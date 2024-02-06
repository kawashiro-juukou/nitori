import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class User {
  String id;
  String? name;
  String? nick;
  String? avatar;
  bool? isBot;

  User({required this.id, this.name, this.nick, this.avatar, this.isBot});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
