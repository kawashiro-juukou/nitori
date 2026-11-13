import './base.dart';
import './elements.dart';

/// Reads a raw attribute as an optional [String], dropping booleans.
String? _string(Map<String, Object> attributes, String key) {
  var value = attributes[key];
  return value is String ? value : null;
}

/// Reads a raw attribute as an optional [bool], accepting both the official
/// `no-<key>` spelling (a bare [bool]) and a literal `true` / `false`.
bool? _boolean(Map<String, Object> attributes, String key) {
  var value = attributes[key];
  if (value is bool) {
    return value;
  }
  if (value == 'true') {
    return true;
  }
  if (value == 'false') {
    return false;
  }
  return null;
}

/// create a [Node] by tag name
Node? _createTag(
  String tag,
  Map<String, Object> attributes,
  List<Node> children,
) {
  switch (tag) {
    case 'at':
      return At(
        id: _string(attributes, 'id'),
        name: _string(attributes, 'name'),
        role: _string(attributes, 'role'),
        type: _string(attributes, 'type'),
      );
    case 'sharp':
      return Sharp(
        id: _string(attributes, 'id') ?? '',
        name: _string(attributes, 'name'),
      );
    case 'a':
      return Anchor(href: _string(attributes, 'href') ?? '');
    case 'img':
      return Image(
        src: _string(attributes, 'src') ?? '',
        cache: _boolean(attributes, 'cache'),
        timeout: _string(attributes, 'timeout'),
        title: _string(attributes, 'title'),
        width: int.tryParse(_string(attributes, 'width') ?? ''),
        height: int.tryParse(_string(attributes, 'height') ?? ''),
      );
    case 'audio':
      return Audio(
        src: _string(attributes, 'src') ?? '',
        cache: _boolean(attributes, 'cache'),
        timeout: _string(attributes, 'timeout'),
        title: _string(attributes, 'title'),
        duration: _string(attributes, 'duration'),
        poster: _string(attributes, 'poster'),
      );
    case 'video':
      return Video(
        src: _string(attributes, 'src') ?? '',
        cache: _boolean(attributes, 'cache'),
        timeout: _string(attributes, 'timeout'),
        title: _string(attributes, 'title'),
        width: int.tryParse(_string(attributes, 'width') ?? ''),
        height: int.tryParse(_string(attributes, 'height') ?? ''),
        duration: _string(attributes, 'duration'),
        poster: _string(attributes, 'poster'),
      );
    case 'file':
      return File(
        src: _string(attributes, 'src') ?? '',
        cache: _boolean(attributes, 'cache'),
        timeout: _string(attributes, 'timeout'),
        title: _string(attributes, 'title'),
        poster: _string(attributes, 'poster'),
      );
    case 'b':
    case 'strong':
      return Bold.children(children);
    case 'i':
    case 'em':
      return Idiomatic.children(children);
    case 'u':
    case 'ins':
      return Underline.children(children);
    case 's':
    case 'del':
      return Strikethrough.children(children);
    case 'spl':
      return Spoiler.children(children);
    case 'code':
      return Code.children(children);
    case 'sup':
      return Superscript.children(children);
    case 'sub':
      return Subscript.children(children);
    case 'br':
      return LineBreak();
    case 'p':
      return Paragraph(attributes: attributes, children: children);
    case 'message':
      return Message(
        id: _string(attributes, 'id'),
        forward: _boolean(attributes, 'forward'),
        children: children,
      );
    case 'quote':
      return Quote(attributes: attributes, children: children);
    case 'author':
      // The official spelling is `id` / `name`; the legacy `user-id` /
      // `nickname` spellings are still honored when reading.
      return Author(
        userId: _string(attributes, 'id') ?? _string(attributes, 'user-id'),
        nickname:
            _string(attributes, 'name') ?? _string(attributes, 'nickname'),
        avatar: _string(attributes, 'avatar'),
      );
    case 'button':
      return Button.children(children, id: _string(attributes, 'id'));
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
        // A comment token is consumed atomically, before the generic
        // tag-splitting logic can mangle it.
        if (input.startsWith('<!--', position)) {
          var end = input.indexOf('-->', position + 4);
          var tokenEnd = end == -1 ? input.length : end + 3;
          var token = input.substring(position, tokenEnd);
          position = tokenEnd;
          return token;
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

  /// Whether the previous token ended with a tag, so a newline right after it
  /// should be trimmed (mirrors the official trimStart / trimEnd behavior).
  bool _trimNext = true;

  Parser(String input) : tokenizer = Tokenizer(input);

  /// Checks if there are more tokens
  hasNext() => tokenizer.hasNext();

  /// Parses the next token
  Node? parse() {
    var token = tokenizer.next();
    if (token == null) {
      throw Exception('Unexpected end of input');
    }

    if (token.startsWith('<!--')) {
      // Comments are dropped from the tree but never break parsing.
      return null;
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

      var tagNameIndex = tagName.indexOf(' ');
      var attributesStr = tagNameIndex == -1
          ? ''
          : tagName.substring(tagNameIndex + 1, tagName.length);
      tagName = tagNameIndex == -1
          ? tagName
          : tagName.substring(0, tagNameIndex);

      if (!isClosingTag && !isSelfClosingTag) {
        // Parse attributes and children
        while (tokenizer.hasNext() && !tokenizer.peek()!.startsWith('</')) {
          var child = parse();
          if (child != null) {
            children.add(child);
          }
        }
        // Skip the closing tag
        var closingTag = tokenizer.next();
        if (closingTag != null) {
          var expected = '</$tagName>';
          if (closingTag != expected) {
            throw Exception(
              'Mismatched closing tag: expected $expected, got $closingTag',
            );
          }
        }
      }

      // A newline right next to a tag is layout noise; other whitespace is
      // kept, matching the official parser.
      _trimNext = true;

      // Parse attributes; values may be double-quoted, single-quoted or bare.
      // The single-quote alternatives are assembled from a code point to keep
      // the regexp literal readable in source.
      var sq = String.fromCharCode(39);
      var attributeRegex = RegExp(
        '([^\\s=]+)(?:="([^"]*)"|='
        '$sq([^$sq]*)$sq'
        ')?',
      );
      var match = attributeRegex.firstMatch(attributesStr);
      while (match != null) {
        var key = match.group(1);
        var value = match.group(2) ?? match.group(3);
        if (key != null) {
          if (value != null) {
            attributes[key] = unescape(value);
          } else if (key.startsWith('no-')) {
            // `no-cache` is the official spelling of `cache=false`.
            attributes[key.substring(3)] = false;
          } else {
            attributes[key] = true;
          }
        }
        attributesStr = attributesStr.substring(match.end);
        match = attributeRegex.firstMatch(attributesStr);
      }

      return _createTag(tagName, attributes, children);
    } else {
      var text = token;
      if (_trimNext) {
        // Whitespace (with a newline) right after a tag is dropped.
        text = text.replaceFirst(RegExp(r'^\s*\n\s*'), '');
      }
      // Whitespace before a tag is handled by peeking ahead: a trailing
      // newline right before the next tag is dropped too.
      var nextTagFollows =
          tokenizer.hasNext() &&
          (tokenizer.peek()!.startsWith('</') ||
              tokenizer.peek()!.startsWith('<'));
      if (nextTagFollows) {
        text = text.replaceFirst(RegExp(r'\s*\n\s*$'), '');
      }
      _trimNext = false;
      if (text.isEmpty) {
        return null;
      }
      // Parse a text node; text content is unescaped like attribute values.
      return Text(unescape(text));
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
