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

class BaseElement {
  String tag;
  Map<String, Object>? attributes;
  List<BaseElement>? children;

  BaseElement(this.tag, {this.attributes, this.children});

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

class Text {
  String text;

  Text(this.text);

  @override
  String toString() {
    return escape(text);
  }
}
