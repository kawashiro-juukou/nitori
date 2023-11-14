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

Map<String, Object> omitNull(Map<String, Object?> map) {
  var result = <String, Object>{};
  map.forEach((key, value) {
    if (value != null) {
      result[key] = value;
    }
  });
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
}

class BaseElement extends Node {
  String tag;
  Map<String, Object?>? attributes;
  List<Node>? children;

  BaseElement(this.tag, {attributes, this.children}) {
    if (attributes != null) {
      attributes = omitNull(attributes!);
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
    if (children != null) {
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
}