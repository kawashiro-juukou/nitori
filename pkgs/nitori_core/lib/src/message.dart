import 'package:json_annotation/json_annotation.dart';

import './base.dart';
import './channel.dart';
import './guild.dart';
import './guild_member.dart';
import './user.dart';

part 'message.g.dart';

@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class Message {
  String? id;
  String? content;
  Channel? channel;
  Guild? guild;
  GuildMember? member;
  User? user;

  /// Millisecond UNIX timestamp of emission, set by the platform.
  int? timestamp;

  /// Quoted message, recursively nested.
  Message? quote;

  /// Structured elements of the message.
  ///
  /// The element models live in `nitori_message`; depending on it here would
  /// invert the package graph, so the field stays untyped on the wire.
  List<dynamic>? elements;

  /// Millisecond UNIX timestamps, as defined by the protocol.
  int? createdAt;
  int? updatedAt;

  Message(
      {this.id,
      this.content,
      this.channel,
      this.guild,
      this.member,
      this.user,
      this.timestamp,
      this.quote,
      this.elements,
      this.createdAt,
      this.updatedAt});

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);
}

abstract interface class MessageInterface {
  Future<List<Message>> createMessage(String channelId, String content,
      {dynamic referrer, bool? linkPreview});

  Future<List<String>> sendMessage(String channelId, String content,
      {dynamic referrer, bool? linkPreview});

  Future<Message> getMessage(String channelId, String messageId);

  Future<BidiList<Message>> getMessageList(String channelId,
      {String? next, Direction? direction, int? limit, Order? order});

  /// Named `editMessage` to match the upstream method of `message.update`.
  Future<void> editMessage(String channelId, String messageId, String content);

  Future<void> deleteMessage(String channelId, String messageId);

  Future<void> createReaction(
      String channelId, String messageId, String emojiId);

  Future<void> deleteReaction(
      String channelId, String messageId, String emojiId,
      {String? userId});

  Future<void> clearReaction(String channelId, String messageId,
      {String? emojiId});

  Future<Pagination<User>> getReactionList(
      String channelId, String messageId, String emojiId,
      {String? next});

  Future<List<String>> createUpload(List<dynamic> blobs);
}
