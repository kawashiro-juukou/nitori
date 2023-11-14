import 'dart:async';

enum ChannelType {
  TEXT(0),
  VOICE(1),
  CATEGORY(2),
  DIRECT(3);

  const ChannelType(this.value);
  final int value;
}

class Channel {
  /// Channel ID
  String id;

  /// Channel Type
  ChannelType type;

  /// Channel Name
  String name;

  /// Channel Parent ID
  String? parentId;

  Channel(this.id, this.type, this.name, this.parentId);

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      json['id'],
      ChannelType.values[json['type']],
      json['name'],
      json['parentId'],
    );
  }

  /// Instance method to convert the Channel instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'parentId': parentId,
    };
  }
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