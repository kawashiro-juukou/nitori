import 'package:json_annotation/json_annotation.dart';

import './base.dart';
import './channel.dart';
import './guild.dart';
import './guild_member.dart';
import './user.dart';

part 'message.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Message {
  String id;
  String content;
  Channel? channel;
  Guild? guild;
  GuildMember? member;
  User? user;
  DateTime? createdAt;
  DateTime? updatedAt;

  Message(this.id, this.content,
      {this.channel,
      this.guild,
      this.member,
      this.user,
      this.createdAt,
      this.updatedAt});

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);
}

abstract class MessageInterface {
  Future<List<Message>> createMessage(String channelId, String content);
  Future<Message> getMessage(String channelId, String messageId);
  Future deleteMessage(String channelId, String messageId);
  Future updateMessage(String channelId, String messageId, Message message);
  Future<Pagination<Message>> getChannelMessages(
      String channelId, String? next);
}
