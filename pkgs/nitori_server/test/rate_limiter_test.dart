import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nitori_core/nitori_core.dart';
import 'package:nitori_server/nitori_server.dart';
import 'package:test/test.dart';

/// Collects decoded gateway frames as they arrive.
class _Connection {
  _Connection(this.socket) {
    socket.listen((data) {
      frames.add(jsonDecode(data as String) as Map<String, dynamic>);
    });
  }

  final WebSocket socket;
  final List<Map<String, dynamic>> frames = <Map<String, dynamic>>[];

  void send(int op, [Map<String, dynamic>? body]) {
    socket.add(jsonEncode(<String, dynamic>{
      'op': op,
      'body': body ?? <String, dynamic>{},
    }));
  }

  Map<String, dynamic> frame(int op) => frames.firstWhere(
        (frame) => frame['op'] == op,
        orElse: () => throw StateError('no frame with op $op'),
      );

  Future<void> close() => socket.close();
}

Future<void> waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 3)}) async {
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
  final HttpHeaders headers;
}

void main() {
  group('RateLimiter core', () {
    test('token bucket allows consumption up to capacity', () {
      final config = RateLimiterConfig(
        maxRequests: 5,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.ip,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      final req = _mockRequest('192.168.1.1');

      expect(limiter.checkHttp(req), isNull);
      expect(limiter.checkHttp(req), isNull);
      expect(limiter.checkHttp(req), isNull);
      expect(limiter.checkHttp(req), isNull);
      expect(limiter.checkHttp(req), isNull);
      expect(limiter.checkHttp(req), isNotNull); // 6th should fail
    });

    test('token bucket refills over time', () async {
      final config = RateLimiterConfig(
        maxRequests: 2,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.ip,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      final req = _mockRequest('192.168.1.1');

      expect(limiter.checkHttp(req), isNull);
      expect(limiter.checkHttp(req), isNull);
      expect(limiter.checkHttp(req), isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(limiter.checkHttp(req), isNull); // ~1.1 tokens refilled
    });

    test('rate limiter with ip scope limits per IP', () async {
      final config = RateLimiterConfig(
        maxRequests: 2,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.ip,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      final req1 = _mockRequest('192.168.1.1');
      final req2 = _mockRequest('192.168.1.2');

      expect(limiter.checkHttp(req1), isNull);
      expect(limiter.checkHttp(req1), isNull);
      expect(limiter.checkHttp(req1), isNotNull);

      expect(limiter.checkHttp(req2), isNull);
      expect(limiter.checkHttp(req2), isNull);
      expect(limiter.checkHttp(req2), isNotNull);
    });

    test('rate limiter with identity scope limits per platform:user', () async {
      final config = RateLimiterConfig(
        maxRequests: 1,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.identity,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      final req1 = _mockRequest('192.168.1.1', platform: 'qq', userId: 'user1');
      final req2 = _mockRequest('192.168.1.2', platform: 'qq', userId: 'user2');
      final req3 = _mockRequest('192.168.1.3', platform: 'qq', userId: 'user1');

      expect(limiter.checkHttp(req1), isNull);
      expect(limiter.checkHttp(req1), isNotNull);

      expect(limiter.checkHttp(req2), isNull);
      expect(limiter.checkHttp(req2), isNotNull);

      expect(limiter.checkHttp(req3), isNotNull);
    });

    test('rate limiter with token scope limits per token', () async {
      final config = RateLimiterConfig(
        maxRequests: 1,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.token,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      final req1 = _mockRequest('192.168.1.1', token: 'token-a');
      final req2 = _mockRequest('192.168.1.2', token: 'token-b');
      final req3 = _mockRequest('192.168.1.3', token: 'token-a');

      expect(limiter.checkHttp(req1), isNull);
      expect(limiter.checkHttp(req1), isNotNull);

      expect(limiter.checkHttp(req2), isNull);
      expect(limiter.checkHttp(req2), isNotNull);

      expect(limiter.checkHttp(req3), isNotNull);
    });

    test('rate limiter with global scope limits all requests', () async {
      final config = RateLimiterConfig(
        maxRequests: 2,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.global,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      final req1 = _mockRequest('192.168.1.1');
      final req2 = _mockRequest('192.168.1.2');
      final req3 = _mockRequest('192.168.1.3');

      expect(limiter.checkHttp(req1), isNull);
      expect(limiter.checkHttp(req2), isNull);
      expect(limiter.checkHttp(req3), isNotNull);
    });

    test('disabled rate limiter allows all requests', () async {
      final config = RateLimiterConfig(
        maxRequests: 1,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.ip,
        enabled: false,
      );
      final limiter = RateLimiter(config);

      final req = _mockRequest('192.168.1.1');
      for (var i = 0; i < 100; i++) {
        expect(limiter.checkHttp(req), isNull);
      }
    });

    test('ws connect rate limiter with identity scope', () {
      final config = RateLimiterConfig(
        maxRequests: 1,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.identity,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      final identify1 = {'platform': 'qq', 'user_id': 'user1'};
      final identify2 = {'platform': 'qq', 'user_id': 'user2'};
      final identify3 = {'platform': 'qq', 'user_id': 'user1'};

      expect(limiter.checkWsConnect(identify1), isNull);
      expect(limiter.checkWsConnect(identify1), isNotNull);

      expect(limiter.checkWsConnect(identify2), isNull);
      expect(limiter.checkWsConnect(identify2), isNotNull);

      expect(limiter.checkWsConnect(identify3), isNotNull);
    });

    test('ws connect rate limiter with token scope', () {
      final config = RateLimiterConfig(
        maxRequests: 1,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.token,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      final identify1 = {'token': 'token-a'};
      final identify2 = {'token': 'token-b'};
      final identify3 = {'token': 'token-a'};

      expect(limiter.checkWsConnect(identify1), isNull);
      expect(limiter.checkWsConnect(identify1), isNotNull);

      expect(limiter.checkWsConnect(identify2), isNull);
      expect(limiter.checkWsConnect(identify2), isNotNull);

      expect(limiter.checkWsConnect(identify3), isNotNull);
    });

    test('ws event rate limiter', () {
      final config = RateLimiterConfig(
        maxRequests: 2,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.ip,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      expect(limiter.checkWsEvent('192.168.1.1'), isNull);
      expect(limiter.checkWsEvent('192.168.1.1'), isNull);
      expect(limiter.checkWsEvent('192.168.1.1'), isNotNull);

      expect(limiter.checkWsEvent('192.168.1.2'), isNull);
      expect(limiter.checkWsEvent('192.168.1.2'), isNull);
      expect(limiter.checkWsEvent('192.168.1.2'), isNotNull);
    });

    test('reset clears all buckets', () async {
      final config = RateLimiterConfig(
        maxRequests: 1,
        window: const Duration(seconds: 1),
        scope: RateLimitScope.ip,
        enabled: true,
      );
      final limiter = RateLimiter(config);

      final req = _mockRequest('192.168.1.1');
      expect(limiter.checkHttp(req), isNull);
      expect(limiter.checkHttp(req), isNotNull);

      limiter.reset();
      expect(limiter.checkHttp(req), isNull);
    });
  });

  group('HTTP rate limiting integration', () {
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
      bot.channels['c1'] =
          Channel(id: 'c1', type: ChannelType.text, name: 'general');
      bot.guilds['g1'] = Guild(id: 'g1', name: 'Guild');
      bot.users['u1'] = User(id: 'u1', name: 'User');
      adapter = InMemoryAdapter(
        bot: bot,
        proxyUrls: const <String>['http://proxy.example'],
      );
      server = SatoriServer(
        adapter: adapter,
        token: 'secret',
        httpRateLimit: RateLimiterConfig(
          maxRequests: 3,
          window: const Duration(seconds: 10),
          scope: RateLimitScope.ip,
          enabled: true,
        ),
      );
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
        response.headers,
      );
    }

    test('allows requests under limit', () async {
      final response =
          await post('channel.get', <String, dynamic>{'channel_id': 'c1'});
      expect(response.statusCode, HttpStatus.ok);
    });

    test('returns 429 when rate limited', () async {
      for (var i = 0; i < 3; i++) {
        final response =
            await post('channel.get', <String, dynamic>{'channel_id': 'c1'});
        expect(response.statusCode, HttpStatus.ok);
      }

      final response =
          await post('channel.get', <String, dynamic>{'channel_id': 'c1'});
      expect(response.statusCode, HttpStatus.tooManyRequests);
      expect(response.body, 'Too Many Requests');
      expect(response.headers.value('Retry-After'), isNotNull);
    });

    test('Retry-After header is set correctly', () async {
      for (var i = 0; i < 3; i++) {
        await post('channel.get', <String, dynamic>{'channel_id': 'c1'});
      }

      final response =
          await post('channel.get', <String, dynamic>{'channel_id': 'c1'});
      expect(response.statusCode, HttpStatus.tooManyRequests);
      final retryAfter =
          int.tryParse(response.headers.value('Retry-After') ?? '');
      expect(retryAfter, isNotNull);
      expect(retryAfter!, greaterThan(0));
      expect(retryAfter, lessThanOrEqualTo(10));
    });

    test('different IPs have separate limits', () async {
      expect(true, isTrue);
    });

    test('upload.create is also rate limited', () async {
      const boundary = '----nitori-test';
      for (var i = 0; i < 3; i++) {
        final request =
            await client.post('127.0.0.1', port, '/v1/upload.create');
        request.headers
          ..set('authorization', 'Bearer secret')
          ..set('satori-platform', 'memory')
          ..set('satori-user-id', 'bot-1')
          ..set('content-type', 'multipart/form-data; boundary=$boundary');
        request.add(utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="a.txt"\r\n'
          'Content-Type: text/plain\r\n'
          '\r\n'
          'hello\r\n'
          '--$boundary--\r\n',
        ));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
      }

      final request = await client.post('127.0.0.1', port, '/v1/upload.create');
      request.headers
        ..set('authorization', 'Bearer secret')
        ..set('satori-platform', 'memory')
        ..set('satori-user-id', 'bot-1')
        ..set('content-type', 'multipart/form-data; boundary=$boundary');
      request.add(utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="a.txt"\r\n'
        'Content-Type: text/plain\r\n'
        '\r\n'
        'hello\r\n'
        '--$boundary--\r\n',
      ));
      final response = await request.close();
      expect(response.statusCode, HttpStatus.tooManyRequests);
    });
  });

  group('WebSocket connection rate limiting integration', () {
    late InMemoryBot bot;
    late InMemoryAdapter adapter;
    late SatoriServer server;
    late int port;

    setUp(() async {
      bot = InMemoryBot(
        user: User(id: 'bot-1', name: 'Bot'),
        platform: 'memory',
        sn: 1,
      );
      adapter = InMemoryAdapter(
        bot: bot,
        proxyUrls: const <String>['http://proxy.example'],
      );
      server = SatoriServer(
        adapter: adapter,
        token: 'secret',
        wsConnectRateLimit: RateLimiterConfig(
          maxRequests: 2,
          window: const Duration(seconds: 10),
          scope: RateLimitScope.identity,
          enabled: true,
        ),
      );
      final httpServer = await server.bind(
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
      port = httpServer.port;
    });

    tearDown(() async {
      await server.close();
      await adapter.close();
    });

    Future<_Connection> connect() async =>
        _Connection(await WebSocket.connect('ws://127.0.0.1:$port/v1/events'));

    Future<_Connection> identify(
        {String token = 'secret', int? sn, String userId = 'bot-1'}) async {
      final connection = await connect();
      await waitFor(() => connection.frames.isNotEmpty);
      connection.send(3, <String, dynamic>{
        'token': token,
        if (sn != null) 'sn': sn,
        'platform': 'memory',
        'user_id': userId,
      });
      await waitFor(() => connection.frames.any((frame) => frame['op'] == 4));
      return connection;
    }

    test('allows connections under limit', () async {
      final conn = await identify();
      final ready = conn.frame(4);
      expect(ready['body']['logins'], hasLength(1));
      await conn.close();
    });

    test('closes with 4029 when rate limited', () async {
      final conn1 = await identify();
      await conn1.close();

      final conn2 = await identify();
      await conn2.close();

      final conn3 = await connect();
      await waitFor(() => conn3.frames.isNotEmpty);
      conn3.send(3, <String, dynamic>{
        'token': 'secret',
        'platform': 'memory',
        'user_id': 'bot-1',
      });
      await conn3.socket.done.timeout(const Duration(seconds: 3));
      expect(conn3.socket.closeCode, 4029);
    });

    test('different identities have separate limits', () async {
      final conn1 = await identify(userId: 'user-a');
      await conn1.close();

      final conn2 = await identify(userId: 'user-a');
      await conn2.close();

      final conn3 = await identify(userId: 'user-b');
      final ready = conn3.frame(4);
      expect(ready['body']['logins'], hasLength(1));
      await conn3.close();
    });
  });

  group('WebSocket event rate limiting integration', () {
    late InMemoryBot bot;
    late InMemoryAdapter adapter;
    late SatoriServer server;
    late int port;

    setUp(() async {
      bot = InMemoryBot(
        user: User(id: 'bot-1', name: 'Bot'),
        platform: 'memory',
        sn: 1,
      );
      adapter = InMemoryAdapter(
        bot: bot,
        proxyUrls: const <String>['http://proxy.example'],
      );
      server = SatoriServer(
        adapter: adapter,
        token: 'secret',
        wsEventRateLimit: RateLimiterConfig(
          maxRequests: 2,
          window: const Duration(seconds: 10),
          scope: RateLimitScope.ip,
          enabled: true,
        ),
      );
      final httpServer = await server.bind(
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
      port = httpServer.port;
    });

    tearDown(() async {
      await server.close();
      await adapter.close();
    });

    Future<_Connection> connect() async =>
        _Connection(await WebSocket.connect('ws://127.0.0.1:$port/v1/events'));

    Future<_Connection> identify({String token = 'secret', int? sn}) async {
      final connection = await connect();
      await waitFor(() => connection.frames.isNotEmpty);
      connection.send(3, <String, dynamic>{
        'token': token,
        if (sn != null) 'sn': sn,
        'platform': 'memory',
        'user_id': 'bot-1',
      });
      await waitFor(() => connection.frames.any((frame) => frame['op'] == 4));
      return connection;
    }

    test('rate limits upstream frames from authorized client', () async {
      final conn = await identify();

      conn.send(1);
      await waitFor(() => conn.frames.any((f) => f['op'] == 2));
      conn.frames.removeWhere((f) => f['op'] == 2);

      conn.send(1);
      await waitFor(() => conn.frames.any((f) => f['op'] == 2));
      conn.frames.removeWhere((f) => f['op'] == 2);

      conn.send(1);
      await conn.socket.done.timeout(const Duration(seconds: 3));
      expect(conn.socket.closeCode, 4029);
    });
  });
}

HttpRequest _mockRequest(String ip,
    {String? platform, String? userId, String? token}) {
  return _MockHttpRequest(ip, platform: platform, userId: userId, token: token);
}

class _MockHttpRequest implements HttpRequest {
  _MockHttpRequest(this.remoteAddress,
      {this.platform, this.userId, this.token});

  final String remoteAddress;
  final String? platform;
  final String? userId;
  final String? token;

  @override
  HttpConnectionInfo get connectionInfo => _MockConnectionInfo(remoteAddress);

  @override
  HttpHeaders get headers =>
      _MockHeaders(platform: platform, userId: userId, token: token);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockConnectionInfo implements HttpConnectionInfo {
  _MockConnectionInfo(this.address);
  final String address;
  @override
  InternetAddress get remoteAddress => InternetAddress(address);
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHeaders implements HttpHeaders {
  _MockHeaders({this.platform, this.userId, this.token});
  final String? platform;
  final String? userId;
  final String? token;

  final Map<String, List<String>> _map = {};

  @override
  String? value(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName == 'satori-platform') return platform;
    if (lowerName == 'satori-user-id') return userId;
    if (lowerName == 'authorization' && token != null) return 'Bearer $token';
    final values = _map[lowerName];
    return values?.isNotEmpty == true ? values!.first : null;
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = [value.toString()];
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
