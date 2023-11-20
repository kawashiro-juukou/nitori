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
}
