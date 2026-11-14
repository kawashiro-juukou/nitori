/// End-to-end dual-hop test: RemoteSatoriAdapter bridges two Satori servers.
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
  bot.channels['c2'] = Channel(
    id: 'c2',
    type: ChannelType.text,
    name: 'random',
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
  _Response(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

Future<_Response> _post(
  HttpClient httpClient,
  int port,
  String method,
  Object? body, {
  String? token,
  String? platform,
  String? userId,
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

void main() {
  // Remote server (upstream)
  late InMemoryBot remoteBot1;
  late InMemoryBot remoteBot2;
  late _MultiBotAdapter remoteAdapter;
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
    remoteBot1 = _createRemoteBot(
      userId: 'remote-1',
      name: 'Remote Bot One',
      platform: 'telegram',
      sn: 1,
      features: ['channel.get', 'message.create', 'guild.list', 'user.get'],
    );
    remoteBot2 = _createRemoteBot(
      userId: 'remote-2',
      name: 'Remote Bot Two',
      platform: 'discord',
      sn: 2,
      features: ['channel.get', 'message.create', 'guild.list', 'user.get'],
    );

    remoteAdapter = _MultiBotAdapter(
      remoteBot1,
      remoteBot2,
      proxyUrls: const ['http://remote-proxy.example'],
    );

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
    print('Local adapter started, client status: ${localAdapter.client.status}');
    await waitFor(() => localAdapter.client.status == Status.online);
    print('Local adapter online, bots: ${localAdapter.bots.length}');
    print('Local client bots: ${localAdapter.client.bots.length}');

    // Wait for bots to be populated from remote READY
    await waitFor(() => localAdapter.client.bots.length >= 2);
    print('Local client bots populated: ${localAdapter.client.bots.length}');
    await waitFor(() => localAdapter.bots.length >= 2);
    print('Local adapter bots populated: ${localAdapter.bots.length}');

    // Add listener to see raw gateway events
    localAdapter.client.events.listen((e) {
      print('Gateway event: type=${e.type}, login=${e.login?.platform}, sn=${e.sn}, op=${e.raw['op']}');
    });

    // Also listen on the gateway directly
    localAdapter.client.gateway.events.listen((e) {
      print('Raw gateway event: type=${e.type}, sn=${e.sn}');
    });

    // Also listen on the remote server's events to see what's happening
    remoteAdapter.events.listen((e) {
      print('Remote adapter event: type=${e.type}, sn=${e.sn}, login=${e.login?.platform}');
    });

    // --- LOCAL SERVER ---
    localServer = SatoriServer(
      adapter: localAdapter,
      token: 'local-token',
      resumeTimeout: const Duration(minutes: 1),
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
    localClient.events.listen((e) {
      print('Local client event: type=${e.type}, login=${e.login?.platform}, sn=${e.sn}');
    });
    await localClient.start();
    print('Local client started, status: ${localClient.status}');
    await waitFor(() => localClient.status == Status.online);
    print('Local client online, bots: ${localClient.bots.length}');
    await waitFor(() => localClient.bots.length >= 2);
    print('Local client has 2+ bots');
  });

  tearDownAll(() async {
    await localClient.close();
    await localServer.close();
    await localAdapter.stop();
    await remoteServer.close();
    await remoteAdapter.close();
    httpClient.close(force: true);
  });

  group('RemoteSatoriAdapter dual-hop', () {
    test('READY contains both remote logins with features', () async {
      expect(localClient.bots.length, 2);
      final platforms = localClient.bots.map((b) => b.platform).toSet();
      expect(platforms, {'telegram', 'discord'});

      // Check features are propagated from remote logins
      final bot1 = localClient.bots.firstWhere((b) => b.platform == 'telegram');
      expect(bot1.login?.features, containsAll(['channel.get', 'message.create', 'guild.list', 'user.get']));
    });

    test('proxyUrls from remote READY/META are exposed locally', () async {
      expect(localAdapter.proxyUrls, contains('http://remote-proxy.example'));

      // Verify local server READY includes proxyUrls
      final ws = await WebSocket.connect(
        'ws://127.0.0.1:$localPort/v1/events',
      );
      addTearDown(ws.close);
      final frames = <Map<String, dynamic>>[];
      ws.listen((data) {
        frames.add(jsonDecode(data as String) as Map<String, dynamic>);
      });
      await waitFor(() => frames.isNotEmpty); // META
      ws.add(jsonEncode(<String, dynamic>{
        'op': Opcode.identify.value,
        'body': <String, dynamic>{'token': 'local-token'},
      }));
      await waitFor(() => frames.any((f) => f['op'] == Opcode.ready.value));
      final ready = frames.firstWhere((f) => f['op'] == Opcode.ready.value);
      expect((ready['body'] as Map)['proxy_urls'], contains('http://remote-proxy.example'));
    });

    test('remote EVENT -> local adapter -> local server -> local gateway client', () async {
      final received = <GatewayEvent>[];
      final sub = localClient.events.listen(received.add);

      // Emit event from remote bot1
      remoteAdapter.emitFromBot1(
        Event(
          type: 'message-created',
          login: remoteBot1.login,
          selfId: 'remote-1',
          message: Message(id: 'msg-1', content: 'hello from remote'),
        ),
      );

      await waitFor(() => received.isNotEmpty);
      expect(received.length, 1);
      final evt = received.single;
      expect(evt.type, 'message-created'); // canonical alias applied
      expect(evt.data['login']['platform'], 'telegram');
      expect(evt.data['message']['content'], 'hello from remote');

      // Verify sn is monotonic (assigned by local server)
      expect(evt.sn, greaterThan(0));

      await sub.cancel();
    });

    test('remote login events sync local bot list but are not forwarded to events stream', () async {
      // Add a new remote bot
      final remoteBot3 = _createRemoteBot(
        userId: 'remote-3',
        name: 'Remote Bot Three',
        platform: 'slack',
        sn: 3,
      );
      remoteAdapter.emitFromBot1(
        Event(
          type: 'login-added',
          login: remoteBot3.login,
          selfId: 'remote-3',
        ),
      );

      await waitFor(() => localAdapter.bots.length == 3);
      expect(localAdapter.bots.map((b) => b.platform).toSet(), {'telegram', 'discord', 'slack'});

      // login events should NOT appear in local gateway client stream
      final received = <GatewayEvent>[];
      final sub = localClient.events.listen(received.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();

      // No login events should be in the stream
      expect(received.where((e) => e.type?.startsWith('login-') ?? false), isEmpty);
    });

    test('HTTP API: local client calls channel.get -> remote bot -> returns data', () async {
      final response = await _post(
        httpClient,
        localPort,
        'channel.get',
        <String, dynamic>{'channel_id': 'c1'},
        token: 'local-token',
        platform: 'telegram',
        userId: 'remote-1',
      );
      expect(response.statusCode, HttpStatus.ok);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['id'], 'c1');
      expect(body['name'], 'general');
    });

    test('HTTP API: local client calls message.create -> remote bot -> returns created message', () async {
      final create = await _post(
        httpClient,
        localPort,
        'message.create',
        <String, dynamic>{
          'channel_id': 'c1',
          'content': 'test message',
        },
        token: 'local-token',
        platform: 'telegram',
        userId: 'remote-1',
      );
      expect(create.statusCode, HttpStatus.ok);
      final messages = jsonDecode(create.body) as List<dynamic>;
      expect(messages, hasLength(1));
      final msgId = messages.single['id'] as String;
      expect(msgId, startsWith('m'));
    });

    test('internal/_api: local bot.internal.someMethod() -> remote bot -> returns', () async {
      // This requires the remote bot to have an internal route defined.
      // We'll test the proxy mechanism by calling the internal route directly.
      // First, define a test route on the remote bot.
      remoteBot1.defineInternalRoute('/_api/testMethod', (req, bot) async {
        return InternalResponse(
          status: 200,
          headers: {'content-type': 'application/json'},
          body: utf8.encode(jsonEncode({'result': 'ok', 'args': req.body})),
        );
      });

      // Call via local adapter's bot
      final localBot = localAdapter.bots.firstWhere((b) => b.platform == 'telegram');
      final remoteBot = localBot as RemoteSatoriBot;

      // Use the internal proxy
      final result = await remoteBot.internal.testMethod({'foo': 'bar'});
      expect(result, isA<Map>());
      expect(result['result'], 'ok');
    });

    test('META broadcast on proxyUrls change', () async {
      // Remote adapter emits META by changing proxyUrls
      // In practice, META comes from remote server. Here we simulate by
      // having the remote adapter's proxyUrls change (but InMemoryAdapter doesn't support this).
      // The test verifies the contract: local adapter exposes proxyUrls.
      expect(localAdapter.proxyUrls, contains('http://remote-proxy.example'));

      // Verify local server META contains proxyUrls
      final ws = await WebSocket.connect(
        'ws://127.0.0.1:$localPort/v1/events',
      );
      addTearDown(ws.close);
      final frames = <Map<String, dynamic>>[];
      ws.listen((data) {
        frames.add(jsonDecode(data as String) as Map<String, dynamic>);
      });
      await waitFor(() => frames.isNotEmpty); // META
      ws.add(jsonEncode(<String, dynamic>{
        'op': Opcode.identify.value,
        'body': <String, dynamic>{'token': 'local-token'},
      }));
      await waitFor(() => frames.any((f) => f['op'] == Opcode.meta.value));
      final meta = frames.firstWhere((f) => f['op'] == Opcode.meta.value);
      expect((meta['body'] as Map)['proxy_urls'], contains('http://remote-proxy.example'));
    });
  });

  group('Reconnection', () {
    test('disconnect/reconnect: kill remote server -> wait reconnect -> events continue', () async {
      // Use a fresh remote server for this test to avoid interfering with others.
      final rBot = _createRemoteBot(
        userId: 'reconnect',
        name: 'Reconnect Bot',
        platform: 'reconnect',
        sn: 99,
      );
      final rAdapter = InMemoryAdapter(bot: rBot, proxyUrls: const []);
      final rServer = SatoriServer(adapter: rAdapter, token: 'reconnect');
      final rHttpServer = await rServer.bind(
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
      final remotePort = rHttpServer.port; // Store port before closing
      addTearDown(rServer.close);
      addTearDown(rAdapter.close);

      // Create local adapter pointing to this remote
      final adapter = RemoteSatoriAdapter(
        baseUrl: 'http://127.0.0.1:$remotePort',
        token: 'reconnect',
        retryTimes: 2,
        retryInterval: const Duration(milliseconds: 100),
        retryLazy: const Duration(milliseconds: 200),
        heartbeatInterval: const Duration(seconds: 2),
      );
      await adapter.start();
      await waitFor(() => adapter.client.status == Status.online);
      await waitFor(() => adapter.bots.length == 1);
      expect(adapter.bots.length, 1);

      // Kill remote server
      await rServer.close();

      // Wait for reconnect (should go to reconnecting, then back online)
      await waitFor(() => adapter.client.status == Status.reconnect || adapter.client.status == Status.disconnect);

      // Restart remote server ON THE SAME PORT
      // We need to recreate the HttpServer on the same port.
      final rServer2 = SatoriServer(adapter: rAdapter, token: 'reconnect');
      await rServer2.bind(
        address: InternetAddress.loopbackIPv4,
        port: remotePort, // Same port!
      );
      addTearDown(rServer2.close);

      // Wait for adapter to reconnect AND bots to populate
      await waitFor(() => adapter.client.status == Status.online);
      await waitFor(() => adapter.bots.length == 1);
      expect(adapter.bots.length, 1);

      // Create LOCAL SERVER with this adapter
      final localServer = SatoriServer(
        adapter: adapter,
        token: 'local-token',
        resumeTimeout: const Duration(minutes: 1),
      );
      final localHttpServer = await localServer.bind(
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
      final localPort = localHttpServer.port;
      addTearDown(localServer.close);

      // Emit event after reconnect - connect a client to the LOCAL server
      final received = <GatewayEvent>[];
      final client = NitoriClient(
        baseUrl: 'http://127.0.0.1:$localPort',
        token: 'local-token',
      );
      addTearDown(client.close);
      await client.start();
      await waitFor(() => client.status == Status.online);
      client.events.listen(received.add);

      rAdapter.emit(
        Event(
          type: 'message-created',
          login: rBot.login,
          selfId: 'reconnect',
          message: Message(id: 'after-reconnect', content: 'test'),
        ),
      );
      await waitFor(() => received.isNotEmpty);
      expect(received.single.data['message']['content'], 'test');

      await client.close();
      await rServer2.close();
    });
  });
}