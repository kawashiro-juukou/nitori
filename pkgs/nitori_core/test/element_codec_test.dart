import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

void main() {
  group('element codec round-trip', () {
    test('nested tree with at inside p and text node', () {
      final pNode = ElementNode(
        'p',
        children: [
          ElementNode('at', attributes: {'id': '1'}),
        ],
      );
      final textNode = ElementNode('text', text: 'hello');
      final nodes = [pNode, textNode];

      final encoded = encodeElementNodes(nodes);
      final decoded = decodeElementNodes(encoded);

      expect(decoded, [
        ElementNode(
          'p',
          children: [
            ElementNode('at', attributes: {'id': '1'}),
          ],
        ),
        ElementNode('text', text: 'hello'),
      ]);
    });

    test('non-text node with text emits a trailing text child on encode', () {
      final pNode = ElementNode(
        'p',
        attributes: {'id': '2'},
        text: 'prefix',
        children: [
          ElementNode('at', attributes: {'id': '3'}),
        ],
      );

      expect(encodeElementNode(pNode), {
        'type': 'p',
        'attrs': {'id': '2'},
        'children': [
          {
            'type': 'at',
            'attrs': {'id': '3'},
          },
          {
            'type': 'text',
            'attrs': {'text': 'prefix'},
          },
        ],
      });
    });

    test('trailing text child decodes back as a child, not as node text', () {
      final decoded = decodeElementNode({
        'type': 'p',
        'attrs': {'id': '2'},
        'children': [
          {
            'type': 'at',
            'attrs': {'id': '3'},
          },
          {
            'type': 'text',
            'attrs': {'text': 'prefix'},
          },
        ],
      });

      // The trailing run stays a child node and the non-text node's own `text`
      // stays empty, so a non-text node's text does not survive the round-trip.
      expect(
        decoded,
        ElementNode(
          'p',
          attributes: {'id': '2'},
          children: [
            ElementNode('at', attributes: {'id': '3'}),
            ElementNode('text', text: 'prefix'),
          ],
        ),
      );
      expect(decoded.text, '');
    });

    test('non-string attrs decode to string', () {
      // Encode using the wire form directly with non-string values
      final wireElements = [
        {
          'type': 'at',
          'attrs': {'id': 42, 'active': true, 'count': 3.14},
        },
      ];
      final decoded = decodeElementNodes(
        wireElements.cast<Map<String, Object?>>(),
      );

      expect(decoded, [
        ElementNode(
          'at',
          attributes: {'id': '42', 'active': 'true', 'count': '3.14'},
        ),
      ]);
    });
  });

  group('Message elementNodes extension', () {
    test('getter returns decoded nodes or null', () {
      final message = Message();
      expect(message.elementNodes, isNull);

      message.elements = [
        {
          'type': 'text',
          'attrs': {'text': 'test'},
        },
      ];
      expect(message.elementNodes, isNotNull);
      expect(message.elementNodes!.length, 1);
      expect(message.elementNodes!.first.text, 'test');
    });

    test('setter accepts null or list', () {
      final message = Message();
      message.elementNodes = null;
      expect(message.elements, isNull);

      message.elementNodes = [ElementNode('text', text: 'hello')];
      expect(message.elements, isNotNull);
      expect(message.elements!.length, 1);
      expect(message.elements!.first['attrs'], {'text': 'hello'});
    });

    test('setter null clears elements', () {
      final message = Message();
      message.elements = [
        {
          'type': 'text',
          'attrs': {'text': 'test'},
        },
      ];
      expect(message.elementNodes, isNotNull);

      message.elementNodes = null;
      expect(message.elements, isNull);
    });
  });
}
