import './base.dart';

// #region Basic

/// Represents an `<at>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E6%8F%90%E5%8F%8A%E7%94%A8%E6%88%B7
class At extends Base {
  String? id;
  String? name;
  String? role;
  String? type;

  At({
    this.id,
    this.name,
    this.role,
    this.type,
  }) : super('at', attributes: {
          'id': id,
          'name': name,
          'role': role,
          'type': type,
        });
}

/// Represents a `<sharp>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E6%8F%90%E5%8F%8A%E9%A2%91%E9%81%93
class Sharp extends Base {
  String id;
  String? name;

  Sharp({
    required this.id,
    this.name,
  }) : super('sharp', attributes: {
          'id': id,
          'name': name,
        });
}

/// Represents an `<a> element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E9%93%BE%E6%8E%A5
class Anchor extends Base {
  String href;

  Anchor({
    required this.href,
  }) : super('a', attributes: {
          'href': href,
        });
}

// #endregion

// #region Layout

/// Represents a `<br>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E6%8D%A2%E8%A1%8C
class LineBreak extends Base {
  LineBreak() : super('br');
}

/// Represents a `<p>` element.
///
/// See also: https://satori.chat/zh-CN/protocol/elements.html#%E6%AE%B5%E8%90%BD
class Paragraph extends Base {
  Paragraph({Map<String, Object?>? attributes, List<Node>? children})
      : super('p', attributes: attributes, children: children);
}

// #endregion

// #region Meta

/// Represents a `<message>` element.
///
/// See also: https://satori.chat/zh-CN/protocol/elements.html#%E6%B6%88%E6%81%AF
class Message extends Base {
  String? id;
  bool? forward;

  Message({this.id, this.forward, List<Node>? children})
      : super('message',
            attributes: {'id': id, 'forward': forward}, children: children);
}

/// Represents a `<quote>` element.
///
/// See also: https://satori.chat/zh-CN/protocol/elements.html#%E5%BC%95%E7%94%A8
class Quote extends Base {
  Quote({Map<String, Object?>? attributes, List<Node>? children})
      : super('quote', attributes: attributes, children: children);
}

/// Represents an `<author>` element.
///
/// See also: https://satori.chat/zh-CN/protocol/elements.html#%E4%BD%9C%E8%80%85
class Author extends Base {
  String? userId;
  String? nickname;
  String? avatar;

  Author({this.userId, this.nickname, this.avatar, List<Node>? children})
      : super('author',
            attributes: {
              // The official spec uses `id` / `name` / `avatar`; the older
              // `user-id` / `nickname` spellings are still accepted by the
              // parser for backward compatibility with existing content.
              'id': userId,
              'name': nickname,
              'avatar': avatar
            },
            children: children);
}

// #endregion

// #region Modifier

/// Base class for inline modifier elements such as `<b>` and `<u>`.
///
/// Unlike the official Element tree, children stay nested so parsing
/// `<b>x<u>y</u></b>` keeps the `<u>` inside the `<b>`.
abstract class Modifier extends Base {
  Modifier._(String tag, {String? text, List<Node>? children})
      : super(tag, children: [
          if (text != null) Text(text),
          ...?children,
        ]);

  /// The plain text content of this modifier, including nested text.
  String get text =>
      children?.whereType<Text>().map((e) => e.text).join('') ?? '';
}

/// Represents a `<b>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E7%B2%97%E4%BD%93
class Bold extends Modifier {
  Bold(String text) : super._('b', text: text);
  Bold.children(List<Node> children) : super._('b', children: children);
}

/// Represents an `<i>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E6%96%9C%E4%BD%93
class Idiomatic extends Modifier {
  Idiomatic(String text) : super._('i', text: text);
  Idiomatic.children(List<Node> children) : super._('i', children: children);
}

/// Represents a `<u>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E4%B8%8B%E5%88%92%E7%BA%BF
class Underline extends Modifier {
  Underline(String text) : super._('u', text: text);
  Underline.children(List<Node> children) : super._('u', children: children);
}

/// Represents an `<s>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E5%88%A0%E9%99%A4%E7%BA%BF
class Strikethrough extends Modifier {
  Strikethrough(String text) : super._('s', text: text);
  Strikethrough.children(List<Node> children)
      : super._('s', children: children);
}

/// Represents a `<spl>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E5%89%A7%E9%80%8F
class Spoiler extends Modifier {
  Spoiler(String text) : super._('spl', text: text);
  Spoiler.children(List<Node> children) : super._('spl', children: children);
}

/// Represents a `<code>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E4%BB%A3%E7%A0%81
class Code extends Modifier {
  Code(String text) : super._('code', text: text);
  Code.children(List<Node> children) : super._('code', children: children);
}

/// Represents a `<sup>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E4%B8%8A%E6%A0%87
class Superscript extends Modifier {
  Superscript(String text) : super._('sup', text: text);
  Superscript.children(List<Node> children)
      : super._('sup', children: children);
}

/// Represents a `<sub>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E4%B8%8B%E6%A0%87
class Subscript extends Modifier {
  Subscript(String text) : super._('sub', text: text);
  Subscript.children(List<Node> children) : super._('sub', children: children);
}

// #endregion

// #region Experimental

/// Represents a `<button>` element.
///
/// See also: https://satori.chat/zh-CN/protocol/elements.html#%E6%8C%89%E9%92%AE-%E5%AE%9E%E9%AA%8C%E6%80%A7
class Button extends Base {
  String? id;

  Button(
    String text, {
    this.id,
    Map<String, Object?>? attributes,
  }) : super('button',
            attributes: {...?attributes, 'id': id}, children: [Text(text)]);

  Button.children(
    List<Node> children, {
    this.id,
    Map<String, Object?>? attributes,
  }) : super('button',
            attributes: {...?attributes, 'id': id}, children: children);
}

// #endregion

// #region Resource

/// Abstract class for resource elements.
class _ResourceElement extends Base {
  String src;
  bool? cache;
  String? timeout;
  String? title;

  _ResourceElement({
    required String tag,
    required this.src,
    this.cache,
    this.timeout,
    this.title,
    Map<String, Object?>? attributes,
  }) : super(tag,
            attributes: {
              'src': src,
              'cache': cache,
              'timeout': timeout,
              'title': title,
            }..addAll(attributes ?? {}));
}

/// Represents an `<img>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E5%9B%BE%E7%89%87
class Image extends _ResourceElement {
  int? width;
  int? height;

  Image({
    required String src,
    this.width,
    this.height,
    bool? cache,
    String? timeout,
    String? title,
  }) : super(
          tag: 'img',
          src: src,
          cache: cache,
          timeout: timeout,
          title: title,
          attributes: {
            'width': width,
            'height': height,
          },
        );
}

/// Represents an `<audio>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E8%AF%AD%E9%9F%B3
class Audio extends _ResourceElement {
  String? duration;
  String? poster;

  Audio({
    required String src,
    bool? cache,
    String? timeout,
    String? title,
    this.duration,
    this.poster,
  }) : super(
          tag: 'audio',
          src: src,
          cache: cache,
          timeout: timeout,
          title: title,
          attributes: {
            'duration': duration,
            'poster': poster,
          },
        );
}

/// Represents a `<video>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E8%A7%86%E9%A2%91
class Video extends _ResourceElement {
  int? width;
  int? height;
  String? duration;
  String? poster;

  Video({
    required String src,
    this.width,
    this.height,
    bool? cache,
    String? timeout,
    String? title,
    this.duration,
    this.poster,
  }) : super(
          tag: 'video',
          src: src,
          cache: cache,
          timeout: timeout,
          title: title,
          attributes: {
            'width': width,
            'height': height,
            'duration': duration,
            'poster': poster,
          },
        );
}

/// Represents a `<file>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E6%96%87%E4%BB%B6
class File extends _ResourceElement {
  String? poster;

  File({
    required String src,
    bool? cache,
    String? timeout,
    String? title,
    this.poster,
  }) : super(
          tag: 'file',
          src: src,
          cache: cache,
          timeout: timeout,
          title: title,
          attributes: {
            'poster': poster,
          },
        );
}

// #endregion
