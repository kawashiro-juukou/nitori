import '../base.dart';

class ResourceElement extends BaseElement {
  String src;
  bool? cache;
  String? timeout;

  ResourceElement({
    required this.src,
    this.cache,
    this.timeout,
  }) : super('resource', attributes: {
          'src': src,
          'cache': cache,
          'timeout': timeout,
        });
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
          src: src,
          cache: cache,
          timeout: timeout,
        );
}

typedef AudioElement = ResourceElement;
typedef VideoElement = ResourceElement;
typedef FileElement = ResourceElement;
