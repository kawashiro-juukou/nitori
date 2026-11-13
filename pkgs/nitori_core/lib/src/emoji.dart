import 'package:json_annotation/json_annotation.dart';

part 'emoji.g.dart';

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class Emoji {
  String id;
  String? name;

  Emoji({required this.id, this.name});

  factory Emoji.fromJson(Map<String, dynamic> json) => _$EmojiFromJson(json);

  Map<String, dynamic> toJson() => _$EmojiToJson(this);
}
