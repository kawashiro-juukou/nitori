import './base.dart';
import './elements.dart';

/// create a [Node] by tag name
Node? _createTag(String tag, dynamic attributes, dynamic children) {
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
      return Anchor(href: attributes['href']);
    case 'img':
      return Image(
          src: attributes['src'],
          cache: attributes['cache'],
          timeout: attributes['timeout'],
          width: int.tryParse(attributes['width'] ?? ''),
          height: int.tryParse(attributes['height'] ?? ''));
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
      return Bold((children as List<Node>)
          .whereType<Text>()
          .map((e) => e.text)
          .join(''));
    case 'i':
    case 'em':
      return Idiomatic((children as List<Node>)
          .whereType<Text>()
          .map((e) => e.text)
          .join(''));
    case 'u':
    case 'ins':
      return Underline((children as List<Node>)
          .whereType<Text>()
          .map((e) => e.text)
          .join(''));
    case 's':
    case 'del':
      return Strikethrough((children as List<Node>)
          .whereType<Text>()
          .map((e) => e.text)
          .join(''));
    case 'spl':
      return Spoiler((children as List<Node>)
          .whereType<Text>()
          .map((e) => e.text)
          .join(''));
    case 'code':
      return Code((children as List<Node>)
          .whereType<Text>()
          .map((e) => e.text)
          .join(''));
    case 'sup':
      return Superscript((children as List<Node>)
          .whereType<Text>()
          .map((e) => e.text)
          .join(''));
    case 'sub':
      return Subscript((children as List<Node>)
          .whereType<Text>()
          .map((e) => e.text)
          .join(''));
    case 'br':
      return LineBreak();
    case 'p':
      return Paragraph(attributes: attributes, children: children);
    case 'message':
      return Message(
          id: attributes['id'],
          forward: attributes['forward'] == null
              ? null
              : attributes['forward'] is bool
                  ? attributes['forward']
                  : bool.tryParse(attributes['forward'] ?? ''),
          children: children);
    case 'quote':
      return Quote(attributes: attributes, children: children);
    case 'author':
      return Author(
          userId: attributes['user-id'],
          nickname: attributes['nickname'],
          avatar: attributes['avatar']);

    default:
      return Base(tag, attributes: attributes, children: children);
  }
}

/// A tokenizer that splits the input into tokens
class Tokenizer {
  /// The input string
  final String input;
  /// The current position
  late int position;

  Tokenizer(this.input) {
    position = 0;
  }

  /// Returns the next token without advancing the position
  String? peek() {
    var oldPosition = position;
    var token = next();
    position = oldPosition;
    return token;
  }

  /// Returns the next token and advances the position
  String? next() {
    if (position >= input.length) {
      return null;
    }

    var buffer = StringBuffer();
    while (position < input.length) {
      var char = input[position];
      if (char == '<') {
        if (buffer.isNotEmpty) {
          break;
        }
      } else if (char == '>') {
        if (buffer.isNotEmpty) {
          buffer.write(char);
          position++;
          break;
        }
      }
      buffer.write(char);
      position++;
    }

    return buffer.toString();
  }

  /// Checks if there are more tokens
  bool hasNext() {
    return position < input.length;
  }
}

/// A parser that parses tokens into a tree of nodes
class Parser {
  /// The tokenizer
  final Tokenizer tokenizer;

  Parser(String input) : tokenizer = Tokenizer(input);

  /// Checks if there are more tokens
  hasNext() => tokenizer.hasNext();

  /// Parses the next token
  Node? parse() {
    var token = tokenizer.next();
    if (token == null) {
      throw Exception('Unexpected end of input');
    }

    if (token.startsWith('<')) {
      // Parse a tag
      var isClosingTag = token.startsWith('</');
      var isSelfClosingTag = token.endsWith('/>');
      var tagName = isClosingTag
          ? token.substring(2, token.length - 1)
          : token.substring(1, token.length - (isSelfClosingTag ? 2 : 1));
      var attributes = <String, Object>{};
      var children = <Node>[];

      if (!isClosingTag && !isSelfClosingTag) {
        // Parse attributes and children
        while (tokenizer.hasNext() && !tokenizer.peek()!.startsWith('</')) {
          var child = parse();
          if (child != null) {
            children.add(child);
          }
        }
        // Skip the closing tag
        tokenizer.next();
      }

      var tagNameIndex = tagName.indexOf(' ');
      var attributesStr = tagNameIndex == -1
          ? ''
          : tagName.substring(tagNameIndex + 1, tagName.length);
      tagName =
          tagNameIndex == -1 ? tagName : tagName.substring(0, tagNameIndex);

      // Parse attributes
      var attributeRegex = RegExp(r'([\w-]+)(?:="([^"]*)")?');
      var match = attributeRegex.firstMatch(attributesStr);
      while (match != null) {
        var key = match.group(1);
        var value = match.group(2);
        if (key != null && value != null) {
          attributes[key] = value;
        } else if (key != null) {
          attributes[key] = true;
        }
        attributesStr = attributesStr.substring(match.end);
        match = attributeRegex.firstMatch(attributesStr);
      }

      return _createTag(tagName, attributes, children);
    } else {
      if (token.trim().isEmpty) {
        // Skip empty text
        return null;
      }
      // Parse a text node
      return Text(token);
    }
  }
}

/// Parses the input into a tree of nodes
List<Node> parse(String input) {
  var parser = Parser(input);
  var nodes = <Node>[];
  while (parser.hasNext()) {
    var node = parser.parse();
    if (node != null) {
      nodes.add(node);
    }
  }
  return nodes;
}
