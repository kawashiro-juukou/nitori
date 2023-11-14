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

    test('Escape', () {
      expect(n.escape('<test/>'), equals('&lt;test/&gt;'));
      expect(n.escape('\"test\"'), equals('&quot;test&quot;'));
      expect(n.escape('&test&'), equals('&amp;test&amp;'));
    });

    test('Unescape', () {
      expect(n.unescape('&lt;test/&gt;'), equals('<test/>'));
      expect(n.unescape('&quot;test&quot;'), equals('\"test\"'));
      expect(n.unescape('&amp;test&amp;'), equals('&test&'));
    });
  });
  group('Elements', () {
    test('Basic', () {
      // At Element
      expect(n.AtElement(id: '1').toString(), equals('<at id="1"/>'));
      expect(n.AtElement(id: '1', name: 'test').toString(),
          equals('<at id="1" name="test"/>'));
      expect(n.AtElement(role: 'test').toString(), equals('<at role="test"/>'));
      expect(n.AtElement(type: 'test').toString(), equals('<at type="test"/>'));
      // Sharp Element
      expect(n.SharpElement(id: '1').toString(), equals('<sharp id="1"/>'));
      expect(n.SharpElement(id: '1', name: 'test').toString(),
          equals('<sharp id="1" name="test"/>'));
      // A Element
      expect(n.AElement(href: 'https://example.com').toString(),
          equals('<a href="https://example.com"/>'));
    });

    test('Layout', () {
      // Br Element
      expect(n.BrElement().toString(), equals('<br/>'));
      // P Element
      expect(n.PElement().toString(), equals('<p/>'));
      expect(n.PElement(children: [n.Text('test')]).toString(),
          equals('<p>test</p>'));
      expect(n.PElement(children: [n.Text('test'), n.Text('test2')]).toString(),
          equals('<p>testtest2</p>'));
      expect(n.PElement(children: [n.Text('test'), n.BrElement()]).toString(),
          equals('<p>test<br/></p>'));
      // Message Element
      expect(n.MessageElement().toString(), equals('<message/>'));
      expect(n.MessageElement(id: '1').toString(), equals('<message id="1"/>'));
      expect(n.MessageElement(forward: true).toString(),
          equals('<message forward/>'));
      expect(n.MessageElement(id: '1', forward: true).toString(),
          equals('<message id="1" forward/>'));
      expect(n.MessageElement(id: '1', forward: false).toString(),
          equals('<message id="1" forward="false"/>'));
      expect(n.MessageElement(children: [n.Text('test')]).toString(),
          equals('<message>test</message>'));
    });
  });
}
