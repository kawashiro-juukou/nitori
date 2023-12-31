import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

void main() {
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
      expect(n.Anchor(href: 'https://example.com').toString(),
          equals('<a href="https://example.com"/>'));
    });

    test('Layout', () {
      // Br Element
      expect(n.LineBreak().toString(), equals('<br/>'));
      // P Element
      expect(n.Paragraph().toString(), equals('<p/>'));
      expect(n.Paragraph(children: [n.Text('test')]).toString(),
          equals('<p>test</p>'));
      expect(
          n.Paragraph(children: [n.Text('test'), n.Text('test2')]).toString(),
          equals('<p>testtest2</p>'));
      expect(n.Paragraph(children: [n.Text('test'), n.LineBreak()]).toString(),
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
          n.Image(src: 'https://example.com', width: 300, height: 200)
              .toString(),
          equals('<img src="https://example.com" width="300" height="200"/>'));
      expect(n.Audio(src: 'https://example.com').toString(),
          equals('<audio src="https://example.com"/>'));
      expect(n.Video(src: 'https://example.com').toString(),
          equals('<video src="https://example.com"/>'));
    });

    test('Modifier', () {
      expect(n.Bold('test').toString(), equals('<b>test</b>'));
      expect(n.Idiomatic('test').toString(), equals('<i>test</i>'));
      expect(n.Underline('test').toString(), equals('<u>test</u>'));
      expect(n.Strikethrough('test').toString(), equals('<s>test</s>'));
      expect(n.Spoiler('test').toString(), equals('<spl>test</spl>'));
      expect(n.Code('test').toString(), equals('<code>test</code>'));
      expect(n.Superscript('test').toString(), equals('<sup>test</sup>'));
      expect(n.Subscript('test').toString(), equals('<sub>test</sub>'));
    });
  });
}
