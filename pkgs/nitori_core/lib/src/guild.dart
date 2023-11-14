import './base.dart';

class Guild {
  String id;
  String? name;
  String? avatar;

  Guild(this.id, {this.name, this.avatar});

  factory Guild.fromJson(Map<String, dynamic> json) {
    return Guild(
      json['id'],
      name: json['name'],
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
    };
  }
}

abstract interface class GuildInterface {
  Future<Guild> getGuild(String id);
  Future<Pagination<Guild>> getGuildList(String? next);
  Future handleGuildApprove(String messageId, bool approve, String comment);
}
