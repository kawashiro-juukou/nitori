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

class A extends Base {
  String href;

  A({
    required this.href,
  }) : super('a', attributes: {
          'href': href,
        });
}

// #endregion

// #region Layout

class Br extends Base {
  Br() : super('br');
}

class P extends Base {
  P({attributes, children})
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

class Strong extends Base {
  Strong(String text) : super('strong', children: [Text(text)]);
}

class Em extends Base {
  Em(String text) : super('em', children: [Text(text)]);
}

class Ins extends Base {
  Ins(String text) : super('ins', children: [Text(text)]);
}

class Del extends Base {
  Del(String text) : super('del', children: [Text(text)]);
}

class Spl extends Base {
  Spl(String text) : super('spl', children: [Text(text)]);
}

class Code extends Base {
  Code(String text) : super('code', children: [Text(text)]);
}

class Sup extends Base {
  Sup(String text) : super('sup', children: [Text(text)]);
}

class Sub extends Base {
  Sub(String text) : super('sub', children: [Text(text)]);
}

// #endregion

// #region Resource

class ResourceElement extends Base {
  String src;
  bool? cache;
  String? timeout;

  ResourceElement({
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

class Img extends ResourceElement {
  int? width;
  int? height;

  Img({
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

typedef Image = Img;

class Audio extends ResourceElement {
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

class Video extends ResourceElement {
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

class File extends ResourceElement {
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
