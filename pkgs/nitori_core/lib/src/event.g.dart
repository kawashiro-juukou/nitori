// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
  type: json['type'] as String,
  sn: json['sn'] as int?,
  login: json['login'] == null
      ? null
      : Login.fromJson(json['login'] as Map<String, dynamic>),
  selfId: json['self_id'] as String?,
  platform: json['platform'] as String?,
  timestamp: json['timestamp'] as int?,
  argv: json['argv'] == null
      ? null
      : Argv.fromJson(json['argv'] as Map<String, dynamic>),
  channel: json['channel'] == null
      ? null
      : Channel.fromJson(json['channel'] as Map<String, dynamic>),
  guild: json['guild'] == null
      ? null
      : Guild.fromJson(json['guild'] as Map<String, dynamic>),
  friend: json['friend'] == null
      ? null
      : Friend.fromJson(json['friend'] as Map<String, dynamic>),
  member: json['member'] == null
      ? null
      : GuildMember.fromJson(json['member'] as Map<String, dynamic>),
  message: json['message'] == null
      ? null
      : Message.fromJson(json['message'] as Map<String, dynamic>),
  operator: json['operator'] == null
      ? null
      : User.fromJson(json['operator'] as Map<String, dynamic>),
  emoji: json['emoji'] == null
      ? null
      : Emoji.fromJson(json['emoji'] as Map<String, dynamic>),
  role: json['role'] == null
      ? null
      : GuildRole.fromJson(json['role'] as Map<String, dynamic>),
  user: json['user'] == null
      ? null
      : User.fromJson(json['user'] as Map<String, dynamic>),
  button: json['button'] == null
      ? null
      : Button.fromJson(json['button'] as Map<String, dynamic>),
  referrer: json['referrer'],
  eventType: json['_type'] as String?,
  eventData: json['_data'],
);

Map<String, dynamic> _$EventToJson(Event instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('sn', instance.sn);
  val['type'] = instance.type;
  writeNotNull('login', instance.login?.toJson());
  writeNotNull('self_id', instance.selfId);
  writeNotNull('platform', instance.platform);
  writeNotNull('timestamp', instance.timestamp);
  writeNotNull('argv', instance.argv?.toJson());
  writeNotNull('channel', instance.channel?.toJson());
  writeNotNull('guild', instance.guild?.toJson());
  writeNotNull('friend', instance.friend?.toJson());
  writeNotNull('member', instance.member?.toJson());
  writeNotNull('message', instance.message?.toJson());
  writeNotNull('operator', instance.operator?.toJson());
  writeNotNull('emoji', instance.emoji?.toJson());
  writeNotNull('role', instance.role?.toJson());
  writeNotNull('user', instance.user?.toJson());
  writeNotNull('button', instance.button?.toJson());
  writeNotNull('referrer', instance.referrer);
  writeNotNull('_type', instance.eventType);
  writeNotNull('_data', instance.eventData);
  return val;
}

Meta _$MetaFromJson(Map<String, dynamic> json) => Meta(
  logins: (json['logins'] as List<dynamic>?)
      ?.map((e) => Login.fromJson(e as Map<String, dynamic>))
      .toList(),
  proxyUrls: (json['proxy_urls'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$MetaToJson(Meta instance) => <String, dynamic>{
  'logins': instance.logins.map((e) => e.toJson()).toList(),
  'proxy_urls': instance.proxyUrls,
};
