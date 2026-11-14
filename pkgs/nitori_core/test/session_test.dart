import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

class _FakeHost implements SessionHost {
  @override
  String get platform => 'fake';

  @override
  String get selfId => 'bot-1';

  @override
  Login get login =>
      Login(status: Status.online, platform: 'fake', sn: 5, adapter: 'fake');

  @override
  int get sequence => 42;
}

void main() {
  group('accessors', () {
    test('fall back to event fields', () {
      final session = Session(
        Event(
          type: 'message',
          selfId: 'bot-1',
          platform: 'onebot',
          timestamp: 123,
          user: User(id: 'u1'),
          channel: Channel(id: 'c1', type: ChannelType.text, name: 'general'),
          guild: Guild(id: 'g1', name: 'Nitori'),
          message: Message(
            id: 'm1',
            quote: Message(id: 'q0'),
          ),
          operator: User(id: 'op1'),
          role: GuildRole(id: 'r1'),
          referrer: 'ref',
        ),
      );

      expect(session.type, 'message');
      expect(session.platform, 'onebot');
      expect(session.selfId, 'bot-1');
      expect(session.timestamp, 123);
      expect(session.userId, 'u1');
      expect(session.channelId, 'c1');
      expect(session.channelName, 'general');
      expect(session.guildId, 'g1');
      expect(session.guildName, 'Nitori');
      expect(session.messageId, 'm1');
      expect(session.operatorId, 'op1');
      expect(session.roleId, 'r1');
      expect(session.quote!.id, 'q0');
      expect(session.referrer, 'ref');
    });

    test('host fills platform, selfId and timestamp', () {
      final session = Session(Event(type: 'message'), host: _FakeHost());

      expect(session.platform, 'fake');
      expect(session.selfId, 'bot-1');
      expect(session.timestamp, isNotNull);
      expect(session.sn, 42);
    });

    test('isDirect reads the channel type', () {
      final direct = Session(
        Event(
          type: 'message',
          channel: Channel(id: 'c1', type: ChannelType.direct),
        ),
      );
      final text = Session(
        Event(
          type: 'message',
          channel: Channel(id: 'c2', type: ChannelType.text),
        ),
      );

      expect(direct.isDirect, isTrue);
      expect(text.isDirect, isFalse);
      expect(Session(Event(type: 'message')).isDirect, isFalse);
    });

    test('author merges user and member', () {
      final session = Session(
        Event(
          type: 'message',
          user: User(id: 'u1', name: 'nitori'),
          member: GuildMember(
            user: User(id: 'u1'),
            nick: 'nickname',
          ),
        ),
      );

      expect(session.author.user.id, 'u1');
      expect(session.author.user.name, 'nitori');
      expect(session.author.nick, 'nickname');
    });
  });

  group('composite ids', () {
    test('format as platform:id', () {
      final session = Session(
        Event(
          type: 'message',
          platform: 'onebot',
          selfId: 'bot-1',
          user: User(id: 'u1'),
          channel: Channel(id: 'c1', type: ChannelType.text),
          guild: Guild(id: 'g1'),
        ),
      );

      expect(session.uid, 'onebot:u1');
      expect(session.gid, 'onebot:g1');
      expect(session.cid, 'onebot:c1');
      expect(session.fid, 'onebot:c1:u1');
      expect(session.sid, 'onebot:bot-1');
    });

    test('interpolates missing ids as the string "null"', () {
      final session = Session(
        Event(type: 'message', platform: 'onebot', selfId: 'bot-1'),
      );

      expect(session.uid, 'onebot:null');
      expect(session.gid, 'onebot:null');
      expect(session.cid, 'onebot:null');
      expect(session.fid, 'onebot:null:null');
      expect(session.sid, 'onebot:bot-1');
    });
  });

  group('content', () {
    test('round-trips plain text', () {
      final session = Session(Event(type: 'message'));

      session.content = 'hello';

      expect(session.content, 'hello');
      expect(session.event.message!.elements, <Map<String, Object?>>[
        {
          'type': 'text',
          'attrs': {'text': 'hello'},
        },
      ]);
    });

    test('round-trips text with an element', () {
      final session = Session(Event(type: 'message'));

      session.content = 'hello <at id="x"/>';

      expect(session.content, 'hello <at id="x"/>');
    });

    test('empty string parses to no elements', () {
      final session = Session(Event(type: 'message'));

      session.content = '';

      // Deviates from upstream (`join` of an empty array is `''`): no elements
      // parse, so the getter has nothing to join and returns null.
      expect(session.content, isNull);
      expect(session.event.message!.elements, isEmpty);
    });

    test('accepts null, clearing content', () {
      final session = Session(Event(type: 'message'));

      session.content = 'hello';
      session.content = null;

      expect(session.content, isNull);
      expect(session.event.message!.elements, isNull);
    });
  });

  group('quote extraction', () {
    test('extracts a leading quote element into message.quote', () {
      final session = Session(Event(type: 'message'));

      session.content = '<quote id="q1"/>hello';

      expect(session.quote!.id, 'q1');
      expect(session.event.message!.elements, <Map<String, Object?>>[
        {
          'type': 'text',
          'attrs': {'text': 'hello'},
        },
      ]);
      expect(session.content, 'hello');
    });
  });

  group('elements', () {
    test('round-trips through message element maps', () {
      final session = Session(Event(type: 'message'));

      session.elements = [
        ElementNode('text', text: 'hello'),
        ElementNode('at', attributes: {'id': 'x'}),
      ];

      expect(session.event.message!.elements, <Map<String, Object?>>[
        {
          'type': 'text',
          'attrs': {'text': 'hello'},
        },
        {
          'type': 'at',
          'attrs': {'id': 'x'},
        },
      ]);
      expect(session.elements, [
        ElementNode('text', text: 'hello'),
        ElementNode('at', attributes: {'id': 'x'}),
      ]);
    });

    test('returns null when no elements are stored', () {
      final session = Session(Event(type: 'message'));

      expect(session.elements, isNull);
    });
  });

  group('setInternal', () {
    test('writes the adapter-local discriminator and payload', () {
      final session = Session(Event(type: 'message'));

      session.setInternal('internal', {'x': 1});

      expect(session.event.eventType, 'internal');
      expect(session.event.eventData, {'x': 1});
    });
  });

  group('toJSON', () {
    test('injects sn and login from the host', () {
      final session = Session(
        Event(type: 'message', selfId: 'bot-1', platform: 'fake'),
        host: _FakeHost(),
      );

      final json = session.toJSON();

      expect(json['sn'], 42);
      expect(json['login'], session.host!.login.toJson());
    });

    test('folds elements into content and drops the elements key', () {
      final session = Session(Event(type: 'message'), host: _FakeHost());

      session.content = 'hello <at id="x"/>';

      final message = session.toJSON()['message'] as Map<String, dynamic>;
      expect(message['content'], 'hello <at id="x"/>');
      expect(message.containsKey('elements'), isFalse);
    });

    test('prefixes the encoded quote when present', () {
      final session = Session(Event(type: 'message'), host: _FakeHost());

      session.content = '<quote id="q1"/>hello';

      final message = session.toJSON()['message'] as Map<String, dynamic>;
      expect(message['content'], '<quote id="q1"/>hello');
    });

    test('leaves a plain event unchanged besides sn and login', () {
      final session = Session(
        Event(
          type: 'message',
          selfId: 'bot-1',
          platform: 'fake',
          user: User(id: 'u1'),
        ),
        host: _FakeHost(),
      );

      final json = session.toJSON();

      expect(json['type'], 'message');
      expect(json['self_id'], 'bot-1');
      expect(json['platform'], 'fake');
      expect(json['user'], {'id': 'u1'});
      expect(json.containsKey('message'), isFalse);
      expect(json['sn'], 42);
      expect(json['login'], session.host!.login.toJson());
    });
  });
}
