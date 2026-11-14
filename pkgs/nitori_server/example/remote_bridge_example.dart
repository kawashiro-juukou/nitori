// Example: run a local SatoriServer in front of a remote Satori server.
//
// Topology:
//
//   [Telegram/Discord/...] upstream adapters
//         |
//   remote Satori server (e.g. Koishi with server-satori)
//         |  network, standard /v1/* + /v1/events
//         v
//   RemoteSatoriAdapter (this process)
//         |
//   local SatoriServer on SATORI_LOCAL_PORT
//         |
//   local Satori clients (nitori_client / any Satori client)
//
// Environment:
//   SATORI_REMOTE_URL   base URL of the remote server (default
//                       http://127.0.0.1:5140). Include any path prefix the
//                       remote serves under, e.g. http://host:5140/satori.
//   SATORI_REMOTE_TOKEN token for the remote gateway (optional).
//   SATORI_LOCAL_PORT   port for the local server (default 5141).

import 'dart:io';

import 'package:nitori_server/nitori_server.dart';

Future<void> main() async {
  final remoteUrl =
      Platform.environment['SATORI_REMOTE_URL'] ?? 'http://127.0.0.1:5140';
  final remoteToken = Platform.environment['SATORI_REMOTE_TOKEN'];
  final localPort =
      int.tryParse(Platform.environment['SATORI_LOCAL_PORT'] ?? '') ?? 5141;

  print('Protocol bridge topology:');
  print('  upstream adapters -> remote Satori server ($remoteUrl)');
  print('  -> RemoteSatoriAdapter -> local SatoriServer (port $localPort)');
  print('  -> local Satori clients');

  final adapter = RemoteSatoriAdapter(baseUrl: remoteUrl, token: remoteToken);

  // Every event mirrored from the remote server passes through here. The
  // local server re-numbers `sn` and broadcasts it to local gateway clients.
  adapter.events.listen((event) {
    print(
      'event: type=${event.type} sn=${event.sn} '
      'platform=${event.login?.platform}',
    );
  });

  final server = SatoriServer(adapter: adapter);
  final httpServer = await server.bind(port: localPort);
  print(
    'local server listening on '
    'http://${httpServer.address.address}:$localPort',
  );

  // Connects to the remote gateway (/v1/events), performs IDENTIFY, and keeps
  // the connection (and the process) alive until interrupted.
  await adapter.start();
  print('remote adapter status: ${adapter.client.status}');
}
