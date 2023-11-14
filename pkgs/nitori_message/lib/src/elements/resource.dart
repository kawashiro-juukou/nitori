import '../base.dart';

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
