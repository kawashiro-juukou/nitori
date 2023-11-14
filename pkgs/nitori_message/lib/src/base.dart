String escape(String text) {
  return text
    ..replaceAll('"', '&quot;')
    ..replaceAll('&', '&amp;')
    ..replaceAll('<', '&lt;')
    ..replaceAll('>', '&gt;');
}

String unescape(String text) {
  return text
    ..replaceAll('&quot;', '"')
    ..replaceAll('&amp;', '&')
    ..replaceAll('&lt;', '<')
    ..replaceAll('&gt;', '>');
}

class BaseElement {
  String tag;
  Map<String, String>? attributes;
  List<BaseElement>? children;

  BaseElement(this.tag, {this.attributes, this.children});

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write('<$tag');
    if (attributes != null) {
      attributes!.forEach((key, value) {
        buffer.write(' $key="${escape(value)}"');
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
