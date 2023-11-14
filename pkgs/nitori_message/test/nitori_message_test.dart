import 'package:nitori_message/nitori_message.dart' as message;
import 'package:test/test.dart';

void main() {
  group('Base Element and Functions', () {
    test('BaseElement', () {
      expect(message.BaseElement('test').toString(), equals('<test/>'));
      expect(message.BaseElement('test', attributes: {'id': '001'}).toString(),
          equals('<test id="001"/>'));
      expect(
          message.BaseElement('test', attributes: {'id': '001', 'name': 'test'})
              .toString(),
          equals('<test id="001" name="test"/>'));
    });

    test('escape', () {
      expect(message.escape('<test/>'), equals('&lt;test/&gt;'));
      expect(message.escape('\"test\"'), equals('&quot;test&quot;'));
      expect(message.escape('&test&'), equals('&amp;test&amp;'));
    });
  });
  group('Basic Elements', () {
    test('First Test', () {
      expect(true, isTrue);
    });
  });
}
