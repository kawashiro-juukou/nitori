import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:nitori_core/nitori_core.dart';

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

  /// Static method to create a Channel instance from JSON
  static Channel fromJson(Map<String, dynamic> json) {
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

class ChannelController extends BaseController<ChannelInterface> {
  ChannelController(ChannelInterface _interface) : super(_interface);

  @override
  Future<void> handlePost(HttpRequest request) async {
    final body = await request
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(json.decoder)
        .single as Map<String, dynamic>;

    final channel = Channel.fromJson(body);

    request.response
      ..statusCode = HttpStatus.ok
      ..write(json.encode(channel.toJson()));
  }
}
