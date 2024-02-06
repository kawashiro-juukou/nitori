// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guild_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GuildMember _$GuildMemberFromJson(Map<String, dynamic> json) => GuildMember(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      nick: json['nick'] as String?,
      avatar: json['avatar'] as String?,
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.parse(json['joined_at'] as String),
    );

Map<String, dynamic> _$GuildMemberToJson(GuildMember instance) =>
    <String, dynamic>{
      'user': instance.user,
      'nick': instance.nick,
      'avatar': instance.avatar,
      'joined_at': instance.joinedAt?.toIso8601String(),
    };
