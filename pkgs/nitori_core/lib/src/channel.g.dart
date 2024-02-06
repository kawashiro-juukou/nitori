// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Channel _$ChannelFromJson(Map<String, dynamic> json) => Channel(
      id: json['id'] as String,
      type: $enumDecode(_$ChannelTypeEnumMap, json['type']),
      name: json['name'] as String,
      parentId: json['parent_id'] as String?,
    );

Map<String, dynamic> _$ChannelToJson(Channel instance) => <String, dynamic>{
      'id': instance.id,
      'type': _$ChannelTypeEnumMap[instance.type]!,
      'name': instance.name,
      'parent_id': instance.parentId,
    };

const _$ChannelTypeEnumMap = {
  ChannelType.text: 'text',
  ChannelType.voice: 'voice',
  ChannelType.category: 'category',
  ChannelType.direct: 'direct',
};
