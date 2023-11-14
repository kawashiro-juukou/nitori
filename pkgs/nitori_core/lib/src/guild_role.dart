import './base.dart';

class GuildRole {
  String id;
  String name;

  GuildRole(this.id, this.name);

  factory GuildRole.fromJson(Map<String, dynamic> json) {
    return GuildRole(
      json['id'],
      json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

abstract class GuildRoleInterface {
  Future setGuildMemberRole(String guildId, String roleId, String userId);
  Future unsetGuildMemberRole(String guildId, String roleId, String userId);
  Future<Pagination<GuildRole>> getGuildRoles(String guildId);
  Future<GuildRole> createGuildRole(String guildId, String name);
  Future updateGuildRole(String guildId, String roleId, GuildRole role);
  Future deleteGuildRole(String guildId, String roleId);
}
