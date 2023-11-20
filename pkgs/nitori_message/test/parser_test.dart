import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

void main() {
  group('Basic', () {
    test('parse as Base elements', () {
      expect(n.parse('<test/>'), equals([n.Base('test')]));
      expect(
          n.parse('<test id="001"/>'),
          equals([
            n.Base('test', attributes: {'id': '001'})
          ]));
      expect(
          n.parse('<test id="001" name="test"/>'),
          equals([
            n.Base('test', attributes: {'id': '001', 'name': 'test'})
          ]));
    });

    test('parse as Base elements with children', () {
      expect(
          n.parse('<test>111</test>'),
          equals([
            n.Base('test', children: [n.Text('111')])
          ]));
      expect(
          n.parse('<test><test>111</test><test/><test>222</test>333</test>'),
          equals([
            n.Base('test', children: [
              n.Base('test', children: [n.Text('111')]),
              n.Base('test'),
              n.Base('test', children: [n.Text('222')]),
              n.Text('333')
            ])
          ]));
    });
  });

  group('Elements', () {
    test('Basic', () {
      expect(n.parse('<at id="1"/>'), equals([n.At(id: '1')]));
      expect(n.parse('<at id="1" name="test"/>'),
          equals([n.At(id: '1', name: 'test')]));
      expect(n.parse('<at role="test"/>'), equals([n.At(role: 'test')]));
      expect(n.parse('<at type="test"/>'), equals([n.At(type: 'test')]));
      expect(n.parse('<sharp id="1"/>'), equals([n.Sharp(id: '1')]));
      expect(n.parse('<sharp id="1" name="test"/>'),
          equals([n.Sharp(id: '1', name: 'test')]));
      expect(n.parse('<a href="https://example.com"/>'),
          equals([n.A(href: 'https://example.com')]));
    });

    test('Layout', () {
      expect(n.parse('<br/>'), equals([n.Br()]));
      expect(n.parse('<p/>'), equals([n.P()]));
      expect(
          n.parse('<p>test</p>'),
          equals([
            n.P(children: [n.Text('test')])
          ]));
      expect(
          n.parse('<p>testtest2</p>'),
          equals([
            n.P(children: [n.Text('testtest2')])
          ]));
      expect(
          n.parse('<p>test<br/></p>'),
          equals([
            n.P(children: [n.Text('test'), n.Br()])
          ]));
      expect(n.parse('<message/>'), equals([n.Message()]));
      expect(n.parse('<message id="1"/>'), equals([n.Message(id: '1')]));
      expect(n.parse('<message forward/>'), equals([n.Message(forward: true)]));
      expect(n.parse('<message id="1" forward/>'),
          equals([n.Message(id: '1', forward: true)]));
      expect(n.parse('<message id="1" forward="false"/>'),
          equals([n.Message(id: '1', forward: false)]));
      expect(
          n.parse('<message>test</message>'),
          equals([
            n.Message(children: [n.Text('test')])
          ]));
    });

    test('Meta', () {
      expect(n.parse('<quote/>'), equals([n.Quote()]));
      expect(
          n.parse('<quote>test</quote>'),
          equals([
            n.Quote(children: [n.Text('test')])
          ]));
      expect(n.parse('<author/>'), equals([n.Author()]));
      expect(n.parse('<author user-id="1"/>'), equals([n.Author(userId: '1')]));
      expect(n.parse('<author user-id="1" nickname="test"/>'),
          equals([n.Author(userId: '1', nickname: 'test')]));
      expect(n.parse('<author user-id="1" nickname="test" avatar="test"/>'),
          equals([n.Author(userId: '1', nickname: 'test', avatar: 'test')]));
    });

    test('Resource', () {
      expect(n.parse('<img src="https://example.com"/>'),
          equals([n.Image(src: 'https://example.com')]));
      expect(
          n.parse('<img src="https://example.com" cache timeout="1000"/>'),
          equals([
            n.Image(src: 'https://example.com', cache: true, timeout: '1000')
          ]));
      expect(
          n.parse('<img src="https://example.com" width="300" height="200"/>'),
          equals([n.Img(src: 'https://example.com', width: 300, height: 200)]));
      expect(n.parse('<audio src="https://example.com"/>'),
          equals([n.Audio(src: 'https://example.com')]));
      expect(n.parse('<video src="https://example.com"/>'),
          equals([n.Video(src: 'https://example.com')]));
    });

    test('Modifier', () {
      expect(n.parse('<strong>test</strong>'), equals([n.Strong('test')]));
      expect(n.parse('<b>test</b>'), equals([n.Strong('test')]));
      expect(n.parse('<em>test</em>'), equals([n.Em('test')]));
      expect(n.parse('<i>test</i>'), equals([n.Em('test')]));
      expect(n.parse('<ins>test</ins>'), equals([n.Ins('test')]));
      expect(n.parse('<u>test</u>'), equals([n.Ins('test')]));
      expect(n.parse('<del>test</del>'), equals([n.Del('test')]));
      expect(n.parse('<s>test</s>'), equals([n.Del('test')]));
      expect(n.parse('<spl>test</spl>'), equals([n.Spl('test')]));
      expect(n.parse('<code>test</code>'), equals([n.Code('test')]));
      expect(n.parse('<sup>test</sup>'), equals([n.Sup('test')]));
      expect(n.parse('<sub>test</sub>'), equals([n.Sub('test')]));
    });
  });
}
