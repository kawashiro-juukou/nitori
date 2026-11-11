import 'package:json_annotation/json_annotation.dart';

import './button.dart';
import './channel.dart';
import './command.dart';
import './emoji.dart';
import './friend.dart';
import './guild.dart';
import './guild_member.dart';
import './guild_role.dart';
import './login.dart';
import './message.dart';
import './user.dart';

part 'event.g.dart';

/// The complete set of event names the protocol can emit, exactly as they
/// appear on the wire.
///
/// [Event.type] stays a plain [String] because adapters may mint names outside
/// this registry; this enum is the canonical built-in set.
enum EventName {
  friendAdded('friend-added'),
  friendDeleted('friend-deleted'),
  friendUpdated('friend-updated'),
  channelAdded('channel-added'),
  channelDeleted('channel-deleted'),
  channelUpdated('channel-updated'),
  guildAdded('guild-added'),
  guildDeleted('guild-deleted'),
  guildUpdated('guild-updated'),
  guildMemberAdded('guild-member-added'),
  guildMemberDeleted('guild-member-deleted'),
  guildMemberUpdated('guild-member-updated'),
  guildRoleAdded('guild-role-added'),
  guildRoleDeleted('guild-role-deleted'),
  guildRoleUpdated('guild-role-updated'),
  guildFileAdded('guild-file-added'),
  guildFileDeleted('guild-file-deleted'),
  guildFileUpdated('guild-file-updated'),
  guildEmojiAdded('guild-emoji-added'),
  guildEmojiDeleted('guild-emoji-deleted'),
  guildEmojiUpdated('guild-emoji-updated'),
  message('message'),
  messageDeleted('message-deleted'),
  messageUpdated('message-updated'),
  messagePinned('message-pinned'),
  messageUnpinned('message-unpinned'),
  interactionCommand('interaction/command'),
  reactionAdded('reaction-added'),
  reactionDeleted('reaction-deleted'),
  reactionDeletedOne('reaction-deleted/one'),
  reactionDeletedAll('reaction-deleted/all'),
  reactionDeletedEmoji('reaction-deleted/emoji'),
  send('send'),
  friendRequest('friend-request'),
  guildRequest('guild-request'),
  guildMemberRequest('guild-member-request');

  const EventName(this.value);

  final String value;

  /// Resolves a wire name back to its enum value.
  static EventName from(String value) {
    for (final name in values) {
      if (name.value == value) return name;
    }
    throw ArgumentError.value(value, 'value', 'unknown event name');
  }
}

/// Event-name groups that adapters emit under two spellings.
///
/// Mirrors the upstream `eventAliases` table: dispatching under any member of a
/// group also fires the rest, with the canonical (first) name replacing the
/// [`Event.type`] that gets dispatched.
const List<List<String>> eventAliases = <List<String>>[
  ['message-created', 'message'],
  ['guild-removed', 'guild-deleted'],
  ['guild-member-removed', 'guild-member-deleted'],
];

/// Every event name [type] should be dispatched under.
List<String> expandEventAliases(String type) {
  for (final aliases in eventAliases) {
    if (aliases.contains(type)) return aliases;
  }
  return <String>[type];
}

@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class Event {
  /// Sequence number assigned by the server.
  int? sn;

  /// Event name; see [EventName] for the built-in set.
  String type;

  Login? login;
  String? selfId;
  String? platform;

  /// Millisecond UNIX timestamp of emission.
  int? timestamp;

  Argv? argv;
  Channel? channel;
  Guild? guild;
  Friend? friend;
  GuildMember? member;
  Message? message;

  /// The user that performed the action.
  User? operator;

  Emoji? emoji;
  GuildRole? role;
  User? user;
  Button? button;

  /// Platform object the adapter forwards verbatim; never renamed on the wire.
  dynamic referrer;

  /// Adapter-local event discriminator.
  @JsonKey(name: '_type')
  String? eventType;

  /// Adapter-local payload.
  @JsonKey(name: '_data')
  dynamic eventData;

  Event(
      {required this.type,
      this.sn,
      this.login,
      this.selfId,
      this.platform,
      this.timestamp,
      this.argv,
      this.channel,
      this.guild,
      this.friend,
      this.member,
      this.message,
      this.operator,
      this.emoji,
      this.role,
      this.user,
      this.button,
      this.referrer,
      this.eventType,
      this.eventData});

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);

  /// Creates a deep copy by JSON round-trip, ensuring all nested objects are isolated.
  Event deepCopy() => Event.fromJson(toJson());
}

/// Server metadata pushed with the `meta` opcode: the login registry and the
/// upload proxy endpoints.
@JsonSerializable(
    fieldRename: FieldRename.snake, explicitToJson: true, includeIfNull: false)
class Meta {
  List<Login> logins;

  /// URL prefixes served by the file upload provider.
  List<String> proxyUrls;

  Meta({List<Login>? logins, List<String>? proxyUrls})
      : logins = logins ?? <Login>[],
        proxyUrls = proxyUrls ?? <String>[];

  factory Meta.fromJson(Map<String, dynamic> json) => _$MetaFromJson(json);

  Map<String, dynamic> toJson() => _$MetaToJson(this);
}
