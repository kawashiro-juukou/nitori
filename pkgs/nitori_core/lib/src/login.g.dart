// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Login _$LoginFromJson(Map<String, dynamic> json) => Login(
      status: $enumDecode(_$StatusEnumMap, json['status']),
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
      selfId: json['self_id'] as String?,
      platform: json['platform'] as String?,
    );

Map<String, dynamic> _$LoginToJson(Login instance) => <String, dynamic>{
      'status': _$StatusEnumMap[instance.status]!,
      'user': instance.user,
      'self_id': instance.selfId,
      'platform': instance.platform,
    };

const _$StatusEnumMap = {
  Status.offline: 'offline',
  Status.online: 'online',
  Status.connect: 'connect',
  Status.disconnect: 'disconnect',
  Status.reconnect: 'reconnect',
};
