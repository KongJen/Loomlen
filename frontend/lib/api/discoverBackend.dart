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

  try {
    await for (PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_http._tcp.local'))) {
      await for (SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName))) {
        await for (IPAddressResourceRecord ip
            in client.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target))) {
          print('Found service at: ${ip.address.address}:${srv.port}');
          return 'http://${ip.address.address}:${srv.port}';
        }
      }
    }
  } catch (e) {
    print("mDNS discovery error: $e");
  } finally {
    client.stop(); // don't await here
  }

  return null;
}
