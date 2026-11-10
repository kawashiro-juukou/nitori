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

void main() {
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
  });

  Future<_Connection> connect() async =>
      _Connection(await WebSocket.connect('ws://127.0.0.1:$port/v1/events'));

  Future<_Connection> identify({String token = 'secret', int? sn}) async {
    final connection = await connect();
    await waitFor(() => connection.frames.isNotEmpty);
    connection.send(3, <String, dynamic>{
      'token': token,
      if (sn != null) 'sn': sn,
    });
    await waitFor(() => connection.frames.any((frame) => frame['op'] == 4));
    return connection;
  }

  test('sends META with the proxy URLs on connect', () async {
    final connection = await connect();
    await waitFor(() => connection.frames.isNotEmpty);

    final meta = connection.frame(5);
    expect(meta['body'], <String, dynamic>{
      'proxy_urls': <String>['http://proxy.example'],
    });

    await connection.close();
  });

  test('IDENTIFY answers READY with logins and proxy URLs', () async {
    final connection = await identify();

    final ready = connection.frame(4)['body'] as Map<String, dynamic>;
    expect(ready['proxy_urls'], <String>['http://proxy.example']);
    final logins = ready['logins'] as List<dynamic>;
    expect(logins, hasLength(1));
    expect(logins.single['sn'], 1);
    expect(logins.single['platform'], 'memory');
    expect((logins.single['user'] as Map<String, dynamic>)['id'], 'bot-1');

    await connection.close();
  });

  test('an invalid token closes the connection with 4004', () async {
    final connection = await connect();
    await waitFor(() => connection.frames.isNotEmpty);
    final done = connection.socket.done;

    connection.send(3, <String, dynamic>{'token': 'wrong'});
    await done.timeout(const Duration(seconds: 3));

    expect(connection.socket.closeCode, 4004);
  });

  test('PING answers PONG', () async {
    final connection = await identify();

    connection.send(1);
    await waitFor(() => connection.frames.any((frame) => frame['op'] == 2));

    expect(connection.frame(2)['body'], <String, dynamic>{});
    await connection.close();
  });

  test('adapter events are broadcast with incrementing sn', () async {
    final connection = await identify();

    adapter.emit(Event(
      type: 'message-created',
      login: bot.login,
      selfId: 'bot-1',
      message: Message(id: 'm1', content: 'hi'),
    ));
    adapter.emit(Event(type: 'message-deleted', login: bot.login));

    await waitFor(
        () => connection.frames.where((frame) => frame['op'] == 0).length >= 2);
    final events = connection.frames
        .where((frame) => frame['op'] == 0)
        .map((frame) => frame['body'] as Map<String, dynamic>)
        .toList();

    expect(events[0]['sn'], 1);
    expect(events[0]['type'], 'message-created');
    expect((events[0]['message'] as Map<String, dynamic>)['id'], 'm1');
    expect(events[1]['sn'], 2);
    expect(events[1]['type'], 'message-deleted');

    await connection.close();
  });

  test('reconnect replays buffered events after the last sn', () async {
    final first = await identify();
    await first.socket.close();
    await first.socket.done;

    adapter.emit(Event(type: 'channel-added', login: bot.login));
    adapter.emit(Event(type: 'channel-deleted', login: bot.login));

    final second = await identify(sn: 1);
    await waitFor(
        () => second.frames.where((frame) => frame['op'] == 0).isNotEmpty);
    final replayed = second.frames
        .where((frame) => frame['op'] == 0)
        .map((frame) => frame['body'] as Map<String, dynamic>)
        .toList();

    expect(replayed, hasLength(1));
    expect(replayed.single['sn'], 2);
    expect(replayed.single['type'], 'channel-deleted');

    await second.close();
  });
}
