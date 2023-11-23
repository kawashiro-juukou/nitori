String escape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String unescape(String text) {
  return text
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

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

class Node {}

class Text extends Node {
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
  int get hashCode => text.hashCode;
}

class Base extends Node {
  String tag;
  Map<String, Object?>? attributes;
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
            buffer.write(' $key="false"');
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
