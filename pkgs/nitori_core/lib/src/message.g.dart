// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['id'] as String?,
  content: json['content'] as String?,
  channel: json['channel'] == null
      ? null
      : Channel.fromJson(json['channel'] as Map<String, dynamic>),
  guild: json['guild'] == null
      ? null
      : Guild.fromJson(json['guild'] as Map<String, dynamic>),
  member: json['member'] == null
      ? null
      : GuildMember.fromJson(json['member'] as Map<String, dynamic>),
  user: json['user'] == null
      ? null
      : User.fromJson(json['user'] as Map<String, dynamic>),
  timestamp: json['timestamp'] as int?,
  quote: json['quote'] == null
      ? null
      : Message.fromJson(json['quote'] as Map<String, dynamic>),
  elements: (json['elements'] as List<dynamic>?)
      ?.map((e) => e as Map<String, dynamic>)
      .toList(),
  createdAt: json['created_at'] as int?,
  updatedAt: json['updated_at'] as int?,
);

Map<String, dynamic> _$MessageToJson(Message instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('id', instance.id);
  writeNotNull('content', instance.content);
  writeNotNull('channel', instance.channel?.toJson());
  writeNotNull('guild', instance.guild?.toJson());
  writeNotNull('member', instance.member?.toJson());
  writeNotNull('user', instance.user?.toJson());
  writeNotNull('timestamp', instance.timestamp);
  writeNotNull('quote', instance.quote?.toJson());
  writeNotNull('elements', instance.elements);
  writeNotNull('created_at', instance.createdAt);
  writeNotNull('updated_at', instance.updatedAt);
  return val;
}
