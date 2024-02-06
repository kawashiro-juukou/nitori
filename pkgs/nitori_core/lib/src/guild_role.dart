import './base.dart';

import 'package:json_annotation/json_annotation.dart';

part 'guild_role.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class GuildRole {
  String id;
  String name;

  GuildRole({required this.id, required this.name});

  factory GuildRole.fromJson(Map<String, dynamic> json) =>
      _$GuildRoleFromJson(json);

  Map<String, dynamic> toJson() => _$GuildRoleToJson(this);
}

abstract class GuildRoleInterface {
  Future setGuildMemberRole(String guildId, String roleId, String userId);
  Future unsetGuildMemberRole(String guildId, String roleId, String userId);
  Future<Pagination<GuildRole>> getGuildRoles(String guildId);
  Future<GuildRole> createGuildRole(String guildId, String name);
  Future updateGuildRole(String guildId, String roleId, GuildRole role);
  Future deleteGuildRole(String guildId, String roleId);
}
