import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nitori_client/nitori_client.dart';
import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

/// Response of a mock API handler.
typedef ApiResult = ({int status, Object? body});

/// Minimal in-process HTTP endpoint for exercising the bot API.
class MockApi {
  MockApi._(this.server);

  final HttpServer server;
  final List<String> paths = <String>[];
  final List<String> bodies = <String>[];

  /// Handles each request; defaults to a 404.
  Future<ApiResult> Function(HttpRequest request, String body)? handler;

  static Future<MockApi> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final mock = MockApi._(server);
    server.listen(mock._handleRequest);
    return mock;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    paths.add(request.uri.path);
    bodies.add(body);

    final result = await handler?.call(request, body) ??
        (status: HttpStatus.notFound, body: <String, dynamic>{});
    request.response
      ..statusCode = result.status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(result.body));
    await request.response.close();
  }

  Future<void> close() async {
    await server.close();
  }
}

NitoriBot botFor(MockApi api) => NitoriBot(
      NitoriClient(baseUrl: 'http://127.0.0.1:${api.server.port}'),
      platform: 'mock',
      userId: 'bot-1',
    );

void main() {
  late MockApi api;

  setUp(() async {
    api = await MockApi.start();
  });

  tearDown(() async {
    await api.close();
  });

  test('getMessage posts snake_case fields with identity headers', () async {
    Map<String, String>? seenHeaders;
    api.handler = (request, body) async {
      seenHeaders = <String, String>{
        'authorization': request.headers.value('authorization') ?? '',
        'satori-platform': request.headers.value('satori-platform') ?? '',
        'satori-user-id': request.headers.value('satori-user-id') ?? '',
      };
      expect(body, '{"channel_id":"c1","message_id":"m1"}');
      return (status: HttpStatus.ok, body: <String, dynamic>{'id': 'm1'});
    };

    final bot = botFor(api);
    final message = await bot.getMessage('c1', 'm1');

    expect(api.paths.single, '/v1/message.get');
    expect(message.id, 'm1');
    expect(seenHeaders, <String, String>{
      'authorization': '',
      'satori-platform': 'mock',
      'satori-user-id': 'bot-1',
    });
  });

  test('sends the Authorization bearer token when configured', () async {
    final client = NitoriClient(
      baseUrl: 'http://127.0.0.1:${api.server.port}',
      token: 'secret',
    );
    final bot = NitoriBot(client, platform: 'mock', userId: 'bot-1');
    api.handler = (request, body) async {
      expect(request.headers.value('authorization'), 'Bearer secret');
      return (status: HttpStatus.ok, body: <String, dynamic>{'id': 'm1'});
    };

    await bot.getMessage('c1', 'm1');
  });

  test('getChannelList parses a Pagination payload', () async {
    api.handler = (request, body) async {
      expect(body, '{"guild_id":"g1","next":"page-2"}');
      return (
        status: HttpStatus.ok,
        body: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'ch1', 'type': 0, 'name': 'general'},
          ],
          'next': 'page-2',
        },
      );
    };

    final bot = botFor(api);
    final page = await bot.getChannelList('g1', next: 'page-2');

    expect(page.data.single.id, 'ch1');
    expect(page.data.single.type, ChannelType.text);
    expect(page.next, 'page-2');
  });

  test('getMessageList parses a BidiList payload', () async {
    api.handler = (request, body) async {
      expect(body,
          '{"channel_id":"c1","direction":"after","limit":10,"order":"desc"}');
      return (
        status: HttpStatus.ok,
        body: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'm1', 'content': 'hi'},
          ],
          'prev': 'p',
          'next': 'n',
        },
      );
    };

    final bot = botFor(api);
    final page = await bot.getMessageList('c1',
        direction: Direction.after, limit: 10, order: Order.desc);

    expect(page.data.single.id, 'm1');
    expect(page.prev, 'p');
    expect(page.next, 'n');
  });

  test('createMessage returns the message list', () async {
    api.handler = (request, body) async {
      expect(body, '{"channel_id":"c1","content":"hello"}');
      return (
        status: HttpStatus.ok,
        body: <dynamic>[
          <String, dynamic>{'id': 'm1', 'content': 'hello'},
        ],
      );
    };

    final bot = botFor(api);
    final messages = await bot.createMessage('c1', 'hello');

    expect(messages.single.id, 'm1');
  });

  test('nested data maps are snake_cased on the wire', () async {
    api.handler = (request, body) async {
      expect(
        body,
        '{"guild_id":"g1","data":{"name":"new","parent_id":"p1","is_bot":true}}',
      );
      return (
        status: HttpStatus.ok,
        body: <String, dynamic>{'id': 'ch1', 'type': 0}
      );
    };

    final bot = botFor(api);
    final channel = await bot.createChannel('g1', <String, dynamic>{
      'name': 'new',
      'parentId': 'p1',
      'isBot': true,
    });

    expect(channel.id, 'ch1');
  });

  test('non-200 responses raise SatoriApiException', () async {
    api.handler = (request, body) async => (
          status: HttpStatus.forbidden,
          body: <String, dynamic>{'error': 'nope'}
        );

    final bot = botFor(api);
    await expectLater(
      bot.getGuild('g1'),
      throwsA(isA<SatoriApiException>()
          .having((e) => e.statusCode, 'statusCode', HttpStatus.forbidden)),
    );
  });

  test('createUpload sends a multipart form', () async {
    late String contentType;
    api.handler = (request, body) async {
      contentType = request.headers.value('content-type') ?? '';
      expect(body, contains('hi'));
      return (
        status: HttpStatus.ok,
        body: <String, dynamic>{'file': 'http://example/1'},
      );
    };

    final bot = botFor(api);
    final urls = await bot.createUpload(<dynamic>[
      <int>[104, 105]
    ]);

    expect(urls, <String>['http://example/1']);
    expect(contentType, startsWith('multipart/form-data'));
  });
}
