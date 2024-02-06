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

Map<String, dynamic> _$GuildToJson(Guild instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar': instance.avatar,
    };
