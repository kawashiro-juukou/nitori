import 'dart:async';

import 'package:json_annotation/json_annotation.dart';

part 'channel.g.dart';

enum ChannelType {
  text(0),
  voice(1),
  category(2),
  direct(3);

  const ChannelType(this.value);
  final int value;
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Channel {
  /// Channel ID
  String id;

  /// Channel Type
  ChannelType type;

  /// Channel Name
  String name;

  /// Channel Parent ID
  String? parentId;

  Channel(
      {required this.id,
      required this.type,
      required this.name,
      this.parentId});

  factory Channel.fromJson(Map<String, dynamic> json) =>
      _$ChannelFromJson(json);

  /// Instance method to convert the Channel instance to JSON
  Map<String, dynamic> toJson() => _$ChannelToJson(this);
}

abstract interface class ChannelInterface {
  /// Get Channel by ID
  Future<Channel> getChannel(String id);

  /// Get Channels by Guild ID
  Future<List<Channel>> getChannels(String guildId);

  /// Create Channel
  Future<Channel> createChannel(
      String guildId, ChannelType type, String name, String? parentId);

  /// Delete Channel
  Future<void> deleteChannel(String id);
}
