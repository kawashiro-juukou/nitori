// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guild.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Guild _$GuildFromJson(Map<String, dynamic> json) => Guild(
  id: json['id'] as String,
  name: json['name'] as String?,
  avatar: json['avatar'] as String?,
);

Map<String, dynamic> _$GuildToJson(Guild instance) {
  final val = <String, dynamic>{'id': instance.id};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('avatar', instance.avatar);
  return val;
}
