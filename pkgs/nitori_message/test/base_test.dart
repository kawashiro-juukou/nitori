import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

void main() {
  group('Base', () {
    test('BaseElement', () {
      expect(n.Base('test').toString(), equals('<test/>'));
      expect(n.Base('test', attributes: {'id': '001'}).toString(),
          equals('<test id="001"/>'));
      expect(
          n.Base('test', attributes: {'id': '001', 'name': 'test'}).toString(),
          equals('<test id="001" name="test"/>'));
    });

    test('Escape', () {
      expect(n.escape('<test/>'), equals('&lt;test/&gt;'));
      expect(n.escape('"test"'), equals('&quot;test&quot;'));
      expect(n.escape('&test&'), equals('&amp;test&amp;'));
    });

    test('Unescape', () {
      expect(n.unescape('&lt;test/&gt;'), equals('<test/>'));
      expect(n.unescape('&quot;test&quot;'), equals('"test"'));
      expect(n.unescape('&amp;test&amp;'), equals('&test&'));
    });
  });
}
