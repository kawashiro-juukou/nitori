import 'package:json_annotation/json_annotation.dart';

part 'command.g.dart';

/// A command the bot exposes to the platform, as advertised by `updateCommands`.
@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class Command {
  String name;

  /// Human-readable descriptions keyed by locale code.
  Map<String, String> description;

  List<CommandDeclaration> arguments;

  List<CommandDeclaration> options;

  /// Nested sub-commands.
  List<Command> children;

  Command(
      {required this.name,
      Map<String, String>? description,
      List<CommandDeclaration>? arguments,
      List<CommandDeclaration>? options,
      List<Command>? children})
      : description = description ?? const <String, String>{},
        arguments = arguments ?? const <CommandDeclaration>[],
        options = options ?? const <CommandDeclaration>[],
        children = children ?? const <Command>[];

  factory Command.fromJson(Map<String, dynamic> json) =>
      _$CommandFromJson(json);

  Map<String, dynamic> toJson() => _$CommandToJson(this);
}

/// A single argument or option of a [Command].
@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class CommandDeclaration {
  String name;

  /// Type of the value, as accepted by the command registrar.
  String type;

  bool required;

  /// Human-readable descriptions keyed by locale code.
  Map<String, String> description;

  CommandDeclaration(
      {required this.name,
      required this.type,
      required this.required,
      Map<String, String>? description})
      : description = description ?? const <String, String>{};

  factory CommandDeclaration.fromJson(Map<String, dynamic> json) =>
      _$CommandDeclarationFromJson(json);

  Map<String, dynamic> toJson() => _$CommandDeclarationToJson(this);
}

/// Command invocation carried by `interaction/command` events.
@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class Argv {
  /// Name of the invoked command.
  String? name;

  /// Positional arguments of the invocation.
  List<dynamic>? arguments;

  /// Named options of the invocation.
  Map<String, dynamic>? options;

  Argv({this.name, this.arguments, this.options});

  factory Argv.fromJson(Map<String, dynamic> json) => _$ArgvFromJson(json);

  Map<String, dynamic> toJson() => _$ArgvToJson(this);
}

/// Interface for command management (slash commands).
abstract class CommandInterface {
  /// Updates the bot's slash command list.
  Future<void> updateCommands(List<Command> commands);
}
