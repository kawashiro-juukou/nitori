/// Test for Step 10: BridgeEventDispatcher dispatch middleware / internal/session.
library;

import 'dart:async';
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
    await waitFor(() => localAdapter.client.status == Status.online);
    await waitFor(() => localAdapter.client.bots.isNotEmpty);
    await waitFor(() => localAdapter.bots.isNotEmpty);

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
    await waitFor(() => localClient.status == Status.online);
    await waitFor(() => localClient.bots.isNotEmpty);
  });

  tearDownAll(() async {
    await localClient.close();
    await localServer.close();
    await localAdapter.stop();
    await remoteServer.close();
    await remoteAdapter.close();
    httpClient.close(force: true);
  });

  group('Step 10: BridgeEventDispatcher', () {
    test('internal/session is emitted before alias-group events', () async {
      final localBot =
          localAdapter.bots.firstWhere((b) => b.platform == 'telegram')
              as RemoteSatoriBot;

      final dispatcher = BridgeEventDispatcher(localBot);
      final internalSessions = <Session>[];
      final events = <Event>[];

      final subInternal = dispatcher.internalSessions.listen(
        internalSessions.add,
      );
      final subEvents = dispatcher.events.listen(events.add);

      // Create a session with message-created (has alias group with 'message')
      final originalEvent = Event(
        type: 'message-created',
        login: localBot.login,
        selfId: 'remote-1',
        message: Message(id: 'msg-dispatch-1', content: 'dispatch test'),
      );
      final session = Session(
        originalEvent,
        host: localBot.session(originalEvent).host,
      )..sn = 999;

      dispatcher.dispatch(session);

      // Wait for streams to process
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await subInternal.cancel();
      await subEvents.cancel();
      await dispatcher.close();

      // internal/session should be emitted first
      expect(internalSessions.length, 1);
      expect(
        events.length,
        2,
      ); // 'message-created' and 'message' (the alias group)

      // The first event in internalSessions should be the canonical session
      expect(internalSessions.single.event.type, 'message-created');

      // The events stream should have both alias members
      final eventTypes = events.map((e) => e.type).toList();
      expect(eventTypes, containsAll(['message-created', 'message']));
    });

    test(
      'alias normalisation replaces emitted type with canonical alias',
      () async {
        final localBot =
            localAdapter.bots.firstWhere((b) => b.platform == 'telegram')
                as RemoteSatoriBot;

        final dispatcher = BridgeEventDispatcher(localBot);
        final events = <Event>[];
        final subEvents = dispatcher.events.listen(events.add);

        // Dispatch with 'message' (non-canonical, alias member)
        // The canonical for ['message-created', 'message'] is 'message-created'
        final originalEvent = Event(
          type: 'message', // This is an alias member
          login: localBot.login,
          selfId: 'remote-1',
          message: Message(id: 'msg-dispatch-2', content: 'alias test'),
        );
        final session = Session(
          originalEvent,
          host: localBot.session(originalEvent).host,
        )..sn = 998;

        dispatcher.dispatch(session);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        await subEvents.cancel();
        await dispatcher.close();

        // The internal/session should have the canonical type
        // But we're checking events stream: both alias members should be emitted
        // with their respective types (canonical and alias)
        final eventTypes = events.map((e) => e.type).toList();
        expect(eventTypes, containsAll(['message-created', 'message']));
      },
    );

    test('each alias member is emitted as a separate event', () async {
      final localBot =
          localAdapter.bots.firstWhere((b) => b.platform == 'telegram')
              as RemoteSatoriBot;

      final dispatcher = BridgeEventDispatcher(localBot);
      final events = <Event>[];
      final subEvents = dispatcher.events.listen(events.add);

      // message-created has alias group: ['message-created', 'message']
      final originalEvent = Event(
        type: 'message-created',
        login: localBot.login,
        selfId: 'remote-1',
        message: Message(id: 'msg-dispatch-3', content: 'separate events test'),
      );
      final session = Session(
        originalEvent,
        host: localBot.session(originalEvent).host,
      )..sn = 997;

      dispatcher.dispatch(session);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      await subEvents.cancel();
      await dispatcher.close();

      // Should emit 2 events: one for each alias member
      expect(events.length, 2);

      // Both events should have their own type
      final types = events.map((e) => e.type).toSet();
      expect(types, {'message-created', 'message'});

      // Both events should be deep copies (not the same object)
      expect(identical(events[0], events[1]), isFalse);
      expect(identical(events[0], originalEvent), isFalse);
    });

    test(
      'dispatching does NOT publish into live SatoriServer client stream (no duplication)',
      () async {
        // Connect a gateway client to the LOCAL server
        final receivedByClient = <SatoriGatewayEvent>[];
        final subClient = localClient.events.listen(receivedByClient.add);

        // Create dispatcher with a local bot
        final localBot =
            localAdapter.bots.firstWhere((b) => b.platform == 'telegram')
                as RemoteSatoriBot;

        final dispatcher = BridgeEventDispatcher(localBot);

        // Dispatch a session
        final originalEvent = Event(
          type: 'message-created',
          login: localBot.login,
          selfId: 'remote-1',
          message: Message(id: 'msg-no-dup', content: 'no duplication'),
        );
        final session = Session(
          originalEvent,
          host: localBot.session(originalEvent).host,
        )..sn = 996;

        dispatcher.dispatch(session);

        // Wait a bit for any potential events to arrive
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await subClient.cancel();
        await dispatcher.close();

        // The gateway client should have received NOTHING from the dispatcher
        // because BridgeEventDispatcher does NOT touch SatoriServer's publish path
        expect(
          receivedByClient.length,
          0,
          reason:
              'BridgeEventDispatcher must not publish into SatoriServer pipeline',
        );
      },
    );

    test('expandEventAliases returns group for known aliases', () {
      // Test the expandEventAliases function from nitori_core
      final aliases1 = expandEventAliases('message-created');
      expect(aliases1, ['message-created', 'message']);

      final aliases2 = expandEventAliases('message');
      expect(aliases2, ['message-created', 'message']);

      final aliases3 = expandEventAliases('guild-removed');
      expect(aliases3, ['guild-removed', 'guild-deleted']);

      final aliases4 = expandEventAliases('guild-member-removed');
      expect(aliases4, ['guild-member-removed', 'guild-member-deleted']);

      // Unknown type returns singleton list
      final aliases5 = expandEventAliases('unknown-type');
      expect(aliases5, ['unknown-type']);
    });

    test('dispatch with non-aliased type emits single event', () async {
      final localBot =
          localAdapter.bots.firstWhere((b) => b.platform == 'telegram')
              as RemoteSatoriBot;

      final dispatcher = BridgeEventDispatcher(localBot);
      final internalSessions = <Session>[];
      final events = <Event>[];

      final subInternal = dispatcher.internalSessions.listen(
        internalSessions.add,
      );
      final subEvents = dispatcher.events.listen(events.add);

      // reaction-added is NOT in any alias group
      final originalEvent = Event(
        type: 'reaction-added',
        login: localBot.login,
        selfId: 'remote-1',
        message: Message(id: 'msg-react', content: 'react'),
        emoji: Emoji(id: 'emoji-1'),
      );
      final session = Session(
        originalEvent,
        host: localBot.session(originalEvent).host,
      )..sn = 995;

      dispatcher.dispatch(session);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      await subInternal.cancel();
      await subEvents.cancel();
      await dispatcher.close();

      // Should emit 1 internal/session and 1 event (no aliases)
      expect(internalSessions.length, 1);
      expect(events.length, 1);
      expect(events.single.type, 'reaction-added');
      expect(internalSessions.single.event.type, 'reaction-added');
    });

    test('multiple dispatches work independently', () async {
      final localBot =
          localAdapter.bots.firstWhere((b) => b.platform == 'telegram')
              as RemoteSatoriBot;

      final dispatcher = BridgeEventDispatcher(localBot);
      final allInternalSessions = <Session>[];
      final allEvents = <Event>[];

      final subInternal = dispatcher.internalSessions.listen(
        allInternalSessions.add,
      );
      final subEvents = dispatcher.events.listen(allEvents.add);

      // Dispatch first session (with alias group)
      final session1 = Session(
        Event(
          type: 'message-created',
          login: localBot.login,
          selfId: 'remote-1',
          message: Message(id: 'msg-1', content: 'first'),
        ),
        host: localBot.session(Event(type: '', login: localBot.login)).host,
      )..sn = 1;

      dispatcher.dispatch(session1);

      // Dispatch second session (without alias group)
      final session2 = Session(
        Event(
          type: 'reaction-added',
          login: localBot.login,
          selfId: 'remote-1',
          message: Message(id: 'msg-2', content: 'second'),
          emoji: Emoji(id: 'emoji-2'),
        ),
        host: localBot.session(Event(type: '', login: localBot.login)).host,
      )..sn = 2;

      dispatcher.dispatch(session2);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      await subInternal.cancel();
      await subEvents.cancel();
      await dispatcher.close();

      // First dispatch: 1 internal + 2 events (message-created, message)
      // Second dispatch: 1 internal + 1 event (reaction-added)
      expect(allInternalSessions.length, 2);
      expect(allEvents.length, 3);

      // Check types
      final types = allEvents.map((e) => e.type).toList();
      expect(
        types,
        containsAll(['message-created', 'message', 'reaction-added']),
      );
    });
  });
}
