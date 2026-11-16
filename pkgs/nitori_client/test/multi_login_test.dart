/// Multi-login management tests for [NitoriClient].
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:nitori_core/nitori_core.dart';
import 'package:nitori_client/nitori_client.dart';

class _MockHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value(const <int>[]), 200);
  }
}

void main() {
  group('NitoriClient multi-login', () {
    late NitoriClient client;

    setUp(() {
      client = NitoriClient(
        baseUrl: 'http://localhost:5140',
        httpClient: _MockHttpClient(),
      );
    });

    tearDown(() async {
      await client.close();
    });

    test('getBot returns bot when platform and userId match', () {
      final login1 = Login(
        status: Status.online,
        sn: 1,
        platform: 'discord',
        user: User(id: 'user1', name: 'User One'),
      );
      client.addBot(login1);

      final bot = client.getBot('discord', 'user1');
      expect(bot, isNotNull);
      expect(bot!.platform, equals('discord'));
      expect(bot.userId, equals('user1'));
    });

    test('getBot returns null when not found', () {
      final bot = client.getBot('discord', 'nonexistent');
      expect(bot, isNull);
    });

    test('addBot adds a new bot', () {
      final login = Login(
        status: Status.online,
        sn: 1,
        platform: 'discord',
        user: User(id: 'user1', name: 'User One'),
      );
      client.addBot(login);

      expect(client.bots.length, equals(1));
      expect(client.bots.first.login?.sn, equals(1));
      expect(client.bots.first.platform, equals('discord'));
      expect(client.bots.first.userId, equals('user1'));
    });

    test('addBot does not duplicate when sn exists', () {
      final login = Login(
        status: Status.online,
        sn: 1,
        platform: 'discord',
        user: User(id: 'user1', name: 'User One'),
      );
      client.addBot(login);
      client.addBot(login); // same sn

      expect(client.bots.length, equals(1));
    });

    test('removeBot removes bot by sn', () {
      final login = Login(
        status: Status.online,
        sn: 1,
        platform: 'discord',
        user: User(id: 'user1', name: 'User One'),
      );
      client.addBot(login);
      expect(client.bots.length, equals(1));

      client.removeBot(1);
      expect(client.bots.length, equals(0));
    });

    test('removeBot does nothing when sn not found', () {
      client.removeBot(999);
      expect(client.bots.length, equals(0));
    });

    test('botsByPlatform filters by platform', () {
      final login1 = Login(
        status: Status.online,
        sn: 1,
        platform: 'discord',
        user: User(id: 'user1', name: 'User One'),
      );
      final login2 = Login(
        status: Status.online,
        sn: 2,
        platform: 'telegram',
        user: User(id: 'user2', name: 'User Two'),
      );
      final login3 = Login(
        status: Status.online,
        sn: 3,
        platform: 'discord',
        user: User(id: 'user3', name: 'User Three'),
      );
      client.addBot(login1);
      client.addBot(login2);
      client.addBot(login3);

      final discordBots = client.botsByPlatform('discord').toList();
      expect(discordBots.length, equals(2));
      expect(discordBots.every((b) => b.platform == 'discord'), isTrue);

      final telegramBots = client.botsByPlatform('telegram').toList();
      expect(telegramBots.length, equals(1));
      expect(telegramBots.first.platform, equals('telegram'));

      final emptyBots = client.botsByPlatform('slack').toList();
      expect(emptyBots, isEmpty);
    });
  });
}
