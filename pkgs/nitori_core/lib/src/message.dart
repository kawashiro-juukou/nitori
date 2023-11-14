import './base.dart';
import './channel.dart';
import './guild.dart';
import './guild_member.dart';
import './user.dart';

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

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      json['id'],
      json['content'],
      channel:
          json['channel'] != null ? Channel.fromJson(json['channel']) : null,
      guild: json['guild'] != null ? Guild.fromJson(json['guild']) : null,
      member:
          json['member'] != null ? GuildMember.fromJson(json['member']) : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'channel': channel?.toJson(),
      'guild': guild?.toJson(),
      'member': member?.toJson(),
      'user': user?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

abstract class MessageInterface {
  Future<List<Message>> createMessage(String channelId, String content);
  Future<Message> getMessage(String channelId, String messageId);
  Future deleteMessage(String channelId, String messageId);
  Future updateMessage(String channelId, String messageId, Message message);
  Future<Pagination<Message>> getChannelMessages(
      String channelId, String? next);
}
