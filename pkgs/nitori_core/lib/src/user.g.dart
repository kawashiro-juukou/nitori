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
  discriminator: json['discriminator'] as String?,
  isBot: json['is_bot'] as bool?,
);

Map<String, dynamic> _$UserToJson(User instance) {
  final val = <String, dynamic>{'id': instance.id};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('nick', instance.nick);
  writeNotNull('avatar', instance.avatar);
  writeNotNull('discriminator', instance.discriminator);
  writeNotNull('is_bot', instance.isBot);
  return val;
}
