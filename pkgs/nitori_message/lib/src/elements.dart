import './base.dart';

// #region Basic

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

class LineBreak extends Base {
  LineBreak() : super('br');
}

class Paragraph extends Base {
  Paragraph({attributes, children})
      : super('p', attributes: attributes, children: children);
}

// #endregion

// #region Meta

class Message extends Base {
  String? id;
  bool? forward;

  Message({this.id, this.forward, children})
      : super('message',
            attributes: {'id': id, 'forward': forward}, children: children);
}

class Quote extends Base {
  Quote({attributes, children})
      : super('quote', attributes: attributes, children: children);
}

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

class Bold extends Base {
  Bold(String text) : super('b', children: [Text(text)]);
}

class Idiomatic extends Base {
  Idiomatic(String text) : super('i', children: [Text(text)]);
}

class Underline extends Base {
  Underline(String text) : super('u', children: [Text(text)]);
}

class Strikethrough extends Base {
  Strikethrough(String text) : super('s', children: [Text(text)]);
}

class Spoiler extends Base {
  Spoiler(String text) : super('spl', children: [Text(text)]);
}

class Code extends Base {
  Code(String text) : super('code', children: [Text(text)]);
}

class Superscript extends Base {
  Superscript(String text) : super('sup', children: [Text(text)]);
}

class Subscript extends Base {
  Subscript(String text) : super('sub', children: [Text(text)]);
}

// #endregion

// #region Resource

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
