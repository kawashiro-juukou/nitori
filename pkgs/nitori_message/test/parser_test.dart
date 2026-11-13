import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

void main() {
  group('Basic', () {
    test('parse as Base elements', () {
      expect(n.parse('<test/>'), equals([n.Base('test')]));
      expect(
        n.parse('<test id="001"/>'),
        equals([
          n.Base('test', attributes: {'id': '001'}),
        ]),
      );
      expect(
        n.parse('<test id="001" name="test"/>'),
        equals([
          n.Base('test', attributes: {'id': '001', 'name': 'test'}),
        ]),
      );
    });

    test('parse as Base elements with children', () {
      expect(
        n.parse('<test>111</test>'),
        equals([
          n.Base('test', children: [n.Text('111')]),
        ]),
      );
      expect(
        n.parse('<test><test>111</test><test/><test>222</test>333</test>'),
        equals([
          n.Base(
            'test',
            children: [
              n.Base('test', children: [n.Text('111')]),
              n.Base('test'),
              n.Base('test', children: [n.Text('222')]),
              n.Text('333'),
            ],
          ),
        ]),
      );
    });
  });

  group('Attributes', () {
    test('single-quoted attribute values', () {
      expect(
        n.parse("<at id='1' name='test'/>"),
        equals([n.At(id: '1', name: 'test')]),
      );
    });

    test('bare boolean and no- prefixed boolean attributes', () {
      expect(
        n.parse('<img src="s" cache/>'),
        equals([n.Image(src: 's', cache: true)]),
      );
      expect(
        n.parse('<img src="s" no-cache/>'),
        equals([n.Image(src: 's', cache: false)]),
      );
      expect(n.parse('<message forward/>'), equals([n.Message(forward: true)]));
      expect(
        n.parse('<message no-forward/>'),
        equals([n.Message(forward: false)]),
      );
      // Legacy `key="false"` still reads as false.
      expect(
        n.parse('<message forward="false"/>'),
        equals([n.Message(forward: false)]),
      );
    });

    test('attribute values are unescaped', () {
      expect(
        n.parse('<img src="s" title="a&amp;b"/>'),
        equals([n.Image(src: 's', title: 'a&b')]),
      );
      expect(
        n.parse('<at id="1" name="&#x27;"/>'),
        equals([n.At(id: '1', name: "'")]),
      );
    });

    test('comments are ignored', () {
      expect(n.parse('<!-- hello --><b>x</b>'), equals([n.Bold('x')]));
      expect(n.parse('<b><!-- c -->x</b>'), equals([n.Bold('x')]));
    });

    test('mismatched closing tag throws', () {
      expect(() => n.parse('<a></b></a>'), throwsException);
    });

    test('text content is unescaped', () {
      expect(n.parse('a&b'), equals([n.Text('a&b')]));
      expect(n.parse('&#39;'), equals([n.Text("'")]));
      // An escaped `<` stays literal text and round trips.
      final amp = String.fromCharCode(0x26);
      final nodes = n.parse('${amp}amp;lt;');
      expect(nodes, equals([n.Text('${amp}lt;')]));
      expect(nodes.first.toString(), equals('${amp}amp;lt;'));
    });
  });

  group('Elements', () {
    test('Basic', () {
      expect(n.parse('<at id="1"/>'), equals([n.At(id: '1')]));
      expect(
        n.parse('<at id="1" name="test"/>'),
        equals([n.At(id: '1', name: 'test')]),
      );
      expect(n.parse('<at role="test"/>'), equals([n.At(role: 'test')]));
      expect(n.parse('<at type="test"/>'), equals([n.At(type: 'test')]));
      expect(n.parse('<sharp id="1"/>'), equals([n.Sharp(id: '1')]));
      expect(
        n.parse('<sharp id="1" name="test"/>'),
        equals([n.Sharp(id: '1', name: 'test')]),
      );
      expect(
        n.parse('<a href="https://example.com"/>'),
        equals([n.Anchor(href: 'https://example.com')]),
      );
    });

    test('Layout', () {
      expect(n.parse('<br/>'), equals([n.LineBreak()]));
      expect(n.parse('<p/>'), equals([n.Paragraph()]));
      expect(
        n.parse('<p>test</p>'),
        equals([
          n.Paragraph(children: [n.Text('test')]),
        ]),
      );
      expect(
        n.parse('<p>testtest2</p>'),
        equals([
          n.Paragraph(children: [n.Text('testtest2')]),
        ]),
      );
      expect(
        n.parse('<p>test<br/></p>'),
        equals([
          n.Paragraph(children: [n.Text('test'), n.LineBreak()]),
        ]),
      );
      expect(n.parse('<message/>'), equals([n.Message()]));
      expect(n.parse('<message id="1"/>'), equals([n.Message(id: '1')]));
      expect(n.parse('<message forward/>'), equals([n.Message(forward: true)]));
      expect(
        n.parse('<message id="1" forward/>'),
        equals([n.Message(id: '1', forward: true)]),
      );
      expect(
        n.parse('<message id="1" forward="false"/>'),
        equals([n.Message(id: '1', forward: false)]),
      );
      expect(
        n.parse('<message>test</message>'),
        equals([
          n.Message(children: [n.Text('test')]),
        ]),
      );
    });

    test('Meta', () {
      expect(n.parse('<quote/>'), equals([n.Quote()]));
      expect(
        n.parse('<quote>test</quote>'),
        equals([
          n.Quote(children: [n.Text('test')]),
        ]),
      );
      expect(n.parse('<author/>'), equals([n.Author()]));
      expect(n.parse('<author id="1"/>'), equals([n.Author(userId: '1')]));
      expect(
        n.parse('<author id="1" name="test"/>'),
        equals([n.Author(userId: '1', nickname: 'test')]),
      );
      expect(
        n.parse('<author id="1" name="test" avatar="test"/>'),
        equals([n.Author(userId: '1', nickname: 'test', avatar: 'test')]),
      );
      // The legacy `user-id` / `nickname` spellings are still accepted.
      expect(
        n.parse('<author user-id="1" nickname="test"/>'),
        equals([n.Author(userId: '1', nickname: 'test')]),
      );
    });

    test('Resource', () {
      expect(
        n.parse('<img src="https://example.com"/>'),
        equals([n.Image(src: 'https://example.com')]),
      );
      expect(
        n.parse('<img src="https://example.com" cache timeout="1000"/>'),
        equals([
          n.Image(src: 'https://example.com', cache: true, timeout: '1000'),
        ]),
      );
      expect(
        n.parse('<img src="https://example.com" width="300" height="200"/>'),
        equals([n.Image(src: 'https://example.com', width: 300, height: 200)]),
      );
      expect(
        n.parse('<audio src="https://example.com"/>'),
        equals([n.Audio(src: 'https://example.com')]),
      );
      expect(
        n.parse('<video src="https://example.com"/>'),
        equals([n.Video(src: 'https://example.com')]),
      );
      expect(
        n.parse('<img src="s" no-cache/>'),
        equals([n.Image(src: 's', cache: false)]),
      );
      expect(
        n.parse('<img src="s" title="t"/>'),
        equals([n.Image(src: 's', title: 't')]),
      );
      expect(
        n.parse('<audio src="s" title="t" duration="10" poster="p"/>'),
        equals([n.Audio(src: 's', title: 't', duration: '10', poster: 'p')]),
      );
      expect(
        n.parse('<video src="s" title="t" duration="10" poster="p"/>'),
        equals([n.Video(src: 's', title: 't', duration: '10', poster: 'p')]),
      );
      expect(
        n.parse('<file src="s" title="t" poster="p"/>'),
        equals([n.File(src: 's', title: 't', poster: 'p')]),
      );
    });

    test('Modifier', () {
      expect(n.parse('<strong>test</strong>'), equals([n.Bold('test')]));
      expect(n.parse('<b>test</b>'), equals([n.Bold('test')]));
      expect(n.parse('<em>test</em>'), equals([n.Idiomatic('test')]));
      expect(n.parse('<i>test</i>'), equals([n.Idiomatic('test')]));
      expect(n.parse('<ins>test</ins>'), equals([n.Underline('test')]));
      expect(n.parse('<u>test</u>'), equals([n.Underline('test')]));
      expect(n.parse('<del>test</del>'), equals([n.Strikethrough('test')]));
      expect(n.parse('<s>test</s>'), equals([n.Strikethrough('test')]));
      expect(n.parse('<spl>test</spl>'), equals([n.Spoiler('test')]));
      expect(n.parse('<code>test</code>'), equals([n.Code('test')]));
      expect(n.parse('<sup>test</sup>'), equals([n.Superscript('test')]));
      expect(n.parse('<sub>test</sub>'), equals([n.Subscript('test')]));
    });

    test('Experimental', () {
      expect(
        n.parse('<button id="x">Hi</button>'),
        equals([
          n.Button.children([n.Text('Hi')], id: 'x'),
        ]),
      );
      expect(
        n.parse('<button id="x">Hi</button>').first.toString(),
        equals('<button id="x">Hi</button>'),
      );
      expect(
        n.parse('<button id="x"/>'),
        equals([n.Button.children([], id: 'x')]),
      );
    });

    test('Modifier preserves nesting and round trips', () {
      expect(
        n.parse('<b>x<u>y</u></b>'),
        equals([
          n.Bold.children([
            n.Text('x'),
            n.Underline.children([n.Text('y')]),
          ]),
        ]),
      );
      expect(
        n.parse('<b>x<u>y</u></b>').first.toString(),
        equals('<b>x<u>y</u></b>'),
      );
    });

    test('whitespace between tags is preserved', () {
      expect(
        n.parse('<b>x</b> <i>y</i>'),
        equals([n.Bold('x'), n.Text(' '), n.Idiomatic('y')]),
      );
      // A newline right next to a tag is still trimmed.
      expect(
        n.parse('<b>x</b>\n<i>y</i>'),
        equals([n.Bold('x'), n.Idiomatic('y')]),
      );
    });
  });

  group('Examples', () {
    test('Single Message', () {
      expect(
        n.parse("""<message>
  <at id="1" name="test"/>
  <at id="2" name="test2"/>
  <br/>
  <p>test</p>
  <img src="https://example.com"/>
  <audio src="https://example.com"/>
  <p>
    <b>bold</b><sup>sup</sup><sub>sub</sub>
    <spl>spoiler</spl>
    <code>code</code>
    <u>underline</u>
    <s>strikethrough</s>
  </p>
</message>"""),
        equals([
          n.Message(
            children: [
              n.At(id: '1', name: 'test'),
              n.At(id: '2', name: 'test2'),
              n.LineBreak(),
              n.Paragraph(children: [n.Text('test')]),
              n.Image(src: 'https://example.com'),
              n.Audio(src: 'https://example.com'),
              n.Paragraph(
                children: [
                  n.Bold('bold'),
                  n.Superscript('sup'),
                  n.Subscript('sub'),
                  n.Spoiler('spoiler'),
                  n.Code('code'),
                  n.Underline('underline'),
                  n.Strikethrough('strikethrough'),
                ],
              ),
            ],
          ),
        ]),
      );

      expect(
        n.parse("""<message>
<code>
  yarn add nitori
  yarn run test
  npm publish
</code>
</message>"""),
        equals([
          n.Message(
            children: [
              n.Code('yarn add nitori\n  yarn run test\n  npm publish'),
            ],
          ),
        ]),
      );
    });
  });
}
