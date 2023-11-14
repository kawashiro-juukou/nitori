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
  group('Elements', () {
    test('Basic', () {
      // At Element
      expect(n.At(id: '1').toString(), equals('<at id="1"/>'));
      expect(n.At(id: '1', name: 'test').toString(),
          equals('<at id="1" name="test"/>'));
      expect(n.At(role: 'test').toString(), equals('<at role="test"/>'));
      expect(n.At(type: 'test').toString(), equals('<at type="test"/>'));
      // Sharp Element
      expect(n.Sharp(id: '1').toString(), equals('<sharp id="1"/>'));
      expect(n.Sharp(id: '1', name: 'test').toString(),
          equals('<sharp id="1" name="test"/>'));
      // A Element
      expect(n.A(href: 'https://example.com').toString(),
          equals('<a href="https://example.com"/>'));
    });

    test('Layout', () {
      // Br Element
      expect(n.Br().toString(), equals('<br/>'));
      // P Element
      expect(n.P().toString(), equals('<p/>'));
      expect(n.P(children: [n.Text('test')]).toString(), equals('<p>test</p>'));
      expect(n.P(children: [n.Text('test'), n.Text('test2')]).toString(),
          equals('<p>testtest2</p>'));
      expect(n.P(children: [n.Text('test'), n.Br()]).toString(),
          equals('<p>test<br/></p>'));
      // Message Element
      expect(n.Message().toString(), equals('<message/>'));
      expect(n.Message(id: '1').toString(), equals('<message id="1"/>'));
      expect(n.Message(forward: true).toString(), equals('<message forward/>'));
      expect(n.Message(id: '1', forward: true).toString(),
          equals('<message id="1" forward/>'));
      expect(n.Message(id: '1', forward: false).toString(),
          equals('<message id="1" forward="false"/>'));
      expect(n.Message(children: [n.Text('test')]).toString(),
          equals('<message>test</message>'));
    });

    test('Meta', () {
      expect(n.Quote().toString(), equals('<quote/>'));
      expect(n.Quote(children: [n.Text('test')]).toString(),
          equals('<quote>test</quote>'));
      expect(n.Author().toString(), equals('<author/>'));
      expect(n.Author(userId: '1').toString(), equals('<author user-id="1"/>'));
      expect(n.Author(userId: '1', nickname: 'test').toString(),
          equals('<author user-id="1" nickname="test"/>'));
      expect(n.Author(userId: '1', nickname: 'test', avatar: 'test').toString(),
          equals('<author user-id="1" nickname="test" avatar="test"/>'));
    });

    test('Resource', () {
      expect(n.Image(src: 'https://example.com').toString(),
          equals('<img src="https://example.com"/>'));
      expect(
          n.Image(src: 'https://example.com', cache: true, timeout: '1000')
              .toString(),
          equals('<img src="https://example.com" cache timeout="1000"/>'));
      expect(
          n.Img(src: 'https://example.com', width: 300, height: 200).toString(),
          equals('<img src="https://example.com" width="300" height="200"/>'));
      expect(n.Audio(src: 'https://example.com').toString(),
          equals('<audio src="https://example.com"/>'));
      expect(n.Video(src: 'https://example.com').toString(),
          equals('<video src="https://example.com"/>'));
    });

    test('Modifier', () {
      expect(n.Strong('test').toString(), equals('<strong>test</strong>'));
      expect(n.Em('test').toString(), equals('<em>test</em>'));
      expect(n.Ins('test').toString(), equals('<ins>test</ins>'));
      expect(n.Del('test').toString(), equals('<del>test</del>'));
      expect(n.Spl('test').toString(), equals('<spl>test</spl>'));
      expect(n.Code('test').toString(), equals('<code>test</code>'));
      expect(n.Sup('test').toString(), equals('<sup>test</sup>'));
      expect(n.Sub('test').toString(), equals('<sub>test</sub>'));
    });
  });

  group('Parser', () {
    test('Basic', () {
      expect(n.parse('<test/>'), equals(n.Base('test')));
      expect(n.parse('<test id="001"/>'),
          equals(n.Base('test', attributes: {'id': '001'})));
      expect(n.parse('<test id="001" name="test"/>'),
          equals(n.Base('test', attributes: {'id': '001', 'name': 'test'})));
    });
  });
}
