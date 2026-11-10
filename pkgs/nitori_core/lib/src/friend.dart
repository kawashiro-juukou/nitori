import 'package:json_annotation/json_annotation.dart';

import './user.dart';

part 'friend.g.dart';

@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class Friend {
  User? user;
  String? nick;

  Friend({this.user, this.nick});

  factory Friend.fromJson(Map<String, dynamic> json) => _$FriendFromJson(json);

  Map<String, dynamic> toJson() => _$FriendToJson(this);
}
