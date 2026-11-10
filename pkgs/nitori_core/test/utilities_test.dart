import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

void main() {
  group('transformKey', () {
    test('renames every key of a nested object', () {
      final source = <String, dynamic>{
        'channel_id': 'c1',
        'user': {'id': 'u1', 'is_bot': true},
      };

      expect(transformKey(source, cashConvertSnakeToCamel), <String, dynamic>{
        'channelId': 'c1',
        'user': {'id': 'u1', 'isBot': true},
      });
    });

    test('renames keys inside arrays', () {
      final source = <dynamic>[
        {'channel_id': 'c1'},
        {'created_at': 0},
      ];

      expect(transformKey(source, cashConvertSnakeToCamel), <dynamic>[
        {'channelId': 'c1'},
        {'createdAt': 0},
      ]);
    });

    test('leaves keys prefixed with _ untouched', () {
      final source = <String, dynamic>{
        '_data': {'channel_id': 'c1'},
        'channel_id': 'c1',
      };

      expect(transformKey(source, cashConvertSnakeToCamel), <String, dynamic>{
        '_data': {'channel_id': 'c1'},
        'channelId': 'c1',
      });
    });

    test('leaves referrer untouched, even when nested', () {
      final source = <String, dynamic>{
        'referrer': {'guild_id': 'g1'},
        'nested': {
          'referrer': {'channel_id': 'c1'}
        },
      };

      expect(transformKey(source, cashConvertSnakeToCamel), <String, dynamic>{
        'referrer': {'guild_id': 'g1'},
        'nested': {
          'referrer': {'channel_id': 'c1'}
        },
      });
    });

    test('passes primitives through unchanged', () {
      expect(transformKey(null, cashConvertSnakeToCamel), null);
      expect(transformKey(42, cashConvertSnakeToCamel), 42);
      expect(transformKey('channel_id', cashConvertSnakeToCamel), 'channel_id');
    });

    test('round-trips with the inverse transform', () {
      final source = <String, dynamic>{
        'channel_id': 'c1',
        'user': {'is_bot': true},
        '_data': {'x': 1},
      };

      final camel =
          transformKey(source, cashConvertSnakeToCamel) as Map<String, dynamic>;
      final snake =
          transformKey(camel, cashConvertCamelToSnake) as Map<String, dynamic>;

      expect(snake['channel_id'], 'c1');
      expect((snake['user'] as Map)['is_bot'], true);
      expect(snake['_data'], {'x': 1});
    });
  });

  group('key case converters', () {
    test('cashConvertSnakeToCamel', () {
      expect(cashConvertSnakeToCamel('channel_id'), 'channelId');
      expect(cashConvertSnakeToCamel('is_bot'), 'isBot');
      expect(cashConvertSnakeToCamel('id'), 'id');
      expect(cashConvertSnakeToCamel('a_b_c'), 'aBC');
    });

    test('cashConvertCamelToSnake', () {
      expect(cashConvertCamelToSnake('channelId'), 'channel_id');
      expect(cashConvertCamelToSnake('isBot'), 'is_bot');
      expect(cashConvertCamelToSnake('id'), 'id');
    });
  });

  group('Methods registry', () {
    test('covers every upstream resource.method key', () {
      expect(methods.keys.toSet(), methodKeys.toSet());
      expect(methodKeys.length, 37);
    });

    test('maps each key to the upstream method name and fields', () {
      const expected = <String, Method>{
        'channel.get': Method('getChannel', ['channel_id', 'guild_id']),
        'channel.list': Method('getChannelList', ['guild_id', 'next']),
        'channel.create': Method('createChannel', ['guild_id', 'data']),
        'channel.update': Method('updateChannel', ['channel_id', 'data']),
        'channel.delete': Method('deleteChannel', ['channel_id']),
        'channel.mute':
            Method('muteChannel', ['channel_id', 'guild_id', 'enable']),
        'message.create':
            Method('createMessage', ['channel_id', 'content', 'referrer']),
        'message.update':
            Method('editMessage', ['channel_id', 'message_id', 'content']),
        'message.delete': Method('deleteMessage', ['channel_id', 'message_id']),
        'message.get': Method('getMessage', ['channel_id', 'message_id']),
        'message.list': Method('getMessageList',
            ['channel_id', 'next', 'direction', 'limit', 'order']),
        'reaction.create':
            Method('createReaction', ['channel_id', 'message_id', 'emoji_id']),
        'reaction.delete': Method('deleteReaction',
            ['channel_id', 'message_id', 'emoji_id', 'user_id']),
        'reaction.clear':
            Method('clearReaction', ['channel_id', 'message_id', 'emoji_id']),
        'reaction.list': Method('getReactionList',
            ['channel_id', 'message_id', 'emoji_id', 'next']),
        'upload.create': Method('createUpload', [], isForm: true),
        'guild.get': Method('getGuild', ['guild_id']),
        'guild.list': Method('getGuildList', ['next']),
        'guild.member.get': Method('getGuildMember', ['guild_id', 'user_id']),
        'guild.member.list': Method('getGuildMemberList', ['guild_id', 'next']),
        'guild.member.kick':
            Method('kickGuildMember', ['guild_id', 'user_id', 'permanent']),
        'guild.member.mute': Method(
            'muteGuildMember', ['guild_id', 'user_id', 'duration', 'reason']),
        'guild.member.role.set':
            Method('setGuildMemberRole', ['guild_id', 'user_id', 'role_id']),
        'guild.member.role.unset':
            Method('unsetGuildMemberRole', ['guild_id', 'user_id', 'role_id']),
        'guild.member.role.list':
            Method('getGuildMemberRoleList', ['guild_id', 'user_id', 'next']),
        'guild.role.list': Method('getGuildRoleList', ['guild_id', 'next']),
        'guild.role.create': Method('createGuildRole', ['guild_id', 'data']),
        'guild.role.update':
            Method('updateGuildRole', ['guild_id', 'role_id', 'data']),
        'guild.role.delete': Method('deleteGuildRole', ['guild_id', 'role_id']),
        'login.get': Method('getLogin', []),
        'user.get': Method('getUser', ['user_id']),
        'user.channel.create':
            Method('createDirectChannel', ['user_id', 'guild_id']),
        'friend.list': Method('getFriendList', ['next']),
        'friend.delete': Method('deleteFriend', ['user_id']),
        'friend.approve':
            Method('handleFriendRequest', ['message_id', 'approve', 'comment']),
        'guild.approve':
            Method('handleGuildRequest', ['message_id', 'approve', 'comment']),
        'guild.member.approve': Method(
            'handleGuildMemberRequest', ['message_id', 'approve', 'comment']),
      };

      expected.forEach((key, method) {
        expect(methods[key], method, reason: '$key should match upstream');
      });
    });

    test('only upload.create is a form', () {
      final formMethods = methods.entries
          .where((entry) => entry.value.isForm)
          .map((entry) => entry.key)
          .toList();

      expect(formMethods, ['upload.create']);
    });
  });

  group('Direction / Order', () {
    test('carry the documented wire values', () {
      expect(Direction.values.map((d) => d.value).toList(),
          ['before', 'after', 'around']);
      expect(Order.values.map((o) => o.value).toList(), ['asc', 'desc']);
    });
  });
}
