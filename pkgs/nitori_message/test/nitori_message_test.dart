import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

void main() {
  group('Base Element and Functions', () {
    test('BaseElement', () {
      expect(n.BaseElement('test').toString(), equals('<test/>'));
      expect(n.BaseElement('test', attributes: {'id': '001'}).toString(),
          equals('<test id="001"/>'));
      expect(
          n.BaseElement('test', attributes: {'id': '001', 'name': 'test'})
              .toString(),
          equals('<test id="001" name="test"/>'));
    });

    test('escape', () {
      expect(n.escape('<test/>'), equals('&lt;test/&gt;'));
      expect(n.escape('\"test\"'), equals('&quot;test&quot;'));
      expect(n.escape('&test&'), equals('&amp;test&amp;'));
    });
  });
  group('Elements', () {
    test('Basic', () {
      expect(n.AtElement(id: '1').toString(), equals('<at id="1"/>'));
      expect(n.AtElement(id: '1', name: 'test').toString(),
          equals('<at id="1" name="test"/>'));
      expect(n.AtElement(role: 'test').toString(), equals('<at role="test"/>'));
      expect(n.AtElement(type: 'test').toString(), equals('<at type="test"/>'));
    });
  });
}
