// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Command _$CommandFromJson(Map<String, dynamic> json) => Command(
      name: json['name'] as String,
      description: (json['description'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      arguments: (json['arguments'] as List<dynamic>?)
          ?.map((e) => CommandDeclaration.fromJson(e as Map<String, dynamic>))
          .toList(),
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => CommandDeclaration.fromJson(e as Map<String, dynamic>))
          .toList(),
      children: (json['children'] as List<dynamic>?)
          ?.map((e) => Command.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CommandToJson(Command instance) => <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'arguments': instance.arguments.map((e) => e.toJson()).toList(),
      'options': instance.options.map((e) => e.toJson()).toList(),
      'children': instance.children.map((e) => e.toJson()).toList(),
    };

CommandDeclaration _$CommandDeclarationFromJson(Map<String, dynamic> json) =>
    CommandDeclaration(
      name: json['name'] as String,
      type: json['type'] as String,
      required: json['required'] as bool,
      description: (json['description'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$CommandDeclarationToJson(CommandDeclaration instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'required': instance.required,
      'description': instance.description,
    };

Argv _$ArgvFromJson(Map<String, dynamic> json) => Argv(
      name: json['name'] as String?,
      arguments: json['arguments'] as List<dynamic>?,
      options: json['options'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ArgvToJson(Argv instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('arguments', instance.arguments);
  writeNotNull('options', instance.options);
  return val;
}
