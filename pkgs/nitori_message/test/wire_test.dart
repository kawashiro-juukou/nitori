import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

void main() {
  test('parse-encode-parse wire round-trips', () {
    final original = n.parse('<at id="1"/><p>hi</p>');
    final wire = n.encodeWireElements(original);
    final decoded = n.parseWireElements(wire);
    expect(decoded, equals(original));
  });

  test('nested wire input round-trips', () {
    final wire = [
      {
        'type': 'message',
        'attrs': {'id': '001'},
        'children': [
          {
            'type': 'text',
            'attrs': {'text': 'hello'},
          },
          {
            'type': 'at',
            'attrs': {'id': '2', 'name': 'bob'},
          },
        ],
      },
    ];
    final decoded = n.parseWireElements(wire);
    expect(
      decoded,
      equals([
        n.Message(
          id: '001',
          children: [
            n.Text('hello'),
            n.At(id: '2', name: 'bob'),
          ],
        ),
      ]),
    );
    expect(n.encodeWireElements(decoded), equals(wire));
  });

  test('unknown tag decodes to Base', () {
    final decoded = n.parseWireElements([
      {
        'type': 'custom',
        'attrs': {'id': 'x'},
      },
    ]);
    expect(
      decoded,
      equals([
        n.Base('custom', attributes: {'id': 'x'}),
      ]),
    );
  });

  test(
    'bool attribute survives decode as string and re-encodes consistently',
    () {
      final wire = [
        {
          'type': 'message',
          'attrs': {'forward': true},
        },
      ];
      final decoded = n.parseWireElements(wire);
      expect(decoded, equals([n.Message(forward: true)]));
      expect(
        n.encodeWireElements(decoded),
        equals([
          {
            'type': 'message',
            'attrs': {'forward': 'true'},
          },
        ]),
      );
    },
  );

  test('Button round-trips with its id', () {
    final wire = [
      {
        'type': 'button',
        'attrs': {'id': 'btn1'},
        'children': [
          {
            'type': 'text',
            'attrs': {'text': 'click'},
          },
        ],
      },
    ];
    final decoded = n.parseWireElements(wire);
    expect(decoded, equals([n.Button('click', id: 'btn1')]));
    expect(n.encodeWireElements(decoded), equals(wire));
  });
}
