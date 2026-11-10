import 'dart:async';

import 'package:json_annotation/json_annotation.dart';

import './base.dart';

part 'channel.g.dart';

// Wire values are fixed by the protocol: DO NOT reorder (TEXT=0, DIRECT=1,
// CATEGORY=2, VOICE=3) — the old ordering had direct/voice swapped.
@JsonEnum(valueField: 'value')
enum ChannelType {
  text(0),
  direct(1),
  category(2),
  voice(3);

  const ChannelType(this.value);

  final int value;
}

@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class Channel {
  /// Channel ID
  String id;

  /// Channel Type
  ChannelType type;

  /// Channel Name
  String? name;

  /// Channel Parent ID
  String? parentId;

  /// Position inside the parent category
  int? position;

  Channel(
      {required this.id,
      required this.type,
      this.name,
      this.parentId,
      this.position});

  factory Channel.fromJson(Map<String, dynamic> json) =>
      _$ChannelFromJson(json);

  /// Instance method to convert the Channel instance to JSON
  Map<String, dynamic> toJson() => _$ChannelToJson(this);
}

abstract interface class ChannelInterface {
  /// Get Channel by ID
  Future<Channel> getChannel(String id);

  /// Get Channels by Guild ID
  Future<Pagination<Channel>> getChannelList(String guildId, {String? next});

  /// Create Channel
  Future<Channel> createChannel(String guildId, Map<String, dynamic> data);

  Future<void> updateChannel(String channelId, Map<String, dynamic> data);

  /// Delete Channel
  Future<void> deleteChannel(String id);

  /// Create a direct channel with a user
  Future<Channel> createDirectChannel(String userId, {String? guildId});

  /// Mute or unmute a channel
  Future<void> muteChannel(String channelId, {String? guildId, bool? enable});
}
