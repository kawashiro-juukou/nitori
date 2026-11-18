import './base.dart';
import './parser.dart';

/// Converts protocol wire elements (`{type, attrs, children}`) to typed nodes.
List<Node> parseWireElements(List<Map<String, Object?>> data) {
  return data.map(_decodeElement).toList();
}

/// Decodes a single wire element into a [Node].
///
/// The tag → class mapping mirrors [createTag] in parser.dart so that wire
/// decoding and string parsing produce the same typed nodes. Anything
/// unrecognised becomes [Base].
Node _decodeElement(Map<String, Object?> element) {
  final type = element['type'] as String?;
  final attrs = <String, Object>{};
  final rawAttrs = element['attrs'] as Map<String, Object?>?;
  rawAttrs?.forEach((key, value) {
    if (value == null) {
      return;
    }
    // Non-string attr values are coerced to String on decode (bool →
    // 'true'/'false', num → its string form).
    if (value is bool) {
      attrs[key] = value ? 'true' : 'false';
    } else if (value is num) {
      attrs[key] = value.toString();
    } else {
      attrs[key] = value;
    }
  });

  final children = <Node>[];
  final rawChildren = element['children'] as List<Object?>?;
  rawChildren?.forEach((child) {
    if (child is Map<String, Object?>) {
      children.add(_decodeElement(child));
    }
  });

  // A text node carries its content in attrs.text.
  if (type == 'text') {
    return Text(attrs['text'] as String? ?? '');
  }

  return createTag(type ?? '', attrs, children) ??
      Base(type ?? '', attributes: attrs, children: children);
}

/// Converts typed nodes back to the protocol wire element form.
List<Map<String, Object?>> encodeWireElements(List<Node> nodes) {
  return nodes.map(_encodeElement).toList();
}

/// Encodes a single [Node] into a wire element.
Map<String, Object?> _encodeElement(Node node) {
  if (node is Text) {
    return {
      'type': 'text',
      'attrs': {'text': node.text},
    };
  }

  final base = node as Base;
  final attrs = <String, Object?>{};
  // A typed node's [Base.attributes] map is `Map<String, Object?>`, so bool
  // attributes legitimately appear there. Encode must not drop them silently;
  // bools are written as 'true'/'false' strings, matching what decode
  // reproduces (this asymmetry means decode→encode→decode is stable even
  // though decode stores some bool attributes as bools in typed nodes).
  base.attributes?.forEach((key, value) {
    if (value == null) {
      return;
    }
    if (value is bool) {
      attrs[key] = value ? 'true' : 'false';
    } else if (value is num) {
      attrs[key] = value.toString();
    } else {
      attrs[key] = value;
    }
  });

  final element = <String, Object?>{'type': base.tag, 'attrs': attrs};
  if (base.children != null && base.children!.isNotEmpty) {
    element['children'] = encodeWireElements(base.children!);
  }
  return element;
}
