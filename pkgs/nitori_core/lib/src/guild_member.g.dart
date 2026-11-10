// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guild_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GuildMember _$GuildMemberFromJson(Map<String, dynamic> json) => GuildMember(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      name: json['name'] as String?,
      nick: json['nick'] as String?,
      avatar: json['avatar'] as String?,
      title: json['title'] as String?,
      joinedAt: json['joined_at'] as int?,
      roles: (json['roles'] as List<dynamic>?)
          ?.map((e) => GuildRole.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GuildMemberToJson(GuildMember instance) {
  final val = <String, dynamic>{
    'user': instance.user.toJson(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('nick', instance.nick);
  writeNotNull('avatar', instance.avatar);
  writeNotNull('title', instance.title);
  writeNotNull('joined_at', instance.joinedAt);
  writeNotNull('roles', instance.roles?.map((e) => e.toJson()).toList());
  return val;
}
