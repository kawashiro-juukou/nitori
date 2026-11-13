import './user.dart';

import 'package:json_annotation/json_annotation.dart';

part 'login.g.dart';

// The protocol transmits these as integers, not as the enum names.
@JsonEnum(valueField: 'value')
enum Status {
  offline(0),
  online(1),
  connect(2),
  disconnect(3),
  reconnect(4);

  const Status(this.value);

  final int value;
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class Login {
  /// Sequence number of this login, assigned by the server.
  int? sn;

  /// Name of the adapter that produced this login.
  String? adapter;

  Status status;
  User? user;
  String? platform;

  /// Advertised platform capabilities.
  List<String> features;

  /// Whether the bot is hidden from platform user lists.
  bool? hidden;

  Login({
    required this.status,
    this.user,
    this.platform,
    this.sn,
    this.adapter,
    List<String>? features,
    this.hidden,
  }) : features = features ?? <String>[];

  factory Login.fromJson(Map<String, dynamic> json) => _$LoginFromJson(json);

  Map<String, dynamic> toJson() => _$LoginToJson(this);
}

abstract class LoginInterface {
  Future<Login> getLogin();
}
