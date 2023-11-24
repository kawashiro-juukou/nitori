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
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E6%AE%B5%E8%90%BD
class Paragraph extends Base {
  Paragraph({attributes, children})
      : super('p', attributes: attributes, children: children);
}

// #endregion

// #region Meta

/// Represents a `<message>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E6%B6%88%E6%81%AF
class Message extends Base {
  String? id;
  bool? forward;

  Message({this.id, this.forward, children})
      : super('message',
            attributes: {'id': id, 'forward': forward}, children: children);
}

/// Represents a `<quote>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E5%BC%95%E7%94%A8
class Quote extends Base {
  Quote({attributes, children})
      : super('quote', attributes: attributes, children: children);
}

/// Represents an `<author>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E4%BD%9C%E8%80%85
class Author extends Base {
  String? userId;
  String? nickname;
  String? avatar;

  Author({this.userId, this.nickname, this.avatar, children})
      : super('author',
            attributes: {
              'user-id': userId,
              'nickname': nickname,
              'avatar': avatar
            },
            children: children);
}

// #endregion

// #region Modifier

/// Represents a `<b>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E7%B2%97%E4%BD%93
class Bold extends Base {
  Bold(String text) : super('b', children: [Text(text)]);
}

/// Represents a `<i>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E6%96%9C%E4%BD%93
class Idiomatic extends Base {
  Idiomatic(String text) : super('i', children: [Text(text)]);
}

/// Represents a `<u>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E4%B8%8B%E5%88%92%E7%BA%BF
class Underline extends Base {
  Underline(String text) : super('u', children: [Text(text)]);
}

/// Represents a `<s>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E5%88%A0%E9%99%A4%E7%BA%BF
class Strikethrough extends Base {
  Strikethrough(String text) : super('s', children: [Text(text)]);
}

/// Represents a `<spl>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E5%89%A7%E9%80%8F
class Spoiler extends Base {
  Spoiler(String text) : super('spl', children: [Text(text)]);
}

/// Represents a `<code>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E4%BB%A3%E7%A0%81
class Code extends Base {
  Code(String text) : super('code', children: [Text(text)]);
}

/// Represents a `<sup>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E4%B8%8A%E6%A0%87
class Superscript extends Base {
  Superscript(String text) : super('sup', children: [Text(text)]);
}

/// Represents a `<sub>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E4%B8%8B%E6%A0%87
class Subscript extends Base {
  Subscript(String text) : super('sub', children: [Text(text)]);
}

// #endregion

// #region Resource

/// Abstract class for resource elements.
class _ResourceElement extends Base {
  String src;
  bool? cache;
  String? timeout;

  _ResourceElement({
    required String tag,
    required this.src,
    this.cache,
    this.timeout,
    Map<String, Object?>? attributes,
  }) : super(tag,
            attributes: {
              'src': src,
              'cache': cache,
              'timeout': timeout,
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
  }) : super(
          tag: 'img',
          src: src,
          cache: cache,
          timeout: timeout,
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
  Audio({
    required String src,
    bool? cache,
    String? timeout,
  }) : super(
          tag: 'audio',
          src: src,
          cache: cache,
          timeout: timeout,
        );
}

/// Represents a `<video>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E8%A7%86%E9%A2%91
class Video extends _ResourceElement {
  Video({
    required String src,
    bool? cache,
    String? timeout,
  }) : super(
          tag: 'video',
          src: src,
          cache: cache,
          timeout: timeout,
        );
}

/// Represents a `<file>` element.
///
/// See also: https://satori.js.org/zh-CN/protocol/elements.html#%E6%96%87%E4%BB%B6
class File extends _ResourceElement {
  File({
    required String src,
    bool? cache,
    String? timeout,
  }) : super(
          tag: 'file',
          src: src,
          cache: cache,
          timeout: timeout,
        );
}

// #endregion
