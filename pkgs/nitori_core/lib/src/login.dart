import './user.dart';

import 'package:json_annotation/json_annotation.dart';

part 'login.g.dart';

enum Status {
  offline(0),
  online(1),
  connect(2),
  disconnect(3),
  reconnect(4);

  const Status(this.value);
  final int value;
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Login {
  Status status;
  User? user;
  String? selfId;
  String? platform;

  Login({ required this.status, this.user, this.selfId, this.platform});

  factory Login.fromJson(Map<String, dynamic> json) => _$LoginFromJson(json);

  Map<String, dynamic> toJson() => _$LoginToJson(this);
}

abstract class LoginInterface {
  Future<Login> getLogin();
}
