import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
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
  late http.Client httpClient;

  setUp(() async {
    client = HttpClient();
    httpClient = http.Client();
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
    httpClient.close();
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
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    expect(decoded['file'], startsWith('internal:/_tmp/'));
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
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    expect(decoded['file'], startsWith('internal:/_tmp/'));
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

  // P0 route tests

  test('POST /v1/meta returns logins and proxy_urls', () async {
    final response = await post('meta', <String, dynamic>{});
    expect(response.statusCode, HttpStatus.ok);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['logins'], isA<List>());
    expect(body['logins'].length, 1);
    expect(body['proxy_urls'], <String>['http://proxy.example']);
  });

  test('POST /v1/meta requires auth', () async {
    final response = await post('meta', <String, dynamic>{}, token: null);
    expect(response.statusCode, HttpStatus.forbidden);
    expect(response.body, 'invalid token');
  });

  test('POST /v1/meta/webhook.create and delete', () async {
    // Create webhook
    var response = await post('meta/webhook.create', <String, dynamic>{
      'url': 'http://webhook.example/endpoint',
    });
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, '{}');

    // Duplicate create updates
    response = await post('meta/webhook.create', <String, dynamic>{
      'url': 'http://webhook.example/endpoint',
      'token': 'tok',
      'enabled': false,
    });
    expect(response.statusCode, HttpStatus.ok);

    // Delete webhook
    response = await post('meta/webhook.delete', <String, dynamic>{
      'url': 'http://webhook.example/endpoint',
    });
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, '{}');

    // Delete non-existent is idempotent
    response = await post('meta/webhook.delete', <String, dynamic>{
      'url': 'http://webhook.example/endpoint',
    });
    expect(response.statusCode, HttpStatus.ok);
  });

  test('webhook create/delete require auth', () async {
    var response = await post('meta/webhook.create', <String, dynamic>{
      'url': 'http://webhook.example/endpoint',
    }, token: null);
    expect(response.statusCode, HttpStatus.forbidden);
    response = await post('meta/webhook.delete', <String, dynamic>{
      'url': 'http://webhook.example/endpoint',
    }, token: null);
    expect(response.statusCode, HttpStatus.forbidden);
  });

  test('GET /v1/proxy/*url forwards to allowed URLs', () async {
    // Start a simple HTTP server to proxy to
    final targetServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(targetServer.close);
    targetServer.listen((req) {
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.text
        ..write('proxied content');
      req.response.close();
    });
    final targetUrl = 'http://127.0.0.1:${targetServer.port}/test.txt';

    // Must be under an allowed proxy URL
    final proxyServer = await SatoriServer(
      adapter: InMemoryAdapter(
        bot: InMemoryBot(
          user: User(id: 'b', name: 'B'),
        ),
        proxyUrls: <String>['http://127.0.0.1:${targetServer.port}'],
      ),
      token: 'secret',
    ).bind(address: InternetAddress.loopbackIPv4, port: 0);
    addTearDown(proxyServer.close);

    final request = await client.get(
      '127.0.0.1',
      proxyServer.port,
      '/v1/proxy/$targetUrl',
    );
    request.headers.set('authorization', 'Bearer secret');
    final response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    final body = await utf8.decoder.bind(response).join();
    expect(body, 'proxied content');
  });

  test('GET /v1/proxy/*url rejects non-allowed URLs', () async {
    final req = await client.get(
      '127.0.0.1',
      port,
      '/v1/proxy/http://evil.example/secret',
    );
    req.headers.set('authorization', 'Bearer secret');
    final response = await req.close();
    expect(response.statusCode, HttpStatus.forbidden);
    expect(await utf8.decoder.bind(response).join(), 'forbidden');
  });

  test('GET /v1/proxy/*url rejects invalid URLs', () async {
    final req = await client.get('127.0.0.1', port, '/v1/proxy/not-a-url');
    req.headers.set('authorization', 'Bearer secret');
    final response = await req.close();
    expect(response.statusCode, HttpStatus.badRequest);
    expect(await utf8.decoder.bind(response).join(), 'invalid url');
  });

  test('ALL /v1/admin/* redirects to /v1/meta', () async {
    // Use raw socket to avoid HttpClient auto-following redirects
    final socket = await RawSocket.connect(InternetAddress.loopbackIPv4, port);
    addTearDown(socket.close);
    final request =
        'GET /v1/admin/webhook.create HTTP/1.1\r\n'
        'Host: 127.0.0.1:$port\r\n'
        'Authorization: Bearer secret\r\n'
        'Connection: close\r\n'
        '\r\n';
    socket.write(utf8.encode(request));
    final completer = Completer<String>();
    final buffer = StringBuffer();
    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final data = socket.read();
        if (data != null) {
          buffer.write(utf8.decode(data));
          // Check if we have the full response (headers end with \r\n\r\n)
          if (buffer.toString().contains('\r\n\r\n')) {
            completer.complete(buffer.toString());
          }
        }
      } else if (event == RawSocketEvent.closed) {
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      }
    }, onError: (e) => completer.completeError(e));
    final responseText = await completer.future.timeout(
      const Duration(seconds: 5),
    );
    // Parse status line
    final statusLine = responseText.split('\r\n').first;
    expect(statusLine, contains('301'));
    // Parse Location header
    final locationMatch = RegExp(
      r'location:\s*(\S+)',
      caseSensitive: false,
    ).firstMatch(responseText);
    expect(locationMatch, isNotNull);
    expect(locationMatch!.group(1), '/v1/meta/webhook.create');
  });

  test('GET /v1/internal/memory/bot-1/_tmp/unknown returns 404', () async {
    final req = await client.get(
      '127.0.0.1',
      port,
      '/v1/internal/memory/bot-1/_tmp/unknown',
    );
    req.headers.set('authorization', 'Bearer secret');
    final response = await req.close();
    expect(response.statusCode, HttpStatus.notFound);
    expect(await utf8.decoder.bind(response).join(), 'not found');
  });

  test('GET /v1/internal/memory/bot-1/_tmp/<id> returns uploaded content', () async {
    // First upload a file
    const boundary = '----nitori-test';
    final uploadReq = await client.post(
      '127.0.0.1',
      port,
      '/v1/upload.create',
    );
    uploadReq.headers
      ..set('authorization', 'Bearer secret')
      ..set('satori-platform', 'memory')
      ..set('satori-user-id', 'bot-1')
      ..set('content-type', 'multipart/form-data; boundary=$boundary');
    uploadReq.add(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="a.txt"\r\n'
        'Content-Type: text/plain\r\n'
        '\r\n'
        'hello world\r\n'
        '--$boundary--\r\n',
      ),
    );
    final uploadResp = await uploadReq.close();
    final uploadBody = await utf8.decoder.bind(uploadResp).join();
    expect(uploadResp.statusCode, HttpStatus.ok);
    final decoded = jsonDecode(uploadBody) as Map<String, dynamic>;
    final url = decoded['file'] as String;
    expect(url, startsWith('internal:/_tmp/'));
    final id = url.substring('internal:/_tmp/'.length);

    // Now GET the temp URL
    final getReq = await client.get(
      '127.0.0.1',
      port,
      '/v1/internal/memory/bot-1/_tmp/$id',
    );
    getReq.headers.set('authorization', 'Bearer secret');
    final getResp = await getReq.close();
    expect(getResp.statusCode, HttpStatus.ok);
    final content = await utf8.decoder.bind(getResp).join();
    expect(content, 'hello world');

    // Second GET should return 404 (TTL is one-time with _takeTempResponse)
    final getReq2 = await client.get(
      '127.0.0.1',
      port,
      '/v1/internal/memory/bot-1/_tmp/$id',
    );
    getReq2.headers.set('authorization', 'Bearer secret');
    final getResp2 = await getReq2.close();
    expect(getResp2.statusCode, HttpStatus.notFound);
  });

  test('POST /v1/internal/memory/bot-1/_tmp/<id> returns 405', () async {
    final req = await client.post(
      '127.0.0.1',
      port,
      '/v1/internal/memory/bot-1/_tmp/someid',
    );
    req.headers.set('authorization', 'Bearer secret');
    final response = await req.close();
    expect(response.statusCode, HttpStatus.methodNotAllowed);
    expect(response.headers.value('allow'), 'GET');
  });

  test('GET /v1/internal/unknown/bot/_tmp/id returns 404 (bot not found)', () async {
    final req = await client.get(
      '127.0.0.1',
      port,
      '/v1/internal/unknown/bot/_tmp/id',
    );
    req.headers.set('authorization', 'Bearer secret');
    final response = await req.close();
    expect(response.statusCode, HttpStatus.notFound);
    expect(await utf8.decoder.bind(response).join(), 'bot not found');
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
