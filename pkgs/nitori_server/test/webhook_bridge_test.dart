/// Test for Step 9: webhook across the bridge.
///
/// A webhook registered on the LOCAL server must receive events that originated
/// on the REMOTE server.
///
/// Mirror mode is the default and needs no configuration — the local server
/// subscribes to the remote adapter's event stream, and _publish() calls
/// _dispatchWebhooks() for every published event.
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

class _WebhookReceiver {
  _WebhookReceiver(this.server, this.port);

  final HttpServer server;
  final int port;
  final List<Map<String, dynamic>> receivedPosts = [];

  Future<void> close() async {
    await server.close();
  }
}

Future<_WebhookReceiver> _startWebhookReceiver() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final receiver = _WebhookReceiver(server, server.port);
  server.listen((request) async {
    if (request.method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      final headers = <String, String>{};
      request.headers.forEach((k, v) {
        headers[k.toLowerCase()] = v.last;
      });
      receiver.receivedPosts.add({
        'body': jsonDecode(body),
        'headers': headers,
      });
      request.response.statusCode = HttpStatus.ok;
      request.response.write('{}');
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.write('method not allowed');
    }
    await request.response.close();
  });
  return receiver;
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

  // Webhook receiver
  late _WebhookReceiver webhookReceiver;

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
    await waitFor(() => localAdapter.client.status == Status.online);
    await waitFor(() => localAdapter.client.bots.isNotEmpty);
    await waitFor(() => localAdapter.bots.isNotEmpty);

    // --- WEBHOOK RECEIVER ---
    webhookReceiver = await _startWebhookReceiver();
    print('Webhook receiver listening on port ${webhookReceiver.port}');

    // --- LOCAL SERVER with webhook ---
    localServer = SatoriServer(
      adapter: localAdapter,
      token: 'local-token',
      resumeTimeout: const Duration(minutes: 1),
      onEventPublished: localAdapter.onEventPublished,
      webhooks: [
        SatoriWebhook(
          url: 'http://127.0.0.1:${webhookReceiver.port}/webhook',
          token: 'webhook-token',
          enabled: true,
        ),
      ],
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
    await waitFor(() => localClient.status == Status.online);
    await waitFor(() => localClient.bots.isNotEmpty);
  });

  tearDownAll(() async {
    await localClient.close();
    await localServer.close();
    await localAdapter.stop();
    await remoteServer.close();
    await remoteAdapter.close();
    await webhookReceiver.close();
    httpClient.close(force: true);
  });

  group('Step 9: webhook across the bridge', () {
    test('remote event triggers webhook on local server', () async {
      // Emit event from remote bot
      remoteAdapter.emit(
        Event(
          type: 'message-created',
          login: remoteBot.login,
          selfId: 'remote-1',
          message: Message(
            id: 'msg-webhook-1',
            content: 'hello from remote via webhook',
          ),
        ),
      );

      // Wait for webhook to receive the POST
      await waitFor(() => webhookReceiver.receivedPosts.isNotEmpty);

      // Verify the webhook received the event
      expect(webhookReceiver.receivedPosts.length, 1);
      final post = webhookReceiver.receivedPosts.single;

      // Verify body contains the event
      final body = post['body'] as Map<String, dynamic>;
      expect(body['type'], 'message-created'); // canonical alias applied
      expect(body['login']['platform'], 'telegram');
      expect(body['message']['content'], 'hello from remote via webhook');
      expect(body['sn'], isNotNull);
      expect(body['sn'], greaterThan(0));

      // Verify Satori-Opcode header is present (Opcode.event.value = 0)
      final headers = post['headers'] as Map<String, String>;
      expect(headers['satori-opcode'], '0');

      // Verify Authorization header with webhook token
      expect(headers['authorization'], 'Bearer webhook-token');
    });

    test('webhook receives multiple events from remote', () async {
      // Clear previous posts
      webhookReceiver.receivedPosts.clear();

      // Emit multiple events from remote bot
      for (var i = 1; i <= 3; i++) {
        remoteAdapter.emit(
          Event(
            type: 'message-created',
            login: remoteBot.login,
            selfId: 'remote-1',
            message: Message(id: 'msg-multi-$i', content: 'message $i'),
          ),
        );
      }

      // Wait for webhook to receive all events
      await waitFor(() => webhookReceiver.receivedPosts.length >= 3);

      expect(webhookReceiver.receivedPosts.length, 3);

      // Verify each event has the correct structure
      for (var i = 0; i < 3; i++) {
        final post = webhookReceiver.receivedPosts[i];
        final body = post['body'] as Map<String, dynamic>;
        expect(body['type'], 'message-created');
        expect(body['message']['content'], 'message ${i + 1}');
        expect(body['sn'], isNotNull);
        expect(body['sn'], greaterThan(i));

        final headers = post['headers'] as Map<String, String>;
        expect(headers['satori-opcode'], '0');
      }
    });

    test('disabled webhook does not receive events', () async {
      // Add a disabled webhook by creating a new server with it
      // (since _webhooks is private, we create a fresh server instance)
      final disabledReceiver = await _startWebhookReceiver();
      addTearDown(disabledReceiver.close);

      // Create a separate server with disabled webhook for this test
      final disabledServer = SatoriServer(
        adapter: localAdapter,
        token: 'local-token',
        resumeTimeout: const Duration(minutes: 1),
        onEventPublished: localAdapter.onEventPublished,
        webhooks: [
          SatoriWebhook(
            url: 'http://127.0.0.1:${disabledReceiver.port}/webhook',
            enabled: false,
          ),
        ],
      );
      await disabledServer.bind(address: InternetAddress.loopbackIPv4, port: 0);
      addTearDown(disabledServer.close);

      // Clear previous posts from both receivers
      webhookReceiver.receivedPosts.clear();
      disabledReceiver.receivedPosts.clear();

      // Emit event from remote - it goes through localServer which has the enabled webhook
      remoteAdapter.emit(
        Event(
          type: 'message-created',
          login: remoteBot.login,
          selfId: 'remote-1',
          message: Message(id: 'msg-disabled', content: 'test disabled'),
        ),
      );

      await waitFor(() => webhookReceiver.receivedPosts.isNotEmpty);

      // Enabled webhook on main server should receive
      expect(webhookReceiver.receivedPosts.length, 1);
      // Disabled webhook on separate server should NOT receive
      expect(disabledReceiver.receivedPosts.length, 0);
    });
  });
}
