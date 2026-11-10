import './base.dart';

import 'package:json_annotation/json_annotation.dart';

part 'guild.g.dart';

@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class Guild {
  String id;
  String? name;
  String? avatar;

  Guild({required this.id, this.name, this.avatar});

  factory Guild.fromJson(Map<String, dynamic> json) => _$GuildFromJson(json);

  Map<String, dynamic> toJson() => _$GuildToJson(this);
}

abstract interface class GuildInterface {
  Future<Guild> getGuild(String id);

  Future<Pagination<Guild>> getGuildList({String? next});

  Future<void> handleGuildRequest(String messageId, bool approve,
      {String? comment});

  Future<void> handleGuildMemberRequest(String messageId, bool approve,
      {String? comment});
}
