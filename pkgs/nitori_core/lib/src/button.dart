import 'package:json_annotation/json_annotation.dart';

part 'button.g.dart';

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class Button {
  String id;

  Button({required this.id});

  factory Button.fromJson(Map<String, dynamic> json) => _$ButtonFromJson(json);

  Map<String, dynamic> toJson() => _$ButtonToJson(this);
}
