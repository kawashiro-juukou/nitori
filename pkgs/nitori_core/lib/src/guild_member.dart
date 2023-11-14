import './user.dart';

class GuildMember {
  User user;
  String? nick;
  String? avatar;
  DateTime? joinedAt;

  GuildMember(this.user, {this.nick, this.avatar, this.joinedAt});

  factory GuildMember.fromJson(Map<String, dynamic> json) {
    return GuildMember(
      User.fromJson(json['user']),
      nick: json['nick'],
      avatar: json['avatar'],
      joinedAt:
          json['joined_at'] != null ? DateTime.parse(json['joined_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'nick': nick,
      'avatar': avatar,
      'joined_at': joinedAt?.toIso8601String(),
    };
  }
}
