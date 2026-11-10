/// Escapes special characters in the given [text] to their corresponding HTML entities.
///
/// This function replaces the characters &, ", <, and > with their corresponding HTML entities.
///
/// [text]: The text to escape.
String escape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Reverts the escaping of special characters in the given [text].
///
/// This function replaces the HTML entities for &, ", <, and > with their
/// corresponding characters. Numeric entities (`&#39;`, `&#x27;`, ...) are
/// resolved as well, mirroring @satorijs/element.
///
/// The order matters: `&` must be decoded last so escaped entities such as
/// `<` survive as literal text; the numeric encodings of `&`
/// (`&#38;` / `&#x26;`) are kept intact until that final pass for the same
/// reason.
///
/// [text]: The text to unescape.
String unescape(String text) {
  return text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
    // `&#38;` encodes `&` itself; keep it for the final pass below.
    final code = match.group(1)!;
    return code == '38'
        ? match.group(0)!
        : String.fromCharCode(int.parse(code));
  }).replaceAllMapped(RegExp(r'&#x([0-9a-f]+);', caseSensitive: false),
          (match) {
    // `&#x26;` encodes `&` itself; same treatment as above.
    final code = match.group(1)!;
    return code.toLowerCase() == '26'
        ? match.group(0)!
        : String.fromCharCode(int.parse(code, radix: 16));
  }).replaceAllMapped(RegExp(r'&(amp|#38|#x26);'), (match) => '&');
}

/// Returns a new map with all null entries removed from the given [map].
///
/// If the resulting map is empty, this function returns null.
///
/// [map]: The map to remove null entries from.
Map<String, Object>? omitNull(Map<String?, Object?> map) {
  var result = <String, Object>{};
  map.forEach((key, value) {
    if (key != null && value != null) {
      result[key] = value;
    }
  });
  if (result.isEmpty) {
    return null;
  }
  return result;
}

/// A base class for nodes in Satori message elements.
class Node {}

/// A node that represents text in Satori message elements.
///
/// This class overrides the equality operator to ignore leading and trailing whitespace.
class Text extends Node {
  /// The text of this node.
  String text;

  Text(this.text);

  @override
  String toString() {
    return escape(text);
  }

  @override
  bool operator ==(Object other) {
    return other is Text &&
        // There might be white spaces before and after the text,
        // but we don't care about them in comparison.
        other.text.trim() == text.trim();
  }

  @override
  int get hashCode => text.trim().hashCode;
}

/// A base class for nodes that can have attributes and children in a tree structure.
///
/// This class overrides the equality operator to compare the tag, attributes, and children of the nodes.
class Base extends Node {
  /// The tag of this node.
  String tag;

  /// The attributes of this node.
  Map<String, Object?>? attributes;

  /// The children of this node.
  List<Node>? children;

  Base(this.tag, {attributes, this.children}) {
    if (attributes != null) {
      this.attributes = omitNull(attributes!);
    }
    if (children != null && children!.isEmpty) {
      children = null;
    }
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write('<$tag');
    if (attributes != null) {
      attributes!.forEach((key, value) {
        if (value is bool) {
          if (value) {
            buffer.write(' $key');
          } else {
            // A false boolean serializes as `no-<key>`, mirroring the
            // official `toAttrString`.
            buffer.write(' no-$key');
          }
        } else {
          buffer.write(' $key="${escape(value.toString())}"');
        }
      });
    }
    if (children != null && children!.isNotEmpty) {
      buffer.write('>');
      for (var child in children!) {
        buffer.write(child.toString());
      }
      buffer.write('</$tag>');
    } else {
      buffer.write('/>');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (other is! Base) {
      return false;
    } else if (tag != other.tag) {
      return false;
    } else if (attributes == null && other.attributes != null) {
      return false;
    } else if (attributes != null && other.attributes == null) {
      return false;
    } else if (attributes != null && other.attributes != null) {
      if (attributes!.length != other.attributes!.length) {
        return false;
      }
      for (var key in attributes!.keys) {
        if (attributes![key] != other.attributes![key]) {
          return false;
        }
      }
    } else if (children == null && other.children != null) {
      return false;
    } else if (children != null && other.children == null) {
      return false;
    } else if (children != null && other.children != null) {
      if (children!.length != other.children!.length) {
        return false;
      }
      for (var i = 0; i < children!.length; i++) {
        if (children![i] != other.children![i]) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  int get hashCode => tag.hashCode ^ attributes.hashCode ^ children.hashCode;
}
