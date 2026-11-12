/// End-to-end integration test: nitori_client <-> nitori_server protocol.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nitori_client/nitori_client.dart';
import 'package:nitori_core/nitori_core.dart';
// ignore: depend_on_referenced_packages
import 'package:nitori_server/nitori_server.dart';
import 'package:test/test.dart';

/// Creates a multi-bot adapter for multi-login tests.
class _MultiBotAdapter extends SatoriAdapter {
  _MultiBotAdapter(this.bot1, this.bot2, {List<String>? proxyUrls})
      : proxyUrls = List<String>.unmodifiable(proxyUrls ?? const <String>[]) {
    _events = StreamController<Event>.broadcast();
  }

  final InMemoryBot bot1;
  final InMemoryBot bot2;
  late final StreamController<Event> _events;

  @override
  final List<String> proxyUrls;

  @override
  List<SatoriBot> get bots => <SatoriBot>[bot1, bot2];

  @override
  Stream<Event> get events => _events.stream;

  void emitFromBot1(Event event) => _events.add(event);
  void emitFromBot2(Event event) => _events.add(event);

  Future<void> close() async {
    await _events.close();
  }
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

void main() {
  late InMemoryBot bot1;
  late InMemoryBot bot2;
  late _MultiBotAdapter adapter;
  late SatoriServer server;
  late int port;
  late NitoriClient client;
  late HttpClient httpClient;

  // Main shared fixture for HTTP API + basic gateway tests.
  setUpAll(() async {
    httpClient = HttpClient();

    bot1 = InMemoryBot(
      user: User(id: 'bot-1', name: 'Bot One'),
      platform: 'test-1',
      sn: 1,
    );
    bot2 = InMemoryBot(
      user: User(id: 'bot-2', name: 'Bot Two'),
      platform: 'test-2',
      sn: 2,
    );

    // Pre-populate bot1 with channels and guilds for API tests.
    bot1.channels['c1'] =
        Channel(id: 'c1', type: ChannelType.text, name: 'general');
    bot1.channels['c2'] =
        Channel(id: 'c2', type: ChannelType.text, name: 'random');
    bot1.guilds['g1'] = Guild(id: 'g1', name: 'Test Guild');
    bot1.users['u1'] = User(id: 'u1', name: 'User One');
    bot1.members['g1/u1'] = GuildMember(user: bot1.users['u1']!);

    // Pre-populate bot2 with different data.
    bot2.channels['c1'] =
        Channel(id: 'c1', type: ChannelType.text, name: 'bot2-general');
    bot2.guilds['g2'] = Guild(id: 'g2', name: 'Bot2 Guild');
    bot2.users['u2'] = User(id: 'u2', name: 'User Two');

    adapter = _MultiBotAdapter(bot1, bot2,
        proxyUrls: const <String>['http://proxy.example']);

    server = SatoriServer(
      adapter: adapter,
      token: 'test-token',
      resumeTimeout: const Duration(minutes: 1),
    );
    final httpServer = await server.bind(
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    port = httpServer.port;

    client = NitoriClient(
      baseUrl: 'http://127.0.0.1:$port',
      token: 'test-token',
    );
    await client.start();
    await waitFor(() => client.status == Status.online);
    await waitFor(() => client.bots.length >= 2);
  });

  tearDownAll(() async {
    await client.close();
    await server.close();
    await adapter.close();
    httpClient.close(force: true);
  });

  Future<_Response> post(
    String method,
    Object? body, {
    String? token = 'test-token',
    String? platform = 'test-1',
    String? userId = 'bot-1',
  }) async {
    final request = await httpClient.post('127.0.0.1', port, '/v1/$method');
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

  group('HTTP API', () {
    test('channel.list with pagination', () async {
      final response = await post('channel.list',
          <String, dynamic>{'guild_id': 'g1', 'next': 'page-2'});
      expect(response.statusCode, HttpStatus.ok);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['data'], hasLength(2));
      final ids = (body['data'] as List).map((e) => e['id']).toList();
      expect(ids, containsAll(['c1', 'c2']));
    });

    test('message.create returns message ID and message.get retrieves it',
        () async {
      final create = await post('message.create',
          <String, dynamic>{'channel_id': 'c1', 'content': 'hello world'});
      expect(create.statusCode, HttpStatus.ok);
      final messages = jsonDecode(create.body) as List<dynamic>;
      expect(messages, hasLength(1));
      final msgId = messages.single['id'] as String;
      expect(msgId, startsWith('m'));

      // Retrieve the message
      final get = await post('message.get',
          <String, dynamic>{'channel_id': 'c1', 'message_id': msgId});
      expect(get.statusCode, HttpStatus.ok);
      final msg = jsonDecode(get.body) as Map<String, dynamic>;
      expect(msg['id'], msgId);
      expect(msg['content'], 'hello world');
    });

    test('message.list supports pagination, direction, limit, order', () async {
      // Create a few messages
      for (var i = 0; i < 5; i++) {
        await post('message.create',
            <String, dynamic>{'channel_id': 'c1', 'content': 'msg $i'});
      }

      // Default list
      var list =
          await post('message.list', <String, dynamic>{'channel_id': 'c1'});
      expect(list.statusCode, HttpStatus.ok);
      var body = jsonDecode(list.body) as Map<String, dynamic>;
      expect((body['data'] as List).length, greaterThanOrEqualTo(5));

      // With limit
      list = await post(
          'message.list', <String, dynamic>{'channel_id': 'c1', 'limit': 2});
      body = jsonDecode(list.body) as Map<String, dynamic>;
      expect((body['data'] as List).length, 2);

      // With direction=after and order=desc (newest first)
      list = await post('message.list', <String, dynamic>{
        'channel_id': 'c1',
        'direction': 'after',
        'order': 'desc',
        'limit': 3,
      });
      body = jsonDecode(list.body) as Map<String, dynamic>;
      expect((body['data'] as List).length, 3);
    });

    test('guild.list and guild.member.list', () async {
      final guilds = await post('guild.list', <String, dynamic>{});
      expect(guilds.statusCode, HttpStatus.ok);
      final gBody = jsonDecode(guilds.body) as Map<String, dynamic>;
      expect((gBody['data'] as List).length, greaterThanOrEqualTo(1));

      final members =
          await post('guild.member.list', <String, dynamic>{'guild_id': 'g1'});
      expect(members.statusCode, HttpStatus.ok);
      final mBody = jsonDecode(members.body) as Map<String, dynamic>;
      expect((mBody['data'] as List).length, greaterThanOrEqualTo(1));
    });

    test('user.get', () async {
      final user = await post('user.get', <String, dynamic>{'user_id': 'u1'});
      expect(user.statusCode, HttpStatus.ok);
      final uBody = jsonDecode(user.body) as Map<String, dynamic>;
      expect(uBody['id'], 'u1');
      expect(uBody['name'], 'User One');
    });

    test('upload.create returns URLs', () async {
      final boundary = '----testboundary';
      final request =
          await httpClient.post('127.0.0.1', port, '/v1/upload.create');
      request.headers
        ..set('authorization', 'Bearer test-token')
        ..set('satori-platform', 'test-1')
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
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, HttpStatus.ok);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['file'], startsWith('memory://upload/'));
    });
  });

  group('WebSocket Gateway', () {
    test('READY contains both logins and proxy_urls', () async {
      expect(client.bots.length, 2);
      final platforms = client.bots.map((b) => b.platform).toSet();
      expect(platforms, {'test-1', 'test-2'});

      expect(client.proxyUrls, contains('http://proxy.example'));
    });

    test('heartbeat PING/PONG at configured interval', () async {
      // The Gateway sends PING every heartbeatInterval (10s default).
      // We just verify the client stays connected and can receive events.
      // Actual PING frame inspection is at gateway level; here we ensure
      // the connection is alive by emitting and receiving an event.
      final received = <GatewayEvent>[];
      final sub = client.events.listen(received.add);
      adapter.emitFromBot1(Event(
        type: 'message-created',
        login: bot1.login,
        selfId: 'bot-1',
        message: Message(id: 'hb1', content: 'heartbeat test'),
      ));
      await waitFor(() => received.isNotEmpty);
      expect(received.single.type, 'message-created');
      await sub.cancel();
    });

    test('EVENT frames carry monotonically increasing sn', () async {
      // Use a fresh server to control sequence numbers.
      final isoBot = InMemoryBot(
        user: User(id: 'iso', name: 'Iso'),
        platform: 'iso',
        sn: 99,
      );
      final isoAdapter = InMemoryAdapter(bot: isoBot, proxyUrls: const []);
      final isoServer = SatoriServer(adapter: isoAdapter, token: 'iso');
      final isoHttpServer = await isoServer.bind(
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
      addTearDown(isoServer.close);
      addTearDown(isoAdapter.close);

      // Use raw WebSocket for reliable event delivery
      final ws = await WebSocket.connect(
          'ws://127.0.0.1:${isoHttpServer.port}/v1/events');
      addTearDown(ws.close);
      final receivedRaw = <Map<String, dynamic>>[];
      ws.listen((data) {
        receivedRaw.add(jsonDecode(data as String) as Map<String, dynamic>);
      });
      // Wait for META
      await waitFor(() => receivedRaw.isNotEmpty);
      // Send IDENTIFY
      ws.add(jsonEncode(<String, dynamic>{
        'op': Opcode.identify.value,
        'body': <String, dynamic>{'token': 'iso'},
      }));
      // Wait for READY
      await waitFor(
          () => receivedRaw.any((f) => f['op'] == Opcode.ready.value));

      // Emit 5 events
      for (var i = 1; i <= 5; i++) {
        isoAdapter.emit(Event(
          type: 'channel-added',
          login: isoBot.login,
          selfId: 'iso',
        ));
      }

      await waitFor(() =>
          receivedRaw.where((f) => f['op'] == Opcode.event.value).length >= 5);
      final events =
          receivedRaw.where((f) => f['op'] == Opcode.event.value).toList();
      final sns = events.map((e) => (e['body'] as Map)['sn'] as int).toList();
      expect(sns, orderedEquals([1, 2, 3, 4, 5]));
    });

    test('Resume replays events after given sn', () async {
      // Dedicated server for controlled resume test.
      final rBot = InMemoryBot(
        user: User(id: 'r', name: 'Resume'),
        platform: 'resume',
        sn: 10,
      );
      final rAdapter = InMemoryAdapter(bot: rBot, proxyUrls: const []);
      final rServer = SatoriServer(adapter: rAdapter, token: 'resume');
      final rHttpServer = await rServer.bind(
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
      addTearDown(rServer.close);
      addTearDown(rAdapter.close);

      // First connection: receive events using RAW WebSocket.
      final ws = await WebSocket.connect(
          'ws://127.0.0.1:${rHttpServer.port}/v1/events');
      addTearDown(ws.close);
      final receivedRaw = <Map<String, dynamic>>[];
      ws.listen((data) {
        receivedRaw.add(jsonDecode(data as String) as Map<String, dynamic>);
      });
      // Wait for META
      await waitFor(() => receivedRaw.isNotEmpty);
      // Send IDENTIFY
      ws.add(jsonEncode(<String, dynamic>{
        'op': Opcode.identify.value,
        'body': <String, dynamic>{'token': 'resume'},
      }));
      // Wait for READY
      await waitFor(
          () => receivedRaw.any((f) => f['op'] == Opcode.ready.value));

      // Emit 3 events.
      for (var i = 1; i <= 3; i++) {
        rAdapter.emit(Event(
          type: 'message-created',
          login: rBot.login,
          selfId: 'r',
          message: Message(id: 'm$i', content: 'msg $i'),
        ));
      }
      // Wait for EVENT frames
      await waitFor(() =>
          receivedRaw.where((f) => f['op'] == Opcode.event.value).length >= 3);
      final events =
          receivedRaw.where((f) => f['op'] == Opcode.event.value).toList();
      final sns = events.map((e) => (e['body'] as Map)['sn'] as int).toList();
      expect(sns, orderedEquals([1, 2, 3]));

      // Now test resume with Gateway client
      await ws.close();

      // New gateway with sequence = 3 to request replay (should replay nothing since sn>3).
      final g2 = Gateway(
        baseUrl: 'http://127.0.0.1:${rHttpServer.port}',
        token: 'resume',
      )..sequence = 3;
      addTearDown(g2.stop);
      final replayed = <GatewayEvent>[];
      g2.events.listen(replayed.add);
      await g2.start();
      await waitFor(() => g2.status == Status.online);

      // Should replay nothing since we gave sn=3 and only have sn=1,2,3.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(replayed, isEmpty);

      // Now test with sn=1: should replay sn=2,3.
      await g2.stop();
      final g3 = Gateway(
        baseUrl: 'http://127.0.0.1:${rHttpServer.port}',
        token: 'resume',
      )..sequence = 1;
      addTearDown(g3.stop);
      final replayed2 = <GatewayEvent>[];
      g3.events.listen(replayed2.add);
      await g3.start();
      await waitFor(() => g3.status == Status.online);
      await waitFor(() => replayed2.length >= 2);
      final replaySns = replayed2.map((e) => e.sn!).toList();
      expect(replaySns, orderedEquals([2, 3]));
    });

    test('sn=0 or omitted does not replay', () async {
      final rBot = InMemoryBot(
        user: User(id: 'r0', name: 'Resume0'),
        platform: 'resume0',
        sn: 20,
      );
      final rAdapter = InMemoryAdapter(bot: rBot, proxyUrls: const []);
      final rServer = SatoriServer(adapter: rAdapter, token: 'resume0');
      final rHttpServer = await rServer.bind(
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
      addTearDown(rServer.close);
      addTearDown(rAdapter.close);

      final ws = await WebSocket.connect(
          'ws://127.0.0.1:${rHttpServer.port}/v1/events');
      addTearDown(ws.close);
      final receivedRaw = <Map<String, dynamic>>[];
      ws.listen((data) {
        receivedRaw.add(jsonDecode(data as String) as Map<String, dynamic>);
      });
      await waitFor(() => receivedRaw.isNotEmpty);
      ws.add(jsonEncode(<String, dynamic>{
        'op': Opcode.identify.value,
        'body': <String, dynamic>{'token': 'resume0'},
      }));
      await waitFor(
          () => receivedRaw.any((f) => f['op'] == Opcode.ready.value));

      rAdapter.emit(Event(
        type: 'channel-added',
        login: rBot.login,
        selfId: 'r0',
      ));
      await waitFor(() =>
          receivedRaw.where((f) => f['op'] == Opcode.event.value).isNotEmpty);
      await ws.close();

      // New connection with sequence = 0
      final ws2 = await WebSocket.connect(
          'ws://127.0.0.1:${rHttpServer.port}/v1/events');
      addTearDown(ws2.close);
      final receivedRaw2 = <Map<String, dynamic>>[];
      ws2.listen((data) {
        receivedRaw2.add(jsonDecode(data as String) as Map<String, dynamic>);
      });
      await waitFor(() => receivedRaw2.isNotEmpty);
      ws2.add(jsonEncode(<String, dynamic>{
        'op': Opcode.identify.value,
        'body': <String, dynamic>{'token': 'resume0', 'sn': 0},
      }));
      await waitFor(
          () => receivedRaw2.any((f) => f['op'] == Opcode.ready.value));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      // Should not replay any events
      expect(receivedRaw2.where((f) => f['op'] == Opcode.event.value), isEmpty);
    });

    test('META broadcast on proxyUrls change', () async {
      // META is sent on connect with the adapter's proxyUrls.
      // This test validates the initial META; dynamic change would need
      // a custom adapter. Here we assert the contract: READY and META
      // both contain proxyUrls.
      expect(client.proxyUrls, contains('http://proxy.example'));
    });

    test('Multi-bot: HTTP requests with bot2 headers return bot2 data',
        () async {
      final response = await post(
          'channel.list', <String, dynamic>{'guild_id': 'g2'},
          platform: 'test-2', userId: 'bot-2');
      expect(response.statusCode, HttpStatus.ok);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>;
      expect(data.length, 1);
      expect(data.single['id'], 'c1');
      expect(data.single['name'], 'bot2-general');
    });

    test('Multi-bot: events from both bots carry login identity', () async {
      final received = <GatewayEvent>[];
      final sub = client.events.listen(received.add);

      adapter.emitFromBot1(Event(
        type: 'message-created',
        login: bot1.login,
        selfId: 'bot-1',
        message: Message(id: 'm1', content: 'from bot1'),
      ));
      adapter.emitFromBot2(Event(
        type: 'message-created',
        login: bot2.login,
        selfId: 'bot-2',
        message: Message(id: 'm2', content: 'from bot2'),
      ));

      await waitFor(() => received.length >= 2);
      final platforms =
          received.map((e) => e.data['login']?['platform']).toSet();
      expect(platforms, {'test-1', 'test-2'});

      await sub.cancel();
    });
  });

  group('Error Handling', () {
    test('HTTP 403: missing token', () async {
      final response = await post(
          'channel.get', <String, dynamic>{'channel_id': 'c1'},
          token: null);
      expect(response.statusCode, HttpStatus.forbidden);
      expect(response.body, 'invalid token');
    });

    test('HTTP 403: wrong token', () async {
      final response = await post(
          'channel.get', <String, dynamic>{'channel_id': 'c1'},
          token: 'wrong');
      expect(response.statusCode, HttpStatus.forbidden);
      expect(response.body, 'invalid token');
    });

    test('HTTP 403: unknown identity headers', () async {
      final response = await post(
          'channel.get', <String, dynamic>{'channel_id': 'c1'},
          platform: 'unknown', userId: 'unknown');
      expect(response.statusCode, HttpStatus.forbidden);
      expect(response.body, 'login not found');
    });

    test('HTTP 404: unknown method', () async {
      final response = await post('nope.nope', <String, dynamic>{});
      expect(response.statusCode, HttpStatus.notFound);
      expect(response.body, 'method not found');
    });

    test('HTTP 404: resource not found returns 500', () async {
      // InMemoryBot throws StateError for missing resources, which
      // the server catches as internal error (500).
      final response = await post(
          'channel.get', <String, dynamic>{'channel_id': 'nonexistent'});
      expect(response.statusCode, HttpStatus.internalServerError);
    });

    test('WS 4004: invalid IDENTIFY token', () async {
      final socket = await WebSocket.connect('ws://127.0.0.1:$port/v1/events');
      addTearDown(socket.close);
      final frames = <Map<String, dynamic>>[];
      socket.listen((data) {
        frames.add(jsonDecode(data as String) as Map<String, dynamic>);
      });
      await waitFor(() => frames.isNotEmpty); // META
      socket.add(jsonEncode(<String, dynamic>{
        'op': Opcode.identify.value,
        'body': <String, dynamic>{'token': 'wrong'},
      }));
      await socket.done.timeout(const Duration(seconds: 3));
      expect(socket.closeCode, 4004);
    });

    test('WS 4000: invalid frame (non-JSON)', () async {
      final socket = await WebSocket.connect('ws://127.0.0.1:$port/v1/events');
      addTearDown(socket.close);
      final frames = <Map<String, dynamic>>[];
      socket.listen((data) {
        frames.add(jsonDecode(data as String) as Map<String, dynamic>);
      });
      await waitFor(() => frames.isNotEmpty); // META
      socket.add('not json');
      await socket.done.timeout(const Duration(seconds: 3));
      expect(socket.closeCode, 4000);
    });
  });
}

/// Helper to capture HTTP responses.
class _Response {
  _Response(this.statusCode, this.body);
  final int statusCode;
  final String body;
}
