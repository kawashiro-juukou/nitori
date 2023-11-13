class User {
  String id;
  String? name;
  String? nick;
  String? avatar;
  bool? isBot;

  User(this.id, {this.name, this.nick, this.avatar, this.isBot});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      json['id'],
      name: json['name'],
      nick: json['nick'],
      avatar: json['avatar'],
      isBot: json['is_bot'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nick': nick,
      'avatar': avatar,
      'is_bot': isBot,
    };
  }
}
