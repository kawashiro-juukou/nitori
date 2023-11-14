import '../base.dart';

class ResourceElement extends BaseElement {
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

class ImgElement extends ResourceElement {
  int? width;
  int? height;

  ImgElement({
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

typedef ImageElement = ImgElement;

class AudioElement extends ResourceElement {
  AudioElement({
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

class VideoElement extends ResourceElement {
  VideoElement({
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

class FileElement extends ResourceElement {
  FileElement({
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
