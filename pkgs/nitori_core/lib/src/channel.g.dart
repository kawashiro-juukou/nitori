// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Channel _$ChannelFromJson(Map<String, dynamic> json) => Channel(
  id: json['id'] as String,
  type: $enumDecode(_$ChannelTypeEnumMap, json['type']),
  name: json['name'] as String?,
  parentId: json['parent_id'] as String?,
  position: json['position'] as int?,
);

Map<String, dynamic> _$ChannelToJson(Channel instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'type': _$ChannelTypeEnumMap[instance.type]!,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('parent_id', instance.parentId);
  writeNotNull('position', instance.position);
  return val;
}

const _$ChannelTypeEnumMap = {
  ChannelType.text: 0,
  ChannelType.direct: 1,
  ChannelType.category: 2,
  ChannelType.voice: 3,
};
