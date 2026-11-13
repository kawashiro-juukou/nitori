import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nitori_client/nitori_client.dart';
import 'package:test/test.dart';

/// Minimal in-process Satori gateway for exercising the client.
class MockGateway {
  MockGateway._(this.server);

  final HttpServer server;
  final List<WebSocket> sockets = <WebSocket>[];
  final List<Map<String, dynamic>> received = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> identifies = <Map<String, dynamic>>[];
  int pingCount = 0;

  static Future<MockGateway> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final mock = MockGateway._(server);
    server.listen(mock._handleRequest);
    return mock;
  }

  void _handleRequest(HttpRequest request) {
    if (request.uri.path == '/v1/events' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((socket) {
        sockets.add(socket);
        socket.listen((data) {
          final frame = jsonDecode(data as String) as Map<String, dynamic>;
          received.add(frame);
          switch (frame['op'] as int) {
            case 3:
              identifies.add(frame);
              socket.add(
                jsonEncode(<String, dynamic>{
                  'op': 4,
                  'body': <String, dynamic>{
                    'logins': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'sn': 1,
                        'status': 1,
                        'platform': 'mock',
                        'user': <String, dynamic>{'id': 'bot-1'},
                        'features': <dynamic>[],
                      },
                    ],
                    'proxy_urls': <String>['http://proxy.example'],
                  },
                }),
              );
            case 1:
              pingCount++;
              socket.add(
                jsonEncode(<String, dynamic>{
                  'op': 2,
                  'body': <String, dynamic>{},
                }),
              );
          }
        });
      });
      return;
    }
    request.response
      ..statusCode = HttpStatus.notFound
      ..close();
  }

  void sendEvent(Map<String, dynamic> body) {
    final frame = jsonEncode(<String, dynamic>{'op': 0, 'body': body});
    for (final socket in sockets) {
      socket.add(frame);
    }
  }

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close();
  }
}

/// Polls [condition] until it holds or [timeout] elapses.
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late MockGateway mock;

  setUp(() async {
    mock = await MockGateway.start();
  });

  tearDown(() async {
    await mock.close();
  });

  test('IDENTIFY carries token and the resume sequence', () async {
    final gateway = Gateway(
      baseUrl: 'http://127.0.0.1:${mock.server.port}',
      token: 'secret',
    )..sequence = 42;

    await gateway.start();
    await waitFor(() => mock.identifies.isNotEmpty);

    final identify = mock.identifies.single;
    expect(identify['op'], 3);
    expect(identify['body'], <String, dynamic>{'token': 'secret', 'sn': 42});

    await gateway.stop();
  });

  test('sends PING frames at the heartbeat interval', () async {
    final gateway = Gateway(
      baseUrl: 'http://127.0.0.1:${mock.server.port}',
      heartbeatInterval: const Duration(milliseconds: 50),
    );

    await gateway.start();
    await waitFor(() => mock.pingCount >= 2);

    expect(mock.pingCount, greaterThanOrEqualTo(2));

    await gateway.stop();
  });

  test('READY populates the client bot list', () async {
    final client = NitoriClient(
      baseUrl: 'http://127.0.0.1:${mock.server.port}',
      token: 'secret',
    );

    await client.start();
    await waitFor(() => client.bots.isNotEmpty);

    expect(client.bots, hasLength(1));
    expect(client.bots.single.platform, 'mock');
    expect(client.bots.single.userId, 'bot-1');
    expect(client.bots.single.login?.sn, 1);
    expect(client.proxyUrls, contains('http://proxy.example'));

    await client.close();
  });

  test('login-added events create a new bot', () async {
    final client = NitoriClient(
      baseUrl: 'http://127.0.0.1:${mock.server.port}',
    );

    await client.start();
    await waitFor(() => client.bots.isNotEmpty);

    mock.sendEvent(<String, dynamic>{
      'sn': 8,
      'type': 'login-added',
      'login': <String, dynamic>{
        'sn': 2,
        'status': 1,
        'platform': 'mock2',
        'user': <String, dynamic>{'id': 'bot-2'},
        'features': <dynamic>[],
      },
    });
    await waitFor(() => client.bots.length == 2);

    expect(client.bots.last.platform, 'mock2');
    expect(client.bots.last.userId, 'bot-2');

    await client.close();
  });

  test('EVENT frames are dispatched with camelCase keys', () async {
    final client = NitoriClient(
      baseUrl: 'http://127.0.0.1:${mock.server.port}',
    );
    final received = <GatewayEvent>[];
    client.events.listen(received.add);

    await client.start();
    await waitFor(() => client.bots.isNotEmpty);

    mock.sendEvent(<String, dynamic>{
      'sn': 7,
      'type': 'message-created',
      'self_id': 'bot-1',
      'login': <String, dynamic>{
        'sn': 1,
        'status': 1,
        'platform': 'mock',
        'user': <String, dynamic>{'id': 'bot-1'},
        'features': <dynamic>[],
      },
      'message': <String, dynamic>{'id': 'm1', 'content': 'hi'},
    });
    await waitFor(() => received.isNotEmpty);

    expect(received.single.sn, 7);
    expect(received.single.type, 'message-created');
    expect(received.single.data['selfId'], 'bot-1');
    expect(received.single.data['message']['id'], 'm1');

    await client.close();
  });

  test('reconnects and replays from the last received sequence', () async {
    final client = NitoriClient(
      baseUrl: 'http://127.0.0.1:${mock.server.port}',
      retryInterval: const Duration(milliseconds: 50),
      retryLazy: const Duration(milliseconds: 50),
    );

    await client.start();
    await waitFor(() => client.bots.isNotEmpty);

    mock.sendEvent(<String, dynamic>{
      'sn': 5,
      'type': 'message-created',
      'login': <String, dynamic>{
        'sn': 1,
        'status': 1,
        'platform': 'mock',
        'user': <String, dynamic>{'id': 'bot-1'},
        'features': <dynamic>[],
      },
      'message': <String, dynamic>{'id': 'm1'},
    });
    await waitFor(() => mock.identifies.length == 1);

    // Drop the connection; the client should reconnect with sn = 5.
    await mock.sockets.single.close();
    await waitFor(() => mock.identifies.length >= 2);

    final replay = mock.identifies.last;
    expect(replay['op'], 3);
    expect(replay['body'], <String, dynamic>{'sn': 5});

    await client.close();
  });
}
