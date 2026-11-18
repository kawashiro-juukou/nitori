// The protocol carries message elements as JSON objects: `type`, `attrs` and
// `children`, with text runs in `attrs.text`. [ElementNode] is the DSL-side
// structural node, so the codec below converts between the two.

import 'message.dart';
import 'resource.dart';

/// Converts structural element nodes into their wire form.
List<Map<String, Object?>> encodeElementNodes(List<ElementNode> nodes) =>
    nodes.map(encodeElementNode).toList();

/// Converts a structural element node into its wire form.
Map<String, Object?> encodeElementNode(ElementNode node) {
  final data = <String, Object?>{
    'type': node.type,
    'attrs': <String, Object?>{
      ...node.attributes,
      if (node.type == 'text') 'text': node.text,
    },
  };
  if (node.children.isNotEmpty ||
      (node.type != 'text' && node.text.isNotEmpty)) {
    data['children'] = <Object?>[
      ...node.children.map(encodeElementNode),
      if (node.type != 'text' && node.text.isNotEmpty)
        <String, Object?>{
          'type': 'text',
          'attrs': <String, Object?>{'text': node.text},
        },
    ];
  }
  return data;
}

/// Converts wire-form elements into structural nodes.
List<ElementNode> decodeElementNodes(List<Map<String, Object?>> maps) =>
    maps.map(decodeElementNode).toList();

/// Converts a wire-form element into a structural node.
ElementNode decodeElementNode(Map<String, Object?> data) {
  final type = data['type'];
  if (type is! String) {
    throw ArgumentError.value(data, 'data', 'element map lacks a type');
  }
  final rawAttrs = data['attrs'];
  final attributes = <String, String>{};
  if (rawAttrs is Map) {
    rawAttrs.forEach((key, value) {
      attributes[key.toString()] = value == null ? '' : value.toString();
    });
  }
  if (type == 'text') {
    return ElementNode('text', text: attributes.remove('text') ?? '');
  }
  final children = <ElementNode>[];
  final rawChildren = data['children'];
  if (rawChildren is List) {
    for (final raw in rawChildren) {
      if (raw is Map) {
        children.add(decodeElementNode(Map<String, Object?>.from(raw)));
      }
    }
  }
  return ElementNode(type, attributes: attributes, children: children);
}

extension MessageElementsCodec on Message {
  /// The message's elements in structural form, or null when absent.
  List<ElementNode>? get elementNodes {
    final elements = this.elements;
    if (elements == null) return null;
    return decodeElementNodes(elements);
  }

  set elementNodes(List<ElementNode>? value) {
    elements = value == null ? null : encodeElementNodes(value);
  }
}
