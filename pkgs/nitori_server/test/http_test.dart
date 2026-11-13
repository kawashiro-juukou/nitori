import 'dart:convert';
import 'dart:io';

import 'package:nitori_core/nitori_core.dart';
import 'package:nitori_server/nitori_server.dart';
import 'package:test/test.dart';

class _Response {
  _Response(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

void main() {
  late InMemoryBot bot;
  late InMemoryAdapter adapter;
  late SatoriServer server;
  late int port;
  late HttpClient client;

  setUp(() async {
    client = HttpClient();
    bot = InMemoryBot(
      user: User(id: 'bot-1', name: 'Bot'),
      platform: 'memory',
      sn: 1,
    );
    bot.channels['c1'] = Channel(
      id: 'c1',
      type: ChannelType.text,
      name: 'general',
    );
    bot.guilds['g1'] = Guild(id: 'g1', name: 'Guild');
    bot.users['u1'] = User(id: 'u1', name: 'User');

    adapter = InMemoryAdapter(
      bot: bot,
      proxyUrls: const <String>['http://proxy.example'],
    );
    server = SatoriServer(adapter: adapter, token: 'secret');
    final httpServer = await server.bind(
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    port = httpServer.port;
  });

  tearDown(() async {
    await server.close();
    await adapter.close();
    client.close(force: true);
  });

  Future<_Response> post(
    String method,
    Object? body, {
    String? token = 'secret',
    String? platform = 'memory',
    String? userId = 'bot-1',
  }) async {
    final request = await client.post('127.0.0.1', port, '/v1/$method');
    if (token != null) {
      request.headers.set('authorization', 'Bearer $token');
    }
    if (platform != null) {
      request.headers.set('satori-platform', platform);
    }
    if (userId != null) {
      request.headers.set('satori-user-id', userId);
    }
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    return _Response(
      response.statusCode,
      await utf8.decoder.bind(response).join(),
    );
  }

  test('dispatches channel.get and returns the wire model', () async {
    final response = await post('channel.get', <String, dynamic>{
      'channel_id': 'c1',
    });

    expect(response.statusCode, HttpStatus.ok);
    expect(jsonDecode(response.body), <String, dynamic>{
      'id': 'c1',
      'type': 0,
      'name': 'general',
    });
  });

  test('dispatches channel.list as a pagination payload', () async {
    final response = await post('channel.list', <String, dynamic>{
      'guild_id': 'g1',
    });

    expect(response.statusCode, HttpStatus.ok);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['data'], hasLength(1));
    expect((body['data'] as List<dynamic>).single['id'], 'c1');
  });

  test('message.create returns the created messages', () async {
    final response = await post('message.create', <String, dynamic>{
      'channel_id': 'c1',
      'content': 'hello',
    });

    expect(response.statusCode, HttpStatus.ok);
    final messages = jsonDecode(response.body) as List<dynamic>;
    expect(messages, hasLength(1));
    expect(messages.single['id'], 'm1');
    expect(messages.single['content'], 'hello');
  });

  test('void methods answer 200 with an empty body', () async {
    final response = await post('channel.delete', <String, dynamic>{
      'channel_id': 'c1',
    });

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, isEmpty);
    expect(bot.channels, isEmpty);
  });

  test('guild.role.create parses permissions from their string form', () async {
    final response = await post('guild.role.create', <String, dynamic>{
      'guild_id': 'g1',
      'data': <String, dynamic>{
        'name': 'admin',
        'permissions': '9007199254740993',
        'hoist': true,
      },
    });

    expect(response.statusCode, HttpStatus.ok);
    final role = jsonDecode(response.body) as Map<String, dynamic>;
    expect(role['id'], 'r1');
    expect(role['permissions'], '9007199254740993');
    expect(role['hoist'], isTrue);
  });

  test('missing or wrong bearer token is rejected', () async {
    final missing = await post('channel.get', <String, dynamic>{
      'channel_id': 'c1',
    }, token: null);
    final wrong = await post('channel.get', <String, dynamic>{
      'channel_id': 'c1',
    }, token: 'wrong');

    expect(missing.statusCode, HttpStatus.forbidden);
    expect(missing.body, 'invalid token');
    expect(wrong.statusCode, HttpStatus.forbidden);
    expect(wrong.body, 'invalid token');
  });

  test('unknown identity headers are rejected', () async {
    final response = await post('channel.get', <String, dynamic>{
      'channel_id': 'c1',
    }, platform: 'other');

    expect(response.statusCode, HttpStatus.forbidden);
    expect(response.body, 'login not found');
  });

  test('unknown methods answer 404', () async {
    final response = await post('nope.nope', <String, dynamic>{});

    expect(response.statusCode, HttpStatus.notFound);
    expect(response.body, 'method not found');
  });

  test('a method the adapter does not implement answers 404', () async {
    // Use a stub bot with no overrides: every capability throws
    // UnimplementedError.
    final stubServer = await SatoriServer(
      adapter: _StubAdapter(),
    ).bind(address: InternetAddress.loopbackIPv4, port: 0);
    addTearDown(stubServer.close);

    final request = await client.post(
      '127.0.0.1',
      stubServer.port,
      '/v1/channel.get',
    );
    request.headers
      ..set('satori-platform', 'stub')
      ..set('satori-user-id', 'stub-1')
      ..contentType = ContentType.json;
    request.write('{"channel_id":"c1"}');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    expect(response.statusCode, HttpStatus.notFound);
    expect(body, 'method not supported');
  });

  test('non-POST requests answer 405', () async {
    final request = await client.get('127.0.0.1', port, '/v1/channel.get');
    request.headers.set('authorization', 'Bearer secret');
    final response = await request.close();

    expect(response.statusCode, HttpStatus.methodNotAllowed);
  });

  test('invalid JSON answers 400', () async {
    final request = await client.post('127.0.0.1', port, '/v1/channel.get');
    request.headers
      ..set('authorization', 'Bearer secret')
      ..set('satori-platform', 'memory')
      ..set('satori-user-id', 'bot-1')
      ..contentType = ContentType.json;
    request.write('not json');
    final response = await request.close();

    expect(response.statusCode, HttpStatus.badRequest);
  });

  test('upload.create parses the multipart form', () async {
    const boundary = '----nitori-test';
    final request = await client.post('127.0.0.1', port, '/v1/upload.create');
    request.headers
      ..set('authorization', 'Bearer secret')
      ..set('satori-platform', 'memory')
      ..set('satori-user-id', 'bot-1')
      ..set('content-type', 'multipart/form-data; boundary=$boundary');
    request.add(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="a.txt"\r\n'
        'Content-Type: text/plain\r\n'
        '\r\n'
        'hello\r\n'
        '--$boundary--\r\n',
      ),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(jsonDecode(body), <String, dynamic>{'file': 'memory://upload/1'});
  });

  test('a boundary inside the file content does not split the part', () async {
    // The old hand-rolled scanner matched any occurrence of the boundary
    // bytes; a body containing them must still upload as one part.
    const boundary = 'sep';
    final request = await client.post('127.0.0.1', port, '/v1/upload.create');
    request.headers
      ..set('authorization', 'Bearer secret')
      ..set('satori-platform', 'memory')
      ..set('satori-user-id', 'bot-1')
      ..set('content-type', 'multipart/form-data; boundary=$boundary');
    request.add(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="a.txt"\r\n'
        '\r\n'
        'text before --sep in the middle\r\n'
        '--$boundary--\r\n',
      ),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    expect(response.statusCode, HttpStatus.ok);
    // One part, one upload key – not split at the embedded occurrence.
    expect(jsonDecode(body), <String, dynamic>{'file': 'memory://upload/1'});
  });

  test('missing content-type header on multipart returns 400', () async {
    final request = await client.post('127.0.0.1', port, '/v1/upload.create');
    request.headers
      ..set('authorization', 'Bearer secret')
      ..set('satori-platform', 'memory')
      ..set('satori-user-id', 'bot-1');
    // No content-type header
    request.add(utf8.encode('some body'));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    expect(response.statusCode, HttpStatus.badRequest);
    expect(body, 'missing multipart content type');
  });

  test('malformed multipart body returns 400', () async {
    const boundary = 'boundary';
    final request = await client.post('127.0.0.1', port, '/v1/upload.create');
    request.headers
      ..set('authorization', 'Bearer secret')
      ..set('satori-platform', 'memory')
      ..set('satori-user-id', 'bot-1')
      ..set('content-type', 'multipart/form-data; boundary=$boundary');
    // Malformed: invalid header (missing colon)
    request.add(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition form-data; name="file"\r\n'
        '\r\n'
        'hello\r\n'
        '--$boundary--\r\n',
      ),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    expect(response.statusCode, HttpStatus.badRequest);
    expect(body, contains('invalid multipart body'));
  });

  test('duplicate multipart part names are rejected', () async {
    const boundary = 'dup-boundary';
    final request = await client.post('127.0.0.1', port, '/v1/upload.create');
    request.headers
      ..set('authorization', 'Bearer secret')
      ..set('satori-platform', 'memory')
      ..set('satori-user-id', 'bot-1')
      ..set('content-type', 'multipart/form-data; boundary=$boundary');
    // Two parts with the same name "file"
    request.add(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="a.txt"\r\n'
        '\r\n'
        'hello\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="b.txt"\r\n'
        '\r\n'
        'world\r\n'
        '--$boundary--\r\n',
      ),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    expect(response.statusCode, HttpStatus.badRequest);
    expect(body, 'duplicate part name: file');
  });

  test('message.list returns a BidiList payload', () async {
    await post('message.create', <String, dynamic>{
      'channel_id': 'c1',
      'content': 'hi',
    });
    final response = await post('message.list', <String, dynamic>{
      'channel_id': 'c1',
      'direction': 'after',
    });

    expect(response.statusCode, HttpStatus.ok);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['data'], hasLength(1));
    expect((body['data'] as List<dynamic>).single['id'], 'm1');
  });

  test('getMessageIter walks newest first', () async {
    // InMemoryBot.getMessageIter is derived from getMessageList, which is
    // ascending (oldest first); like the upstream generator, the iterator
    // reverses the page so the newest message arrives first.
    for (final content in <String>['first', 'second', 'third']) {
      await post('message.create', <String, dynamic>{
        'channel_id': 'c1',
        'content': content,
      });
    }
    final ids = await bot.getMessageIter('c1').map((m) => m.content).toList();
    expect(ids, <String>['third', 'second', 'first']);
  });

  test('every registered method is routed', () async {
    for (final key in methodKeys) {
      final response = await post(key, <String, dynamic>{});
      expect(response.statusCode, isNot(HttpStatus.notFound), reason: key);
    }
  });

  test('an oversized body answers 413', () async {
    final smallServer = await SatoriServer(
      adapter: adapter,
      token: 'secret',
      maxRequestBodySize: 16,
    ).bind(address: InternetAddress.loopbackIPv4, port: 0);
    addTearDown(smallServer.close);

    final request = await client.post(
      '127.0.0.1',
      smallServer.port,
      '/v1/channel.get',
    );
    request.headers
      ..set('authorization', 'Bearer secret')
      ..set('satori-platform', 'memory')
      ..set('satori-user-id', 'bot-1')
      ..contentType = ContentType.json;
    request.write('{"channel_id":"${'x' * 64}"}');
    final response = await request.close();

    expect(response.statusCode, HttpStatus.requestEntityTooLarge);
  });
}

/// A bot with no overrides at all: every capability throws
/// [UnimplementedError].
class _StubBot extends SatoriBot {
  @override
  Login get login => Login(
    status: Status.online,
    user: User(id: 'stub-1', name: 'Stub'),
    platform: 'stub',
    sn: 1,
  );

  @override
  String get platform => 'stub';

  @override
  String get userId => 'stub-1';

  @override
  Future<List<String>> sendPrivateMessage(
    String userId,
    String content, {
    String? guildId,
    dynamic referrer,
    bool? linkPreview,
  }) => throw UnimplementedError();
}

class _StubAdapter extends SatoriAdapter {
  final _StubBot bot = _StubBot();

  @override
  List<SatoriBot> get bots => <SatoriBot>[bot];

  @override
  Stream<Event> get events => const Stream<Event>.empty();
}
