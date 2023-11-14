import './base.dart';

class AtElement extends BaseElement {
  String? id;
  String? name;
  String? role;
  String? type;

  AtElement({
    this.id,
    this.name,
    this.role,
    this.type,
  }) : super('at',
            attributes: {
              'id': id,
              'name': name,
              'role': role,
              'type': type,
        });
}

class SharpElement extends BaseElement {
  String id;
  String? name;

  SharpElement({
    required this.id,
    this.name,
  }) : super('sharp',
            attributes: {
              'id': id,
              'name': name,
        });
}

class AElement extends BaseElement {
  String href;

  AElement({
    required this.href,
  }) : super('a',
            attributes: {
              'href': href,
        });
}
