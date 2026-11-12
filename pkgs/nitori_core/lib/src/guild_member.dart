import 'package:json_annotation/json_annotation.dart';

import './base.dart';
import './guild_role.dart';
import './user.dart';

part 'guild_member.g.dart';

@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class GuildMember {
  User user;
  String? name;
  String? nick;
  String? avatar;
  String? title;

  /// Millisecond UNIX timestamp, as defined by the protocol.
  int? joinedAt;

  List<GuildRole>? roles;

  GuildMember(
      {required this.user,
      this.name,
      this.nick,
      this.avatar,
      this.title,
      this.joinedAt,
      this.roles});

  factory GuildMember.fromJson(Map<String, dynamic> json) =>
      _$GuildMemberFromJson(json);

  Map<String, dynamic> toJson() => _$GuildMemberToJson(this);
}

abstract class GuildMemberInterface {
  Future<GuildMember> getGuildMember(String guildId, String userId);

  Future<Pagination<GuildMember>> getGuildMemberList(String guildId,
      {String? next});

  /// Returns an async iterable of all members in a guild.
  Stream<GuildMember> getGuildMemberIter(String guildId);

  /// `duration` and `reason` are only sent when muting; a `null` duration
  /// unmutes the member.
  Future<void> muteGuildMember(String guildId, String userId,
      {int? duration, String? reason});

  Future<void> kickGuildMember(String guildId, String userId,
      {bool? permanent});

  /// Assigns a role to a guild member.
  Future<void> setGuildMemberRole(String guildId, String userId, String roleId);

  /// Removes a role from a guild member.
  Future<void> unsetGuildMemberRole(
      String guildId, String userId, String roleId);

  /// Returns a paginated list of roles assigned to a guild member.
  Future<Pagination<GuildRole>> getGuildMemberRoleList(
      String guildId, String userId,
      {String? next});
}
