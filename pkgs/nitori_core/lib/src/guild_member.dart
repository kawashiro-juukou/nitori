import './user.dart';

import 'package:json_annotation/json_annotation.dart';

part 'guild_member.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class GuildMember {
  User user;
  String? nick;
  String? avatar;
  DateTime? joinedAt;

  GuildMember({required this.user, this.nick, this.avatar, this.joinedAt});

  factory GuildMember.fromJson(Map<String, dynamic> json) =>
      _$GuildMemberFromJson(json);

  Map<String, dynamic> toJson() => _$GuildMemberToJson(this);
}
