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
  platform: json['platform'] as String?,
  sn: json['sn'] as int?,
  adapter: json['adapter'] as String?,
  features: (json['features'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  hidden: json['hidden'] as bool?,
);

Map<String, dynamic> _$LoginToJson(Login instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('sn', instance.sn);
  writeNotNull('adapter', instance.adapter);
  val['status'] = _$StatusEnumMap[instance.status]!;
  writeNotNull('user', instance.user?.toJson());
  writeNotNull('platform', instance.platform);
  val['features'] = instance.features;
  writeNotNull('hidden', instance.hidden);
  return val;
}

const _$StatusEnumMap = {
  Status.offline: 0,
  Status.online: 1,
  Status.connect: 2,
  Status.disconnect: 3,
  Status.reconnect: 4,
};
