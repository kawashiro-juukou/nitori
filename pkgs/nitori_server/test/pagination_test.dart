/// Tests for satori-pagination header transparency across the Satori protocol bridge.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nitori_client/nitori_client.dart';
import 'package:nitori_core/nitori_core.dart';
import 'package:nitori_server/nitori_server.dart';
import 'package:test/test.dart';

/// Creates a bot with pre-populated data for the remote server.
InMemoryBot _createRemoteBot({
  required String userId,
  required String name,
  required String platform,
  required int sn,
  List<String>? features,
}) {
  final user = User(id: userId, name: name);
  final bot = InMemoryBot(
    user: user,
    platform: platform,
    sn: sn,
    features: features ?? const ['channel.get', 'message.create', 'guild.list'],
  );

  // Pre-populate with test data.
  bot.channels['c1'] = Channel(
    id: 'c1',
    type: ChannelType.text,
    name: 'general',
  );
  bot.guilds['g1'] = Guild(id: 'g1', name: 'Test Guild');
  bot.users['u1'] = User(id: 'u1', name: 'User One');
  bot.members['g1/u1'] = GuildMember(user: bot.users['u1']!);

  return bot;
}

Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _Response {
  _Response(this.statusCode, this.body, this.headers);
  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

Future<_Response> _post(
  HttpClient httpClient,
  int port,
  String path,
  Object? body, {
  String? token,
  String? platform,
  String? userId,
  Map<String, String>? extraHeaders,
}) async {
  final request = await httpClient.post('127.0.0.1', port, path);
  if (token != null) {
    request.headers.set('authorization', 'Bearer $token');
  }
  if (platform != null) {
    request.headers.set('satori-platform', platform);
  }
  if (userId != null) {
    request.headers.set('satori-user-id', userId);
  }
  if (extraHeaders != null) {
    extraHeaders.forEach((k, v) => request.headers.set(k, v));
  }
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(body));
  final response = await request.close();
  final responseHeaders = <String, String>{};
  response.headers.forEach((k, v) {
    // HttpClientResponse headers can have multiple values; take the first
    responseHeaders[k.toLowerCase()] = v.first;
  });
  return _Response(
    response.statusCode,
    await utf8.decoder.bind(response).join(),
    responseHeaders,
  );
}

void main() {
  // Remote server (upstream)
  late InMemoryBot remoteBot;
  late InMemoryAdapter remoteAdapter;
  late SatoriServer remoteServer;
  late int remotePort;
  late HttpClient httpClient;

  // Local server (bridge)
  late RemoteSatoriAdapter localAdapter;
  late SatoriServer localServer;
  late int localPort;

  // Local gateway client
  late NitoriClient localClient;

  setUpAll(() async {
    httpClient = HttpClient();

    // --- REMOTE SERVER ---
    remoteBot = _createRemoteBot(
      userId: 'remote-1',
      name: 'Remote Bot One',
      platform: 'telegram',
      sn: 1,
      features: ['channel.get', 'message.create', 'guild.list', 'user.get'],
    );

    remoteAdapter = InMemoryAdapter(bot: remoteBot, proxyUrls: const []);

    remoteServer = SatoriServer(
      adapter: remoteAdapter,
      token: 'remote-token',
      resumeTimeout: const Duration(minutes: 1),
    );
    final remoteHttpServer = await remoteServer.bind(
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    remotePort = remoteHttpServer.port;

    // --- LOCAL ADAPTER (bridge) ---
    localAdapter = RemoteSatoriAdapter(
      baseUrl: 'http://127.0.0.1:$remotePort',
      token: 'remote-token',
      retryTimes: 3,
      retryInterval: const Duration(seconds: 1),
      retryLazy: const Duration(seconds: 2),
      heartbeatInterval: const Duration(seconds: 5),
    );
    await localAdapter.start();
    print(
      'Local adapter started, client status: ${localAdapter.client.status}',
    );
    await waitFor(() => localAdapter.client.status == Status.online);
    print('Local adapter online, bots: ${localAdapter.bots.length}');

    // Wait for bots to be populated from remote READY
    await waitFor(() => localAdapter.client.bots.isNotEmpty);
    print('Local client bots populated: ${localAdapter.client.bots.length}');
    await waitFor(() => localAdapter.bots.isNotEmpty);
    print('Local adapter bots populated: ${localAdapter.bots.length}');

    // --- LOCAL SERVER ---
    localServer = SatoriServer(
      adapter: localAdapter,
      token: 'local-token',
      resumeTimeout: const Duration(minutes: 1),
      onEventPublished: localAdapter.onEventPublished,
    );
    final localHttpServer = await localServer.bind(
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    localPort = localHttpServer.port;
    print('Local server bound to port $localPort');

    // --- LOCAL GATEWAY CLIENT ---
    localClient = NitoriClient(
      baseUrl: 'http://127.0.0.1:$localPort',
      token: 'local-token',
    );
    await localClient.start();
    print('Local client started, status: ${localClient.status}');
    await waitFor(() => localClient.status == Status.online);
    print('Local client online, bots: ${localClient.bots.length}');
    await waitFor(() => localClient.bots.isNotEmpty);
    print('Local client has 1+ bots');
  });

  tearDownAll(() async {
    await localClient.close();
    await localServer.close();
    await localAdapter.stop();
    await remoteServer.close();
    await remoteAdapter.close();
    httpClient.close(force: true);
  });

  group('satori-pagination header transparency', () {
    test(
      'request header satori-pagination crosses bridge to remote internal method',
      () async {
        // Define a remote internal route that ECHOES the received satori-pagination header
        // in its response body.
        remoteBot.defineInternalRoute('/_api/echoPagination', (req, bot) async {
          final requestHeaders = req.headers;
          final paginationHeader =
              requestHeaders['satori-pagination'] ?? 'missing';
          return InternalResponse(
            status: 200,
            headers: {'content-type': 'application/json'},
            body: utf8.encode(
              jsonEncode({'receivedPagination': paginationHeader}),
            ),
          );
        });

        // POST to the LOCAL server's internal route WITH satori-pagination header.
        // The local bot is a RemoteSatoriBot, so the server forwards to the remote server.
        final response = await _post(
          httpClient,
          localPort,
          '/v1/internal/telegram/remote-1/_api/echoPagination',
          {'test': 'data'},
          token: 'local-token',
          platform: 'telegram',
          userId: 'remote-1',
          extraHeaders: {'satori-pagination': 'true'},
        );

        expect(response.statusCode, HttpStatus.ok);
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // The remote method should have received the satori-pagination header
        expect(body['receivedPagination'], 'true');
      },
    );

    test(
      'request WITHOUT satori-pagination header shows missing on remote side',
      () async {
        // Define a remote internal route that ECHOES the received satori-pagination header
        remoteBot.defineInternalRoute('/_api/echoPagination2', (
          req,
          bot,
        ) async {
          final requestHeaders = req.headers;
          final paginationHeader =
              requestHeaders['satori-pagination'] ?? 'missing';
          return InternalResponse(
            status: 200,
            headers: {'content-type': 'application/json'},
            body: utf8.encode(
              jsonEncode({'receivedPagination': paginationHeader}),
            ),
          );
        });

        // POST to the LOCAL server's internal route WITHOUT satori-pagination header.
        final response = await _post(
          httpClient,
          localPort,
          '/v1/internal/telegram/remote-1/_api/echoPagination2',
          {'test': 'data'},
          token: 'local-token',
          platform: 'telegram',
          userId: 'remote-1',
        );

        expect(response.statusCode, HttpStatus.ok);
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // The remote method should see 'missing' since no header was sent
        expect(body['receivedPagination'], 'missing');
      },
    );

    test(
      'response header satori-pagination is mirrored back to local client',
      () async {
        // Define a remote internal route that RETURNS a satori-pagination header in the response
        remoteBot.defineInternalRoute('/_api/returnPagination', (
          req,
          bot,
        ) async {
          return InternalResponse(
            status: 200,
            headers: {
              'content-type': 'application/json',
              'satori-pagination': 'next_cursor_abc123',
            },
            body: utf8.encode(jsonEncode({'result': 'ok'})),
          );
        });

        // POST to the LOCAL server's internal route
        final response = await _post(
          httpClient,
          localPort,
          '/v1/internal/telegram/remote-1/_api/returnPagination',
          {'test': 'data'},
          token: 'local-token',
          platform: 'telegram',
          userId: 'remote-1',
        );

        expect(response.statusCode, HttpStatus.ok);
        // The response should include the satori-pagination header from the remote
        expect(response.headers['satori-pagination'], 'next_cursor_abc123');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['result'], 'ok');
      },
    );

    test('request and response satori-pagination both work together', () async {
      // Define a remote internal route that ECHOES request header AND returns response header
      remoteBot.defineInternalRoute('/_api/fullPagination', (req, bot) async {
        final requestHeaders = req.headers;
        final reqPagination = requestHeaders['satori-pagination'] ?? 'missing';
        return InternalResponse(
          status: 200,
          headers: {
            'content-type': 'application/json',
            'satori-pagination': 'response_cursor_xyz789',
          },
          body: utf8.encode(
            jsonEncode({'requestPagination': reqPagination, 'echoed': true}),
          ),
        );
      });

      // POST to the LOCAL server's internal route WITH satori-pagination header
      final response = await _post(
        httpClient,
        localPort,
        '/v1/internal/telegram/remote-1/_api/fullPagination',
        {'test': 'data'},
        token: 'local-token',
        platform: 'telegram',
        userId: 'remote-1',
        extraHeaders: {'satori-pagination': 'request_cursor_abc'},
      );

      expect(response.statusCode, HttpStatus.ok);
      // Verify request header was received by remote
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['requestPagination'], 'request_cursor_abc');
      expect(body['echoed'], true);
      // Verify response header is mirrored back
      expect(response.headers['satori-pagination'], 'response_cursor_xyz789');
    });
  });
}
