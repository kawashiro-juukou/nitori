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

  @override
  Future<Channel> getChannel(String id) => throw UnimplementedError();

  @override
  Future<Pagination<Channel>> getChannelList(String guildId, {String? next}) =>
      throw UnimplementedError();

  @override
  Future<Channel> createChannel(String guildId, Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<void> updateChannel(String channelId, Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<void> deleteChannel(String id) => throw UnimplementedError();

  @override
  Future<Channel> createDirectChannel(String userId, {String? guildId}) =>
      throw UnimplementedError();

  @override
  Future<void> muteChannel(String channelId, {String? guildId, bool? enable}) =>
      throw UnimplementedError();

  @override
  Future<List<Message>> createMessage(String channelId, String content,
          {dynamic referrer, bool? linkPreview}) =>
      throw UnimplementedError();

  @override
  Future<List<String>> sendMessage(String channelId, String content,
          {dynamic referrer, bool? linkPreview}) =>
      throw UnimplementedError();

  @override
  Future<Message> getMessage(String channelId, String messageId) =>
      throw UnimplementedError();

  @override
  Future<BidiList<Message>> getMessageList(String channelId,
          {String? next, Direction? direction, int? limit, Order? order}) =>
      throw UnimplementedError();

  @override
  Future<void> editMessage(
          String channelId, String messageId, String content) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessage(String channelId, String messageId) =>
      throw UnimplementedError();

  @override
  Future<void> createReaction(
          String channelId, String messageId, String emojiId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteReaction(
          String channelId, String messageId, String emojiId,
          {String? userId}) =>
      throw UnimplementedError();

  @override
  Future<void> clearReaction(String channelId, String messageId,
          {String? emojiId}) =>
      throw UnimplementedError();

  @override
  Future<Pagination<User>> getReactionList(
          String channelId, String messageId, String emojiId,
          {String? next}) =>
      throw UnimplementedError();

  @override
  Future<List<String>> createUpload(List<dynamic> blobs) =>
      throw UnimplementedError();

  @override
  Future<Guild> getGuild(String id) => throw UnimplementedError();

  @override
  Future<Pagination<Guild>> getGuildList({String? next}) =>
      throw UnimplementedError();

  @override
  Future<void> handleGuildRequest(String messageId, bool approve,
          {String? comment}) =>
      throw UnimplementedError();

  @override
  Future<void> handleGuildMemberRequest(String messageId, bool approve,
          {String? comment}) =>
      throw UnimplementedError();

  @override
  Future<GuildMember> getGuildMember(String guildId, String userId) =>
      throw UnimplementedError();

  @override
  Future<Pagination<GuildMember>> getGuildMemberList(String guildId,
          {String? next}) =>
      throw UnimplementedError();

  @override
  Future<void> muteGuildMember(String guildId, String userId,
          {int? duration, String? reason}) =>
      throw UnimplementedError();

  @override
  Future<void> kickGuildMember(String guildId, String userId,
          {bool? permanent}) =>
      throw UnimplementedError();

  @override
  Future<void> setGuildMemberRole(
          String guildId, String userId, String roleId) =>
      throw UnimplementedError();

  @override
  Future<void> unsetGuildMemberRole(
          String guildId, String userId, String roleId) =>
      throw UnimplementedError();

  @override
  Future<Pagination<GuildRole>> getGuildMemberRoleList(
          String guildId, String userId,
          {String? next}) =>
      throw UnimplementedError();

  @override
  Future<Pagination<GuildRole>> getGuildRoleList(String guildId,
          {String? next}) =>
      throw UnimplementedError();

  @override
  Future<GuildRole> createGuildRole(String guildId,
          {String? name,
          int? color,
          int? position,
          BigInt? permissions,
          bool? hoist,
          bool? mentionable}) =>
      throw UnimplementedError();

  @override
  Future<void> updateGuildRole(String guildId, String roleId,
          {String? name,
          int? color,
          int? position,
          BigInt? permissions,
          bool? hoist,
          bool? mentionable}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteGuildRole(String guildId, String roleId) =>
      throw UnimplementedError();

  @override
  Future<User> getUser(String userId) => throw UnimplementedError();

  @override
  Future<Pagination<Friend>> getFriendList({String? next}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteFriend(String userId) => throw UnimplementedError();

  Future<void> handleFriendRequest(String messageId, bool approve,
          {String? comment}) =>
      throw UnimplementedError();
}

/// Owns the bots of one platform integration and the event stream they emit.
abstract class SatoriAdapter {
  /// Logins served by this adapter.
  List<SatoriBot> get bots;

  /// Events emitted by any of the bots, already carrying login identity.
  Stream<Event> get events;

  /// Upload proxy URL prefixes advertised in META and READY.
  List<String> get proxyUrls => const <String>[];
}
