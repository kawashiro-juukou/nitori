import 'package:nitori/nitori.dart';
import 'package:test/test.dart';

void main() {
  group('Umbrella exports', () {
    test('re-exports core models', () {
      var channel = Channel(id: '001', type: ChannelType.text);

      expect(channel.toJson(), containsPair('id', '001'));
      expect(channel.toJson(), containsPair('type', 0));
    });

    test('re-exports message parser', () {
      expect(parse('<b>Hello</b>'), equals([Bold('Hello')]));
    });
  });
}
