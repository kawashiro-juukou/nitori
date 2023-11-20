import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

void main() {
  group('Basic', () {
    test('parse as Base elements', () {
      expect(n.parse('<test/>').map((e) => e.toString()).toList(),
          equals([n.Base('test').toString()]));
      expect(
          n.parse('<test id="001"/>').map((e) => e.toString()).toList(),
          equals([
            n.Base('test', attributes: {'id': '001'}).toString()
          ]));
      expect(
          n
              .parse('<test id="001" name="test"/>')
              .map((e) => e.toString())
              .toList(),
          equals([
            n.Base('test', attributes: {'id': '001', 'name': 'test'}).toString()
          ]));
    });
  });
}
