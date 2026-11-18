import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nitori_client/nitori_client.dart';
import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

/// Minimal in-process Satori gateway for exercising the client.
class MockGateway {
  MockGateway._(this.server);

  final HttpServer server;
  final List<WebSocket> sockets = <WebSocket>[];
  final List<Map<String, dynamic>> receives = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> identifies = <Map<String, dynamic>>[];

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
          receives.add(frame);
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

  test('eventStream skips login-* frames', () async {
    final client = NitoriClient(
      baseUrl: 'http://127.0.0.1:${mock.server.port}',
    );
    final events = <Event>[];
    client.eventStream.listen(events.add);

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
    await Future.delayed(const Duration(milliseconds: 50));

    expect(events, isEmpty);

    await client.close();
  });

  test('eventStream decodes message-created into a typed Event', () async {
    final client = NitoriClient(
      baseUrl: 'http://127.0.0.1:${mock.server.port}',
    );
    final events = <Event>[];
    client.eventStream.listen(events.add);

    await client.start();
    await waitFor(() => client.bots.isNotEmpty);

    mock.sendEvent(<String, dynamic>{
      'sn': 9,
      'type': 'message-created',
      'self_id': 'bot-1',
      'login': <String, dynamic>{
        'sn': 1,
        'status': 1,
        'platform': 'mock',
        'user': <String, dynamic>{'id': 'bot-1'},
        'features': <dynamic>[],
      },
      'message': <String, dynamic>{'id': 'm1', 'content': 'hello'},
      'channel': <String, dynamic>{'id': 'c1', 'type': 0, 'name': 'general'},
    });
    await waitFor(() => events.isNotEmpty);

    expect(events, hasLength(1));
    expect(events.single.type, 'message-created');
    expect(events.single.sn, 9);
    expect(events.single.message?.id, 'm1');
    expect(events.single.message?.content, 'hello');
    expect(events.single.channel?.id, 'c1');

    await client.close();
  });
}
