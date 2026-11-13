// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guild_role.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GuildRole _$GuildRoleFromJson(Map<String, dynamic> json) => GuildRole(
  id: json['id'] as String,
  name: json['name'] as String?,
  color: json['color'] as int?,
  position: json['position'] as int?,
  permissions: json['permissions'] == null
      ? null
      : BigInt.parse(json['permissions'] as String),
  hoist: json['hoist'] as bool?,
  mentionable: json['mentionable'] as bool?,
);

Map<String, dynamic> _$GuildRoleToJson(GuildRole instance) {
  final val = <String, dynamic>{'id': instance.id};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('color', instance.color);
  writeNotNull('position', instance.position);
  writeNotNull('permissions', instance.permissions?.toString());
  writeNotNull('hoist', instance.hoist);
  writeNotNull('mentionable', instance.mentionable);
  return val;
}
