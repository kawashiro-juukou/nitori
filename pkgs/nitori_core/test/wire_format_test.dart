import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

/// Locks the numeric values the protocol puts on the wire. These guards exist
/// because the enum order was previously wrong for direct/voice and the status
/// codes were serialized as their names instead of integers.
void main() {
  group('ChannelType', () {
    test('matches the protocol order', () {
      expect(ChannelType.values.map((type) => type.value).toList(), [
        0,
        1,
        2,
        3,
      ]);
      expect(ChannelType.text.value, 0);
      expect(ChannelType.direct.value, 1);
      expect(ChannelType.category.value, 2);
      expect(ChannelType.voice.value, 3);
    });

    test('serializes as an integer', () {
      expect(Channel(id: 'c', type: ChannelType.direct).toJson()['type'], 1);
      expect(Channel(id: 'c', type: ChannelType.voice).toJson()['type'], 3);
    });

    test('deserializes from an integer', () {
      expect(
        Channel.fromJson(const {'id': 'c', 'type': 1}).type,
        ChannelType.direct,
      );
      expect(
        Channel.fromJson(const {'id': 'c', 'type': 3}).type,
        ChannelType.voice,
      );
    });
  });

  group('Status', () {
    test('matches the protocol order', () {
      expect(Status.values.map((status) => status.value).toList(), [
        0,
        1,
        2,
        3,
        4,
      ]);
      expect(Status.offline.value, 0);
      expect(Status.online.value, 1);
      expect(Status.connect.value, 2);
      expect(Status.disconnect.value, 3);
      expect(Status.reconnect.value, 4);
    });

    test('serializes as an integer, not as a name', () {
      final login = Login(status: Status.reconnect);

      expect(login.toJson()['status'], 4);
    });

    test('deserializes from an integer', () {
      expect(Login.fromJson(const {'status': 0}).status, Status.offline);
      expect(Login.fromJson(const {'status': 4}).status, Status.reconnect);
    });
  });

  group('Opcode', () {
    test('matches the protocol values', () {
      expect(Opcode.values.map((op) => op.value).toList(), [0, 1, 2, 3, 4, 5]);
      expect(Opcode.event.value, 0);
      expect(Opcode.identify.value, 3);
      expect(Opcode.meta.value, 5);
    });
  });

  group('millisecond timestamps', () {
    test('Message keeps the raw wire number', () {
      final message = Message.fromJson(const {
        'id': 'm',
        'created_at': 1663045572000,
        'updated_at': 1663045573000,
      });

      expect(message.createdAt, isA<int>());
      expect(message.createdAt, 1663045572000);
      expect(message.toJson()['created_at'], 1663045572000);
    });

    test('GuildMember keeps the raw wire number', () {
      final member = GuildMember.fromJson(const {
        'user': {'id': 'u'},
        'joined_at': 1663045572000,
      });

      expect(member.joinedAt, isA<int>());
      expect(member.joinedAt, 1663045572000);
      expect(member.toJson()['joined_at'], 1663045572000);
    });
  });

  group('GuildRole permissions', () {
    test('survives a value beyond 2^53', () {
      const wire = '9007199254740993';

      final role = GuildRole(id: 'role-1', permissions: BigInt.parse(wire));

      expect(role.toJson()['permissions'], wire);
    });
  });
}
