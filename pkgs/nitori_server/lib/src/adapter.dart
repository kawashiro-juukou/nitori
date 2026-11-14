/// Adapter surface implemented by platform integrations.
///
/// A [SatoriBot] is one login: it carries the identity headers and the full
/// method surface of the protocol. A [SatoriAdapter] owns the bots and emits
/// the events the server broadcasts over the gateway.
library;

import 'package:nitori_core/nitori_core.dart';

/// Sentinel object for [SatoriBot.internal]; throws on any access.
///
/// Subclasses (e.g. [InMemoryBot]) override [internal] with a real proxy that
/// exposes the bot's internal HTTP endpoints.
class _EmptyInternal {
  @override
  @pragma('vm:prefer-inline')
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('internal not implemented');
}

/// Minimal [SessionHost] backed by a [SatoriBot].
///
/// Provides the identity fields a [Session] needs: platform, selfId, login,
/// and the current sequence number (from the bot's login).
class _BotSessionHost implements SessionHost {
  _BotSessionHost(this._bot);

  final SatoriBot _bot;

  @override
  String get platform => _bot.platform;

  @override
  String get selfId => _bot.userId;

  @override
  Login get login => _bot.login;

  @override
  int get sequence => _bot.login.sn ?? 0;
}

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
        LoginInterface,
        CommandInterface {
  /// Platform name, matched against the `satori-platform` header.
  String get platform;

  /// Bot user id, matched against the `satori-user-id` header.
  String get userId;

  /// Current login snapshot, advertised through READY.
  Login get login;

  @override
  Future<Login> getLogin() async => login;

  /// The set of method keys this bot actually implements.
  ///
  /// Defaults to all 37 standard methods (conservative). Subclasses override
  /// to declare the precise subset they support (e.g. a remote bot returns
  /// only the methods advertised by the upstream gateway).
  Set<String> get supportedMethods => methodKeys.toSet();

  /// The features this bot advertises in READY / META.
  ///
  /// Mirrors the upstream `features` field: the set of method names the bot
  /// can handle. Defaults to [supportedMethods]; override if the advertised
  /// set differs from the implemented set.
  Set<String> get features => supportedMethods;

  /// Creates a [Session] for [event] with this bot as the host.
  ///
  /// The returned session carries the event plus this bot's identity
  /// (platform, selfId, login, sequence) for context-aware handlers.
  Session session(Event event) => Session(event, host: _BotSessionHost(this));

  /// Dispatches [session] through the bot's event pipeline.
  ///
  /// Implements the upstream `dispatch` semantics exactly:
  /// 1. Finds the alias group containing `session.event.type` in
  ///    [eventAliases] (from nitori_core).
  /// 2. If found, replaces `session.event.type` with the canonical (first)
  ///    name of the group.
  /// 3. Emits `internal/session` first (for internal routing).
  /// 4. Then emits each alias member (including the canonical) as a separate
  ///    event.
  ///
  /// NOTE: [SatoriServer._publish] ALREADY performs alias rewriting via
  /// [_applyEventAliases]. The server does NOT call [bot.dispatch] — its
  /// single normalization point is [_publish]. This method exists so that
  /// any external caller invoking [bot.dispatch] behaves identically to
  /// upstream.
  void dispatch(Session session) {
    final event = session.event;
    final aliases = expandEventAliases(event.type);
    if (aliases.length > 1) {
      // Canonical name replaces the emitted type on the wire.
      event.type = aliases.first;
    }
    // Emit internal/session first.
    _emitInternalSession(session);
    // Then emit each alias member.
    for (final alias in aliases) {
      final copy = event.deepCopy()..type = alias;
      _emitEvent(copy);
    }
  }

  /// Hook for subclasses to emit the internal/session event.
  ///
  /// Default does nothing; adapters that need internal routing (e.g. for
  /// middleware) override this.
  void _emitInternalSession(Session session) {}

  /// Hook for subclasses to emit a regular event.
  ///
  /// Default does nothing; adapters override to broadcast to their event
  /// stream.
  void _emitEvent(Event event) {}

  /// Internal HTTP endpoint proxy.
  ///
  /// Returns a sentinel that throws [UnimplementedError] on any access.
  /// Subclasses override with a real proxy that exposes the bot's internal
  /// routes (e.g. via [InternalRouter]).
  dynamic get internal => _EmptyInternal();

  // Channel methods (6)

  /// Returns a channel by id.
  @override
  Future<Channel> getChannel(String id) => throw UnimplementedError();

  /// Returns a paginated list of channels in a guild.
  @override
  Future<Pagination<Channel>> getChannelList(String guildId, {String? next}) =>
      throw UnimplementedError();

  /// Returns an async iterable of all channels in a guild.
  @override
  Stream<Channel> getChannelIter(String guildId) => throw UnimplementedError();

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
  Future<List<Message>> createMessage(
    String channelId,
    String content, {
    dynamic referrer,
    bool? linkPreview,
  }) => throw UnimplementedError();

  /// Sends a message and returns only the message ids.
  ///
  /// Default implementation delegates to [createMessage] and extracts ids.
  @override
  Future<List<String>> sendMessage(
    String channelId,
    String content, {
    dynamic referrer,
    bool? linkPreview,
  }) => throw UnimplementedError();

  /// Returns a message by id.
  @override
  Future<Message> getMessage(String channelId, String messageId) =>
      throw UnimplementedError();

  /// Returns a bidirectional paginated list of messages in a channel.
  @override
  Future<BidiList<Message>> getMessageList(
    String channelId, {
    String? next,
    Direction? direction,
    int? limit,
    Order? order,
  }) => throw UnimplementedError();

  /// Returns an async iterable of all messages in a channel.
  @override
  Stream<Message> getMessageIter(String channelId) =>
      throw UnimplementedError();

  /// Edits a message's content.
  @override
  Future<void> editMessage(
    String channelId,
    String messageId,
    String content,
  ) => throw UnimplementedError();

  /// Deletes a message.
  @override
  Future<void> deleteMessage(String channelId, String messageId) =>
      throw UnimplementedError();

  /// Adds a reaction to a message.
  @override
  Future<void> createReaction(
    String channelId,
    String messageId,
    String emojiId,
  ) => throw UnimplementedError();

  /// Removes a reaction from a message.
  @override
  Future<void> deleteReaction(
    String channelId,
    String messageId,
    String emojiId, {
    String? userId,
  }) => throw UnimplementedError();

  /// Clears all reactions on a message, or all of a specific emoji.
  @override
  Future<void> clearReaction(
    String channelId,
    String messageId, {
    String? emojiId,
  }) => throw UnimplementedError();

  /// Returns a paginated list of users who reacted with an emoji.
  @override
  Future<Pagination<User>> getReactionList(
    String channelId,
    String messageId,
    String emojiId, {
    String? next,
  }) => throw UnimplementedError();

  /// Returns an async iterable of users who reacted with an emoji.
  @override
  Stream<User> getReactionIter(
    String channelId,
    String messageId,
    String emojiId,
  ) => throw UnimplementedError();

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

  /// Returns an async iterable of all guilds the bot is in.
  @override
  Stream<Guild> getGuildIter() => throw UnimplementedError();

  // Guild request method (1)

  /// Handles a guild join request.
  @override
  Future<void> handleGuildRequest(
    String messageId,
    bool approve, {
    String? comment,
  }) => throw UnimplementedError();

  // Guild member methods (6)

  /// Returns a guild member by user id.
  @override
  Future<GuildMember> getGuildMember(String guildId, String userId) =>
      throw UnimplementedError();

  /// Returns a paginated list of guild members.
  @override
  Future<Pagination<GuildMember>> getGuildMemberList(
    String guildId, {
    String? next,
  }) => throw UnimplementedError();

  /// Returns an async iterable of all members in a guild.
  @override
  Stream<GuildMember> getGuildMemberIter(String guildId) =>
      throw UnimplementedError();

  /// Mutes a guild member for an optional duration.
  @override
  Future<void> muteGuildMember(
    String guildId,
    String userId, {
    int? duration,
    String? reason,
  }) => throw UnimplementedError();

  /// Kicks a guild member.
  @override
  Future<void> kickGuildMember(
    String guildId,
    String userId, {
    bool? permanent,
  }) => throw UnimplementedError();

  /// Assigns a role to a guild member.
  @override
  Future<void> setGuildMemberRole(
    String guildId,
    String userId,
    String roleId,
  ) => throw UnimplementedError();

  /// Removes a role from a guild member.
  @override
  Future<void> unsetGuildMemberRole(
    String guildId,
    String userId,
    String roleId,
  ) => throw UnimplementedError();

  /// Returns a paginated list of roles assigned to a guild member.
  @override
  Future<Pagination<GuildRole>> getGuildMemberRoleList(
    String guildId,
    String userId, {
    String? next,
  }) => throw UnimplementedError();

  // Guild member request method (1)

  /// Handles a guild member join request.
  @override
  Future<void> handleGuildMemberRequest(
    String messageId,
    bool approve, {
    String? comment,
  }) => throw UnimplementedError();

  // Guild role methods (4)

  /// Returns a paginated list of guild roles.
  @override
  Future<Pagination<GuildRole>> getGuildRoleList(
    String guildId, {
    String? next,
  }) => throw UnimplementedError();

  /// Returns an async iterable of all roles in a guild.
  @override
  Stream<GuildRole> getGuildRoleIter(String guildId) =>
      throw UnimplementedError();

  /// Creates a guild role with optional properties.
  @override
  Future<GuildRole> createGuildRole(
    String guildId, {
    String? name,
    int? color,
    int? position,
    BigInt? permissions,
    bool? hoist,
    bool? mentionable,
  }) => throw UnimplementedError();

  /// Updates a guild role's properties.
  @override
  Future<void> updateGuildRole(
    String guildId,
    String roleId, {
    String? name,
    int? color,
    int? position,
    BigInt? permissions,
    bool? hoist,
    bool? mentionable,
  }) => throw UnimplementedError();

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
  Future<void> handleFriendRequest(
    String messageId,
    bool approve, {
    String? comment,
  }) => throw UnimplementedError();

  /// Returns an async iterable of all friends.
  @override
  Stream<Friend> getFriendIter() => throw UnimplementedError();

  // Command methods (1)

  /// Updates the bot's slash command list.
  @override
  Future<void> updateCommands(List<Command> commands) =>
      throw UnimplementedError();

  /// Handles a bot-level internal route request.
  ///
  /// Called by the server for paths under `/v1/internal/<platform>/<selfId>/`
  /// that don't match the global routes (/_tmp, /_api). Returns an
  /// [InternalResponse] if the route is handled, or null to fall through to 404.
  Future<InternalResponse?> handleInternalRoute(InternalRequest request) =>
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
