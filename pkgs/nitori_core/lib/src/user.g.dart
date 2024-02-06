// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      name: json['name'] as String?,
      nick: json['nick'] as String?,
      avatar: json['avatar'] as String?,
      isBot: json['is_bot'] as bool?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nick': instance.nick,
      'avatar': instance.avatar,
      'is_bot': instance.isBot,
    };
