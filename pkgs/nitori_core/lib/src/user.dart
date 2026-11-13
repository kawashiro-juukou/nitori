import 'package:json_annotation/json_annotation.dart';

import './base.dart';
import './friend.dart';

part 'user.g.dart';

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class User {
  String id;
  String? name;
  String? nick;
  String? avatar;

  /// Legacy discriminator, only present on platforms that still mint them.
  String? discriminator;
  bool? isBot;

  User({
    required this.id,
    this.name,
    this.nick,
    this.avatar,
    this.discriminator,
    this.isBot,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}

abstract class UserInterface {
  Future<User> getUser(String userId);

  Future<Pagination<Friend>> getFriendList({String? next});

  /// Returns an async iterable of all friends.
  Stream<Friend> getFriendIter();

  Future<void> deleteFriend(String userId);
}
