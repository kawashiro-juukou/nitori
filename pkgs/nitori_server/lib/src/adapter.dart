/// Adapter surface implemented by platform integrations.
///
/// A [SatoriBot] is one login: it carries the identity headers and the full
/// method surface of the protocol. A [SatoriAdapter] owns the bots and emits
/// the events the server broadcasts over the gateway.
library;

import 'package:nitori_core/nitori_core.dart';

/// One login served through the HTTP API and the WebSocket gateway.
///
/// Methods default to throwing [UnimplementedError]; an integration only
/// overrides the capabilities its platform supports.
///
/// The 37 standard methods cover channels, messages, reactions, guilds,
/// guild members, guild roles, users, logins, friends, and uploads.
/// Each method maps directly to a Satori HTTP endpoint.
abstract class SatoriBot
    implements
        ChannelInterface,
        MessageInterface,
        GuildInterface,
        GuildMemberInterface,
        GuildRoleInterface,
        UserInterface,
        LoginInterface {
  /// Platform name, matched against the `satori-platform` header.
  String get platform;

  /// Bot user id, matched against the `satori-user-id` header.
  String get userId;

  /// Current login snapshot, advertised through READY.
  Login get login;

  @override
  Future<Login> getLogin() async => login;

  // Channel methods (6)

  /// Returns a channel by id.
  @override
  Future<Channel> getChannel(String id) => throw UnimplementedError();

  /// Returns a paginated list of channels in a guild.
  @override
  Future<Pagination<Channel>> getChannelList(String guildId, {String? next}) =>
      throw UnimplementedError();

  /// Creates a channel in a guild with [data].
  @override
  Future<Channel> createChannel(String guildId, Map<String, dynamic> data) =>
      throw UnimplementedError();

  /// Updates a channel with [data].
  @override
  Future<void> updateChannel(String channelId, Map<String, dynamic> data) =>
      throw UnimplementedError();

  /// Deletes a channel.
  @override
  Future<void> deleteChannel(String id) => throw UnimplementedError();

  /// Creates a direct message channel with a user.
  @override
  Future<Channel> createDirectChannel(String userId, {String? guildId}) =>
      throw UnimplementedError();

  /// Mutes or unmutes a channel for the bot.
  @override
  Future<void> muteChannel(String channelId, {String? guildId, bool? enable}) =>
      throw UnimplementedError();

  // Message methods (8)

  /// Creates one or more messages in a channel.
  ///
  /// Returns the created messages. Implementations may split long content
  /// into multiple messages.
  @override
  Future<List<Message>> createMessage(String channelId, String content,
          {dynamic referrer, bool? linkPreview}) =>
      throw UnimplementedError();

  /// Sends a message and returns only the message ids.
  ///
  /// Default implementation delegates to [createMessage] and extracts ids.
  @override
  Future<List<String>> sendMessage(String channelId, String content,
          {dynamic referrer, bool? linkPreview}) =>
      throw UnimplementedError();

  /// Returns a message by id.
  @override
  Future<Message> getMessage(String channelId, String messageId) =>
      throw UnimplementedError();

  /// Returns a bidirectional paginated list of messages in a channel.
  @override
  Future<BidiList<Message>> getMessageList(String channelId,
          {String? next, Direction? direction, int? limit, Order? order}) =>
      throw UnimplementedError();

  /// Edits a message's content.
  @override
  Future<void> editMessage(
          String channelId, String messageId, String content) =>
      throw UnimplementedError();

  /// Deletes a message.
  @override
  Future<void> deleteMessage(String channelId, String messageId) =>
      throw UnimplementedError();

  /// Adds a reaction to a message.
  @override
  Future<void> createReaction(
          String channelId, String messageId, String emojiId) =>
      throw UnimplementedError();

  /// Removes a reaction from a message.
  @override
  Future<void> deleteReaction(
          String channelId, String messageId, String emojiId,
          {String? userId}) =>
      throw UnimplementedError();

  /// Clears all reactions on a message, or all of a specific emoji.
  @override
  Future<void> clearReaction(String channelId, String messageId,
          {String? emojiId}) =>
      throw UnimplementedError();

  /// Returns a paginated list of users who reacted with an emoji.
  @override
  Future<Pagination<User>> getReactionList(
          String channelId, String messageId, String emojiId,
          {String? next}) =>
      throw UnimplementedError();

  // Upload method (1)

  /// Uploads blobs and returns their proxy URLs.
  @override
  Future<List<String>> createUpload(List<dynamic> blobs) =>
      throw UnimplementedError();

  // Guild methods (2)

  /// Returns a guild by id.
  @override
  Future<Guild> getGuild(String id) => throw UnimplementedError();

  /// Returns a paginated list of guilds the bot is in.
  @override
  Future<Pagination<Guild>> getGuildList({String? next}) =>
      throw UnimplementedError();

  // Guild request method (1)

  /// Handles a guild join request.
  @override
  Future<void> handleGuildRequest(String messageId, bool approve,
          {String? comment}) =>
      throw UnimplementedError();

  // Guild member methods (6)

  /// Returns a guild member by user id.
  @override
  Future<GuildMember> getGuildMember(String guildId, String userId) =>
      throw UnimplementedError();

  /// Returns a paginated list of guild members.
  @override
  Future<Pagination<GuildMember>> getGuildMemberList(String guildId,
          {String? next}) =>
      throw UnimplementedError();

  /// Mutes a guild member for an optional duration.
  @override
  Future<void> muteGuildMember(String guildId, String userId,
          {int? duration, String? reason}) =>
      throw UnimplementedError();

  /// Kicks a guild member.
  @override
  Future<void> kickGuildMember(String guildId, String userId,
          {bool? permanent}) =>
      throw UnimplementedError();

  /// Assigns a role to a guild member.
  @override
  Future<void> setGuildMemberRole(
          String guildId, String userId, String roleId) =>
      throw UnimplementedError();

  /// Removes a role from a guild member.
  @override
  Future<void> unsetGuildMemberRole(
          String guildId, String userId, String roleId) =>
      throw UnimplementedError();

  /// Returns a paginated list of roles assigned to a guild member.
  @override
  Future<Pagination<GuildRole>> getGuildMemberRoleList(
          String guildId, String userId,
          {String? next}) =>
      throw UnimplementedError();

  // Guild member request method (1)

  /// Handles a guild member join request.
  @override
  Future<void> handleGuildMemberRequest(String messageId, bool approve,
          {String? comment}) =>
      throw UnimplementedError();

  // Guild role methods (4)

  /// Returns a paginated list of guild roles.
  @override
  Future<Pagination<GuildRole>> getGuildRoleList(String guildId,
          {String? next}) =>
      throw UnimplementedError();

  /// Creates a guild role with optional properties.
  @override
  Future<GuildRole> createGuildRole(String guildId,
          {String? name,
          int? color,
          int? position,
          BigInt? permissions,
          bool? hoist,
          bool? mentionable}) =>
      throw UnimplementedError();

  /// Updates a guild role's properties.
  @override
  Future<void> updateGuildRole(String guildId, String roleId,
          {String? name,
          int? color,
          int? position,
          BigInt? permissions,
          bool? hoist,
          bool? mentionable}) =>
      throw UnimplementedError();

  /// Deletes a guild role.
  @override
  Future<void> deleteGuildRole(String guildId, String roleId) =>
      throw UnimplementedError();

  // User method (1)

  /// Returns a user by id.
  @override
  Future<User> getUser(String userId) => throw UnimplementedError();

  // Friend methods (3)

  /// Returns a paginated list of the bot's friends.
  @override
  Future<Pagination<Friend>> getFriendList({String? next}) =>
      throw UnimplementedError();

  /// Deletes a friend.
  @override
  Future<void> deleteFriend(String userId) => throw UnimplementedError();

  /// Handles a friend request.
  Future<void> handleFriendRequest(String messageId, bool approve,
          {String? comment}) =>
      throw UnimplementedError();
}

/// Owns the bots of one platform integration and the event stream they emit.
abstract class SatoriAdapter {
  /// Logins served by this adapter.
  ///
  /// Each bot represents one authenticated session. The server matches
  /// incoming requests against `platform` and `userId` to select the bot.
  List<SatoriBot> get bots;

  /// Events emitted by any of the bots, already carrying login identity.
  ///
  /// The server buffers these for replay, assigns monotonically increasing
  /// sequence numbers (`sn`), and broadcasts to all authorized gateway
  /// clients. Login events (`login-added`, `login-updated`, `login-removed`)
  /// are filtered from replay but still broadcast live.
  Stream<Event> get events;

  /// Upload proxy URL prefixes advertised in META and READY.
  ///
  /// Clients use these to construct upload URLs. Defaults to an empty list.
  List<String> get proxyUrls => const <String>[];
}
