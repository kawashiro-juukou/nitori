import './base.dart';
import './elements.dart';

/// create a [Node] by tag name
Node? createTag(String tag, dynamic attributes, dynamic children) {
  switch (tag) {
    case 'at':
      return At(
          id: attributes['id'],
          name: attributes['name'],
          role: attributes['role'],
          type: attributes['type']);
    case 'sharp':
      return Sharp(id: attributes['id'], name: attributes['name']);
    case 'a':
      return A(href: attributes['href']);
    case 'img':
      return Img(
          src: attributes['src'],
          cache: attributes['cache'],
          timeout: attributes['timeout']);
    case 'audio':
      return Audio(
          src: attributes['src'],
          cache: attributes['cache'],
          timeout: attributes['timeout']);
    case 'video':
      return Video(
          src: attributes['src'],
          cache: attributes['cache'],
          timeout: attributes['timeout']);
    case 'file':
      return File(
          src: attributes['src'],
          cache: attributes['cache'],
          timeout: attributes['timeout']);
    case 'b':
    case 'strong':
      return Strong(children);
    case 'i':
    case 'em':
      return Em(children);
    case 'u':
    case 'ins':
      return Ins(children);
    case 's':
    case 'del':
      return Del(children);
    case 'spl':
      return Spl(children);
    case 'code':
      return Code(children);
    case 'sup':
      return Sup(children);
    case 'sub':
      return Sub(children);
    case 'br':
      return Br();
    case 'p':
      return P(attributes: attributes, children: children);
    case 'message':
      return Message(
          id: attributes['id'],
          forward: attributes['forward'],
          children: children);
    case 'quote':
      return Quote(attributes: attributes, children: children);
    case 'author':
      return Author(
          userId: attributes['user-id'],
          nickname: attributes['nickname'],
          avatar: attributes['avatar']);

    default:
      return null;
  }
}

/// parse a html like string to a HTML Tag
Node? parseTag(String str, int index) {
  var length = str.length;
  var char = str[index];
  if (char != '<') {
    return Text(char);
  }
  var buffer = StringBuffer();
  var tag = '';
  var attributes = <String, Object?>{};
  var children = <Node>[];
  var state = 0;
  var key = '';
  var value = '';
  var quote = '';
  var i = index + 1;
  while (i < length) {
    var char = str[i];
    if (state == 0) {
      if (char == ' ') {
        state = 1;
      } else if (char == '>') {
        return Base(tag, attributes: attributes, children: children);
      } else {
        tag += char;
      }
    } else if (state == 1) {
      if (char == ' ') {
        continue;
      } else if (char == '>') {
        return Base(tag, attributes: attributes, children: children);
      } else {
        state = 2;
        buffer.write(char);
      }
    } else if (state == 2) {
      if (char == '=') {
        key = buffer.toString();
        buffer.clear();
        state = 3;
      } else if (char == ' ') {
        key = buffer.toString();
        buffer.clear();
        state = 4;
      } else {
        buffer.write(char);
      }
    } else if (state == 3) {
      if (char == '"' || char == "'") {
        quote = char;
      } else {
        buffer.write(char);
        quote = '';
      }
      state = 5;
    } else if (state == 4) {
      if (char == '=') {
        state = 3;
      } else if (char == ' ') {
        continue;
      } else {
        buffer.write(char);
        state = 5;
      }
    } else if (state == 5) {
      if (char == quote) {
        value = buffer.toString();
        buffer.clear();
        attributes[key] = value;
        state = 0;
      } else {
        buffer.write(char);
      }
    }
    i++;
  }

  return null;
}

/// parse a html like string to a list of HTML Tag
List<Node> parse(String str) {
  List<Node> result = [];
  var buffer = StringBuffer();
  var index = 0;
  var length = str.length;
  while (index < length) {
    var char = str[index];
    if (char == '<') {
      if (buffer.isNotEmpty) {
        result.add(Text(buffer.toString()));
        buffer.clear();
      }
      var tag = parseTag(str, index);
      if (tag != null) {
        result.add(tag);
        index += tag.toString().length;
      } else {
        buffer.write(char);
      }
    } else {
      buffer.write(char);
    }
    index++;
  }

  if (buffer.isNotEmpty) {
    result.add(Text(buffer.toString()));
  }

  return result;
}
