import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';

Future<String?> discoverBackendIp() async {
  final MDnsClient client = MDnsClient(rawDatagramSocketFactory:
      (dynamic host, int port,
          {bool? reuseAddress, bool? reusePort, int? ttl}) {
    return RawDatagramSocket.bind(host, port,
        reuseAddress: true, reusePort: false, ttl: ttl ?? 1);
  });

  await client.start();
  String? discoveredUrl;

  try {
    print('Starting mDNS discovery...');

    // Look specifically for "my-backend" service
    final String serviceName = 'my-backend._http._tcp.local';

    // Look for SRV records directly for our specific service
    await for (SrvResourceRecord srv in client
        .lookup<SrvResourceRecord>(ResourceRecordQuery.service(serviceName))) {
      print('Found service: ${srv.name} at ${srv.target}:${srv.port}');

      // Now resolve the hostname to an IP address
      await for (IPAddressResourceRecord ip
          in client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target))) {
        print('Found IP: ${ip.address.address}:${srv.port}');
        discoveredUrl = 'http://${ip.address.address}:${srv.port}';
        break;
      }

      if (discoveredUrl != null) break;
    }

    // If direct approach didn't work, try the broader search
    if (discoveredUrl == null) {
      print('Trying broader mDNS search...');
      await for (PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer('_http._tcp.local'))) {
        print('Found service: ${ptr.domainName}');

        // Check if this is our service
        if (ptr.domainName.contains('my-backend')) {
          await for (SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName))) {
            await for (IPAddressResourceRecord ip
                in client.lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(srv.target))) {
              discoveredUrl = 'http://${ip.address.address}:${srv.port}';
              print('Found our backend: ${discoveredUrl}');
              break;
            }

            if (discoveredUrl != null) break;
          }
        }

        if (discoveredUrl != null) break;
      }
    }
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
