import '../base.dart';

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
