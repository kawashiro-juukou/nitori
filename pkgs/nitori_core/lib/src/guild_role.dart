import 'package:json_annotation/json_annotation.dart';

import './base.dart';

part 'guild_role.g.dart';

@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class GuildRole {
  String id;
  String? name;

  int? color;
  int? position;

  /// Permission bitmask. Upstream types it as `bigint` because it exceeds 2^53
  /// on platforms that hand out 64-bit masks, so it travels as a decimal string
  /// on the wire; `BigInt` mirrors that without losing precision.
  BigInt? permissions;
  bool? hoist;
  bool? mentionable;

  GuildRole(
      {required this.id,
      this.name,
      this.color,
      this.position,
      this.permissions,
      this.hoist,
      this.mentionable});

  factory GuildRole.fromJson(Map<String, dynamic> json) =>
      _$GuildRoleFromJson(json);

  Map<String, dynamic> toJson() => _$GuildRoleToJson(this);
}

abstract class GuildRoleInterface {
  Future<void> setGuildMemberRole(String guildId, String userId, String roleId);

  Future<void> unsetGuildMemberRole(
      String guildId, String userId, String roleId);

  Future<Pagination<GuildRole>> getGuildRoleList(String guildId,
      {String? next});

  /// Returns an async iterable of all roles in a guild.
  Stream<GuildRole> getGuildRoleIter(String guildId);

  Future<GuildRole> createGuildRole(String guildId,
      {String? name,
      int? color,
      int? position,
      BigInt? permissions,
      bool? hoist,
      bool? mentionable});

  Future<void> updateGuildRole(String guildId, String roleId,
      {String? name,
      int? color,
      int? position,
      BigInt? permissions,
      bool? hoist,
      bool? mentionable});

  Future<void> deleteGuildRole(String guildId, String roleId);

  Future<Pagination<GuildRole>> getGuildMemberRoleList(
      String guildId, String userId,
      {String? next});
}
