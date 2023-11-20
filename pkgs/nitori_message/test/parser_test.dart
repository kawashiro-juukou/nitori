import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

String toString(dynamic input) {
  if (input is Iterable) {
    return input.map((e) => toString(e)).join('');
  } else if (input is String) {
    return input;
  } else if (input is n.Base) {
    return input.toString();
  } else if (input is n.Text) {
    return input.toString();
  } else {
    return '';
  }
}

void main() {
  group('Basic', () {
    test('parse as Base elements', () {
      expect(toString(n.parse('<test/>')), equals(toString([n.Base('test')])));
      expect(
          toString(n.parse('<test id="001"/>')),
          equals(toString([
            n.Base('test', attributes: {'id': '001'})
          ])));
      expect(
          toString(n.parse('<test id="001" name="test"/>')),
          equals(toString([
            n.Base('test', attributes: {'id': '001', 'name': 'test'})
          ])));
    });

    test('parse as Base elements with children', () {
      expect(
          toString(n.parse('<test>111</test>')),
          equals(toString([
            n.Base('test', children: [n.Text('111')])
          ])));
    });
  });
}
