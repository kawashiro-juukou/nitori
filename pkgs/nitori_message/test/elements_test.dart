import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

void main() {
  group('Elements', () {
    test('Basic', () {
      // At Element
      expect(n.At(id: '1').toString(), equals('<at id="1"/>'));
      expect(
        n.At(id: '1', name: 'test').toString(),
        equals('<at id="1" name="test"/>'),
      );
      expect(n.At(role: 'test').toString(), equals('<at role="test"/>'));
      expect(n.At(type: 'test').toString(), equals('<at type="test"/>'));
      // Sharp Element
      expect(n.Sharp(id: '1').toString(), equals('<sharp id="1"/>'));
      expect(
        n.Sharp(id: '1', name: 'test').toString(),
        equals('<sharp id="1" name="test"/>'),
      );
      // A Element
      expect(
        n.Anchor(href: 'https://example.com').toString(),
        equals('<a href="https://example.com"/>'),
      );
    });

    test('Layout', () {
      // Br Element
      expect(n.LineBreak().toString(), equals('<br/>'));
      // P Element
      expect(n.Paragraph().toString(), equals('<p/>'));
      expect(
        n.Paragraph(children: [n.Text('test')]).toString(),
        equals('<p>test</p>'),
      );
      expect(
        n.Paragraph(children: [n.Text('test'), n.Text('test2')]).toString(),
        equals('<p>testtest2</p>'),
      );
      expect(
        n.Paragraph(children: [n.Text('test'), n.LineBreak()]).toString(),
        equals('<p>test<br/></p>'),
      );
      // Message Element
      expect(n.Message().toString(), equals('<message/>'));
      expect(n.Message(id: '1').toString(), equals('<message id="1"/>'));
      expect(n.Message(forward: true).toString(), equals('<message forward/>'));
      expect(
        n.Message(id: '1', forward: true).toString(),
        equals('<message id="1" forward/>'),
      );
      expect(
        n.Message(id: '1', forward: false).toString(),
        equals('<message id="1" no-forward/>'),
      );
      expect(
        n.Message(children: [n.Text('test')]).toString(),
        equals('<message>test</message>'),
      );
    });

    test('Meta', () {
      expect(n.Quote().toString(), equals('<quote/>'));
      expect(
        n.Quote(children: [n.Text('test')]).toString(),
        equals('<quote>test</quote>'),
      );
      expect(n.Author().toString(), equals('<author/>'));
      expect(n.Author(userId: '1').toString(), equals('<author id="1"/>'));
      expect(
        n.Author(userId: '1', nickname: 'test').toString(),
        equals('<author id="1" name="test"/>'),
      );
      expect(
        n.Author(userId: '1', nickname: 'test', avatar: 'test').toString(),
        equals('<author id="1" name="test" avatar="test"/>'),
      );
    });

    test('Resource', () {
      expect(
        n.Image(src: 'https://example.com').toString(),
        equals('<img src="https://example.com"/>'),
      );
      expect(
        n.Image(
          src: 'https://example.com',
          cache: true,
          timeout: '1000',
        ).toString(),
        equals('<img src="https://example.com" cache timeout="1000"/>'),
      );
      expect(
        n.Image(src: 'https://example.com', width: 300, height: 200).toString(),
        equals('<img src="https://example.com" width="300" height="200"/>'),
      );
      expect(
        n.Audio(src: 'https://example.com').toString(),
        equals('<audio src="https://example.com"/>'),
      );
      expect(
        n.Video(src: 'https://example.com').toString(),
        equals('<video src="https://example.com"/>'),
      );
      expect(
        n.File(src: 'https://example.com').toString(),
        equals('<file src="https://example.com"/>'),
      );
      // Common resource attributes.
      expect(
        n.Image(src: 's', title: 'name').toString(),
        equals('<img src="s" title="name"/>'),
      );
      expect(
        n.Audio(src: 's', title: 't').toString(),
        equals('<audio src="s" title="t"/>'),
      );
      expect(
        n.Video(src: 's', title: 't').toString(),
        equals('<video src="s" title="t"/>'),
      );
      expect(
        n.File(src: 's', title: 't').toString(),
        equals('<file src="s" title="t"/>'),
      );
      expect(
        n.Image(src: 's', cache: false).toString(),
        equals('<img src="s" no-cache/>'),
      );
      // Media-only attributes.
      expect(
        n.Audio(
          src: 's',
          duration: '10',
          poster: 'https://example.com',
        ).toString(),
        equals('<audio src="s" duration="10" poster="https://example.com"/>'),
      );
      expect(
        n.Video(
          src: 's',
          width: 300,
          height: 200,
          duration: '10',
          poster: 'https://example.com',
        ).toString(),
        equals(
          '<video src="s" width="300" height="200" duration="10" poster="https://example.com"/>',
        ),
      );
      expect(
        n.File(src: 's', poster: 'https://example.com').toString(),
        equals('<file src="s" poster="https://example.com"/>'),
      );
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

    test('Experimental', () {
      expect(n.Button('Hi').toString(), equals('<button>Hi</button>'));
      expect(
        n.Button('Hi', id: 'x').toString(),
        equals('<button id="x">Hi</button>'),
      );
      expect(
        n.Button.children([n.Text('Hi')], id: 'x').toString(),
        equals('<button id="x">Hi</button>'),
      );
      expect(
        n.Button('Hi', id: 'x', attributes: {'class': 'primary'}).toString(),
        equals('<button class="primary" id="x">Hi</button>'),
      );
    });

    test('Modifier keeps nested children', () {
      expect(
        n.Bold.children([
          n.Text('x'),
          n.Underline.children([n.Text('y')]),
        ]).toString(),
        equals('<b>x<u>y</u></b>'),
      );
      expect(
        n.Bold.children([
          n.Text('x'),
          n.Underline.children([n.Text('y')]),
        ]),
        equals(n.parse('<b>x<u>y</u></b>').first),
      );
      // Round trip after nesting is preserved.
      final nested = n.parse('<b>x<u>y</u></b>');
      expect(nested.first.toString(), equals('<b>x<u>y</u></b>'));
    });
  });
}
