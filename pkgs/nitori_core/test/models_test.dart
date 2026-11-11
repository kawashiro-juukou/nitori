import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

/// Wire samples use the field names of the official Satori documentation
/// (snake_case), with the numeric enum values defined by the protocol.
void main() {
  group('User', () {
    test('round-trips the documented fields', () {
      const json = <String, dynamic>{
        'id': 'user-1',
        'name': 'Lucy',
        'nick': 'lu',
        'avatar': 'https://satori.chat/avatar.png',
        'is_bot': false,
      };

      final user = User.fromJson(json);

      expect(user.id, 'user-1');
      expect(user.nick, 'lu');
      expect(user.isBot, isFalse);
      expect(user.toJson(), json);
    });

    test('keeps discriminator when present', () {
      const json = <String, dynamic>{'id': 'u', 'discriminator': '0001'};

      expect(User.fromJson(json).discriminator, '0001');
    });
  });

  group('Guild', () {
    test('round-trips', () {
      const json = <String, dynamic>{
        'id': 'guild-1',
        'name': 'Nitori',
        'avatar': 'https://satori.chat/guild.png',
      };

      expect(Guild.fromJson(json).toJson(), json);
    });
  });

  group('Channel', () {
    test('round-trips an optional name and position', () {
      const json = <String, dynamic>{
        'id': 'channel-1',
        'type': 0,
        'name': 'general',
        'parent_id': 'category-1',
        'position': 3,
      };

      final channel = Channel.fromJson(json);

      expect(channel.type, ChannelType.text);
      expect(channel.name, 'general');
      expect(channel.position, 3);
      expect(channel.toJson(), json);
    });

    test('omits nothing when name is absent', () {
      const json = <String, dynamic>{'id': 'channel-1', 'type': 3};

      final channel = Channel.fromJson(json);

      expect(channel.name, isNull);
      expect(channel.toJson(), json);
    });
  });

  group('GuildRole', () {
    test('round-trips all fields with permissions as a string', () {
      const json = <String, dynamic>{
        'id': 'role-1',
        'name': 'admin',
        'color': 4286945,
        'position': 1,
        'permissions': '1099511627775',
        'hoist': true,
        'mentionable': true,
      };

      final role = GuildRole.fromJson(json);

      expect(role.permissions, BigInt.parse('1099511627775'));
      expect(role.toJson(), json);
    });
  });

  group('GuildMember', () {
    test('round-trips a millisecond joined_at', () {
      const json = <String, dynamic>{
        'user': {'id': 'user-1', 'name': 'Lucy'},
        'name': 'Lucy',
        'nick': 'lu',
        'avatar': 'https://satori.chat/avatar.png',
        'title': 'boss',
        'joined_at': 1663045572000,
        'roles': [
          {'id': 'role-1', 'name': 'admin'}
        ],
      };

      final member = GuildMember.fromJson(json);

      expect(member.joinedAt, 1663045572000);
      expect(member.roles, hasLength(1));
      expect(member.roles!.single.name, 'admin');
      expect(member.toJson(), json);
    });
  });

  group('Login', () {
    test('round-trips the full login payload', () {
      const json = <String, dynamic>{
        'sn': 45,
        'adapter': 'discord',
        'status': 1,
        'user': {'id': 'user-1', 'name': 'Lucy'},
        'platform': 'discord',
        'features': ['guild', 'channel'],
        'hidden': false,
      };

      final login = Login.fromJson(json);

      expect(login.status, Status.online);
      expect(login.adapter, 'discord');
      expect(login.features, ['guild', 'channel']);
      expect(login.toJson(), json);
    });
  });

  group('Message', () {
    test('round-trips nested resources as JSON objects', () {
      const json = <String, dynamic>{
        'id': 'message-1',
        'content': 'hello',
        'channel': {'id': 'channel-1', 'type': 0},
        'guild': {'id': 'guild-1', 'name': 'Nitori'},
        'user': {'id': 'user-1', 'name': 'Lucy'},
        'member': {
          'user': {'id': 'user-1'},
          'nick': 'lu'
        },
        'timestamp': 1663045572000,
        'created_at': 1663045572000,
        'updated_at': 1663045573000,
      };

      final message = Message.fromJson(json);
      final encoded = message.toJson();

      expect(encoded['channel'], isA<Map<String, dynamic>>());
      expect(encoded['guild'], isA<Map<String, dynamic>>());
      expect(encoded['member'], isA<Map<String, dynamic>>());
      expect(encoded['user'], isA<Map<String, dynamic>>());
      expect(encoded, json);
    });

    test('serializes a recursively nested quote', () {
      const json = <String, dynamic>{
        'id': 'message-2',
        'content': 'outer',
        'quote': {
          'id': 'message-1',
          'content': 'inner',
          'quote': {
            'id': 'message-0',
            'content': 'deepest',
          },
        },
      };

      final message = Message.fromJson(json);
      final encoded = message.toJson();

      expect(encoded['quote'], isA<Map<String, dynamic>>());
      expect((encoded['quote'] as Map)['quote'], isA<Map<String, dynamic>>());
      expect((encoded['quote'] as Map)['quote']['content'], 'deepest');
      expect(encoded, json);
    });

    test('round-trips structured elements as element maps', () {
      final elements = <Map<String, Object?>>[
        {
          'tag': 'text',
          'attrs': <String, Object?>{},
          'children': <Object?>[],
        },
        {
          'tag': 'img',
          'attrs': <String, Object?>{'src': 'https://example.com/a.png'},
          'children': <Object?>[],
        },
      ];

      final message = Message(id: 'message-1', elements: elements);
      final encoded = message.toJson();

      expect(encoded['elements'], isA<List<Map<String, Object?>>>());

      final decoded = Message.fromJson(encoded);

      expect(decoded.elements, isA<List<Map<String, Object?>>>());
      expect(decoded.elements, elements);
      expect(decoded.elements!.first['tag'], 'text');
      expect(decoded.elements!.last['attrs'],
          {'src': 'https://example.com/a.png'});
    });

    test('deepCopy isolates nested objects', () {
      const json = <String, dynamic>{
        'id': 'message-1',
        'content': 'hello',
        'channel': {'id': 'channel-1', 'type': 0},
        'guild': {'id': 'guild-1', 'name': 'Nitori'},
        'user': {'id': 'user-1', 'name': 'Lucy'},
        'member': {
          'user': {'id': 'user-1'},
          'nick': 'lu'
        },
        'timestamp': 1663045572000,
        'quote': {
          'id': 'message-0',
          'content': 'quoted',
        },
      };

      final original = Message.fromJson(json);
      final copy = original.deepCopy();

      // Mutate nested objects in the original
      original.channel!.name = 'modified';
      original.guild!.name = 'modified';
      original.user!.name = 'modified';
      original.member!.nick = 'modified';
      original.quote!.content = 'modified';

      // Copy should be unaffected
      expect(copy.channel!.name, isNull);
      expect(copy.guild!.name, 'Nitori');
      expect(copy.user!.name, 'Lucy');
      expect(copy.member!.nick, 'lu');
      expect(copy.quote!.content, 'quoted');

      // IDs and primitives should match
      expect(copy.id, original.id);
      expect(copy.content, original.content);
    });
  });

  group('Friend', () {
    test('round-trips', () {
      const json = <String, dynamic>{
        'user': {'id': 'user-1', 'name': 'Lucy'},
        'nick': 'lu',
      };

      expect(Friend.fromJson(json).toJson(), json);
    });
  });

  group('Button', () {
    test('round-trips', () {
      const json = <String, dynamic>{'id': 'button-1'};

      expect(Button.fromJson(json).toJson(), json);
    });
  });

  group('Event', () {
    test('deepCopy isolates all nested objects', () {
      const json = <String, dynamic>{
        'type': 'message',
        'sn': 1,
        'self_id': 'bot-1',
        'platform': 'discord',
        'timestamp': 1663045572000,
        'login': {
          'status': 1,
          'user': {'id': 'user-1', 'name': 'Lucy'},
          'platform': 'discord',
          'features': ['guild', 'channel'],
        },
        'channel': {'id': 'channel-1', 'type': 0},
        'guild': {'id': 'guild-1', 'name': 'Nitori'},
        'friend': {
          'user': {'id': 'user-1', 'name': 'Lucy'},
          'nick': 'lu',
        },
        'member': {
          'user': {'id': 'user-1', 'name': 'Lucy'},
          'nick': 'lu',
        },
        'message': {
          'id': 'message-1',
          'content': 'hello',
        },
        'operator': {'id': 'user-1', 'name': 'Lucy'},
        'emoji': {'id': 'emoji-1', 'name': 'smile'},
        'role': {'id': 'role-1', 'name': 'admin'},
        'user': {'id': 'user-1', 'name': 'Lucy'},
        'button': {'id': 'button-1'},
        '_type': 'custom-type',
        '_data': {'custom': 'data'},
      };

      final original = Event.fromJson(json);
      final copy = original.deepCopy();

      // Mutate nested objects in the original
      original.login!.user!.name = 'modified';
      original.channel!.name = 'modified';
      original.guild!.name = 'modified';
      original.friend!.nick = 'modified';
      original.member!.nick = 'modified';
      original.message!.content = 'modified';
      original.operator!.name = 'modified';
      original.emoji!.name = 'modified';
      original.role!.name = 'modified';
      original.user!.name = 'modified';
      original.button!.id = 'modified';

      // Copy should be unaffected
      expect(copy.login!.user!.name, 'Lucy');
      expect(copy.channel!.name, isNull);
      expect(copy.guild!.name, 'Nitori');
      expect(copy.friend!.nick, 'lu');
      expect(copy.member!.nick, 'lu');
      expect(copy.message!.content, 'hello');
      expect(copy.operator!.name, 'Lucy');
      expect(copy.emoji!.name, 'smile');
      expect(copy.role!.name, 'admin');
      expect(copy.user!.name, 'Lucy');
      expect(copy.button!.id, 'button-1');

      // Primitives should match
      expect(copy.type, original.type);
      expect(copy.sn, original.sn);
      expect(copy.selfId, original.selfId);
      expect(copy.platform, original.platform);
      expect(copy.timestamp, original.timestamp);
      expect(copy.eventType, original.eventType);
      expect(copy.eventData, original.eventData);
    });
  });

  group('Emoji', () {
    test('round-trips', () {
      const json = <String, dynamic>{'id': 'emoji-1', 'name': 'smile'};

      expect(Emoji.fromJson(json).toJson(), json);
    });
  });

  group('Pagination', () {
    test('reads a List payload', () {
      const json = <String, dynamic>{
        'data': [1, 2],
        'next': 'token-2'
      };

      final page = Pagination<int>.fromJson(json);

      expect(page.data, [1, 2]);
      expect(page.next, 'token-2');
      expect(page.prev, isNull);
    });

    test('reads a BidiList payload', () {
      const json = <String, dynamic>{
        'data': [1, 2, 3],
        'prev': 'token-0',
        'next': 'token-4',
      };

      final page = BidiList<int>.fromJson(json);

      expect(page.prev, 'token-0');
      expect(page.next, 'token-4');
      expect(page.toJson(), json);
    });
  });
}
