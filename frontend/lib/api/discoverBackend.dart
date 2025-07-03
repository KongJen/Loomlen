import 'dart:io';
import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _lastKnownBackendIpKey = 'last_known_backend_ip';

const int _discoveryTimeoutSeconds = 3;

class BackendDiscovery {
  static final BackendDiscovery _instance = BackendDiscovery._internal();
  factory BackendDiscovery() => _instance;
  BackendDiscovery._internal();

  //final String _defaultUrl = "http://10.0.2.2:8080";
  //For server :
  final String _defaultUrl =
      "https://loomlenbackdeploy.jollyhill-26ad4936.southeastasia.azurecontainerapps.io";
  //For Test : http://10.0.2.2:8080

  String? _currentBackendUrl;

  bool _isDiscovering = false;

  Future<String> getBackendUrl() async {
    if (_currentBackendUrl != null) {
      return _currentBackendUrl!;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastKnownIp = prefs.getString(_lastKnownBackendIpKey);

    if (!_isDiscovering) {
      _startDiscoveryInBackground();
    }

    return lastKnownIp ?? _defaultUrl;
  }

  void _startDiscoveryInBackground() {
    if (_isDiscovering) return;

    _isDiscovering = true;

    discoverBackendIp().then((discoveredUrl) async {
      if (discoveredUrl != null) {
        _currentBackendUrl = discoveredUrl;

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastKnownBackendIpKey, discoveredUrl);

        print('Discovered and saved backend URL: $_currentBackendUrl');
      }
      _isDiscovering = false;
    });
  }

  Future<bool> isBackendReachable(String url) async {
    try {
      HttpClient client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);

      final request = await client.getUrl(Uri.parse('$url/health'));
      final response = await request.close();
      await response.drain<void>();

      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      print('Backend connectivity test failed: $e');
      return false;
    }
  }
}

Future<String?> discoverBackendIp() async {
  Completer<String?> completer = Completer<String?>();

  Timer(Duration(seconds: _discoveryTimeoutSeconds), () {
    if (!completer.isCompleted) {
      print('mDNS discovery timed out after $_discoveryTimeoutSeconds seconds');
      completer.complete(null);
    }
  });

  final MDnsClient client = MDnsClient(rawDatagramSocketFactory:
      (dynamic host, int port,
          {bool? reuseAddress, bool? reusePort, int? ttl}) {
    return RawDatagramSocket.bind(host, port,
        reuseAddress: true, reusePort: false, ttl: ttl ?? 1);
  });

  await client.start();
  String? discoveredUrl;

  try {
    print(
        'Starting mDNS discovery with timeout of $_discoveryTimeoutSeconds seconds...');

    final String serviceName = 'my-backend._http._tcp.local';

    var srvSubscription = client
        .lookup<SrvResourceRecord>(ResourceRecordQuery.service(serviceName))
        .listen((SrvResourceRecord srv) async {
      print('Found service: ${srv.name} at ${srv.target}:${srv.port}');

      var ipSubscription = client
          .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target))
          .listen((IPAddressResourceRecord ip) {
        print('Found IP: ${ip.address.address}:${srv.port}');
        discoveredUrl = 'http://${ip.address.address}:${srv.port}';

        if (!completer.isCompleted) {
          completer.complete(discoveredUrl);
        }
      });

      ipSubscription.onError((e) {
        print('Error resolving IP for ${srv.target}: $e');
      });
    });

    srvSubscription.onError((e) {
      print('Error looking up SRV records: $e');
    });

    discoveredUrl = await completer.future;
  } catch (e, stackTrace) {
    print("mDNS discovery error: $e");
    print("Stack trace: $stackTrace");
  } finally {
    client.stop();
  }

  if (discoveredUrl == null) {
    print('No backend service discovered via mDNS');
  } else {
    print('Discovered backend at: $discoveredUrl');
  }

  return discoveredUrl;
}
