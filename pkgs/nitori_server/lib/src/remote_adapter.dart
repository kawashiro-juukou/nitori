/// Remote Satori protocol bridge: connects to an upstream Satori server and
/// maps its logins/events into local [SatoriAdapter]/[SatoriBot] objects.
///
/// This adapter implements the "dual-hop" pattern: a local SatoriServer fronts
/// a RemoteSatoriAdapter that connects to a remote Satori server (running
/// upstream Node adapters like telegram/discord). The remote server's
/// logins/events are mirrored locally with fresh sequence numbers.
library;

import 'dart:async';
import 'dart:collection';

import 'package:nitori_client/nitori_client.dart';
import 'package:nitori_core/nitori_core.dart';

import 'server.dart';

/// A [SatoriBot] backed by a remote [NitoriBot].
///
/// Delegates all 37 standard methods to the remote bot via HTTP, and exposes
/// an internal proxy (`bot.internal.*`) that forwards to the remote
/// `/v1/internal/_api/*` endpoints.
class RemoteSatoriBot implements SatoriBot {
  /// The adapter that owns this bot.
  final RemoteSatoriAdapter adapter;

  /// The underlying remote bot we delegate to.
  final NitoriBot _remoteBot;

  /// Current login snapshot, updated on `login-updated`.
  Login _login;

  /// Internal router for bot-level routes under `/v1/internal/<platform>/<selfId>/...`.
  final InternalRouter<RemoteSatoriBot> _internalRouter =
      InternalRouter<RemoteSatoriBot>();

  /// Dynamic proxy object for `bot.internal.*` calls.
  late final _RemoteInternalProxy _internalProxy = _RemoteInternalProxy(this);

  RemoteSatoriBot(this.adapter, this._remoteBot) : _login = _remoteBot.login! {
    // Define the internal proxy route: bot.internal.* -> POST remote /v1/internal/_api/*
    _internalRouter.define('/*path', _handleInternalRoute);
  }

  @override
  String get platform => _remoteBot.platform;

  @override
  String get userId => _remoteBot.userId;

  @override
  Login get login => _login;

  @override
  Future<Login> getLogin() async => login;

  /// Updates the login snapshot (called by adapter on `login-updated`).
  void updateLogin(Login login) => _login = login;

  /// Releases any resources held by this bot.
  void dispose() {
    // InternalRouter doesn't hold resources requiring cleanup.
  }

  /// The features this bot advertises in READY / META.
  ///
  /// Mirrors the upstream `features` field from the remote login.
  @override
  Set<String> get features => _login.features.toSet();

  /// The set of method keys this bot actually implements.
  ///
  /// Returns the features advertised by the remote login.
  @override
  Set<String> get supportedMethods => _login.features.toSet();

  /// Internal HTTP endpoint proxy.
  ///
  /// Returns a dynamic proxy object: `bot.internal.foo(...)` dispatches to
  /// `POST /v1/internal/_api/foo` on the remote server.
  @override
  dynamic get internal => _internalProxy;

  /// Builds an internal URL path for this bot.
  ///
  /// Returns the path portion only (without baseUrl), e.g.
  /// `/v1/internal/telegram/12345/_api/someMethod`.
  /// Use with [NitoriClient.forwardFullPathBytes].
  String getInternalUrl(
    String path, {
    Map<String, String>? query,
    bool slash = false,
  }) {
    return '/v1/internal${slash ? '/' : ':'}$platform/$userId$path${query != null && query.isNotEmpty ? '?${Uri(queryParameters: query).query}' : ''}';
  }

  /// Defines a bot-level internal route.
  ///
  /// Called by subclasses to register custom internal endpoints under
  /// `/v1/internal/<platform>/<selfId>/...`.
  void defineInternalRoute(
    String path,
    InternalRouteCallback<RemoteSatoriBot> callback,
  ) {
    _internalRouter.define(path, callback);
  }

  /// Handles an internal route request.
  ///
  /// Called by the server for paths under `/v1/internal/<platform>/<selfId>/`
  /// that don't match the global routes (/_tmp, /_api).
  @override
  Future<InternalResponse?> handleInternalRoute(InternalRequest request) {
    return _internalRouter.handle(this, request);
  }

  /// Creates a [Session] for [event] with this bot as the host.
  @override
  Session session(Event event) {
    final session = Session(event, host: _RemoteSessionHost(this));
    session.sn = event.sn;
    return session;
  }

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
  @override
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
  /// Default does nothing; adapters that need internal routing override this.
  void _emitInternalSession(Session session) {}

  /// Hook for subclasses to emit a regular event.
  ///
  /// Default does nothing; adapters override to broadcast to their event
  /// stream.
  void _emitEvent(Event event) {}

  // -- ChannelInterface (6 methods) --

  @override
  Future<Channel> getChannel(String id) => _remoteBot.getChannel(id);

  @override
  Future<Pagination<Channel>> getChannelList(String guildId, {String? next}) =>
      _remoteBot.getChannelList(guildId, next: next);

  @override
  Stream<Channel> getChannelIter(String guildId) =>
      _remoteBot.getChannelIter(guildId);

  @override
  Future<Channel> createChannel(String guildId, Map<String, dynamic> data) =>
      _remoteBot.createChannel(guildId, data);

  @override
  Future<void> updateChannel(String channelId, Map<String, dynamic> data) =>
      _remoteBot.updateChannel(channelId, data);

  @override
  Future<void> deleteChannel(String id) => _remoteBot.deleteChannel(id);

  @override
  Future<Channel> createDirectChannel(String userId, {String? guildId}) =>
      _remoteBot.createDirectChannel(userId, guildId: guildId);

  @override
  Future<void> muteChannel(String channelId, {String? guildId, bool? enable}) =>
      _remoteBot.muteChannel(channelId, guildId: guildId, enable: enable);

  // -- MessageInterface (8 methods) --

  @override
  Future<List<Message>> createMessage(
    String channelId,
    String content, {
    dynamic referrer,
    bool? linkPreview,
  }) => _remoteBot.createMessage(channelId, content, referrer: referrer);

  @override
  Future<List<String>> sendMessage(
    String channelId,
    String content, {
    dynamic referrer,
    bool? linkPreview,
  }) => _remoteBot.sendMessage(channelId, content, referrer: referrer);

  @override
  Future<List<String>> sendPrivateMessage(
    String userId,
    String content, {
    String? guildId,
    dynamic referrer,
    bool? linkPreview,
  }) => _remoteBot.sendPrivateMessage(
    userId,
    content,
    guildId: guildId,
    referrer: referrer,
  );

  @override
  Future<Message> getMessage(String channelId, String messageId) =>
      _remoteBot.getMessage(channelId, messageId);

  @override
  Future<BidiList<Message>> getMessageList(
    String channelId, {
    String? next,
    Direction? direction,
    int? limit,
    Order? order,
  }) => _remoteBot.getMessageList(
    channelId,
    next: next,
    direction: direction,
    limit: limit,
    order: order,
  );

  @override
  Stream<Message> getMessageIter(String channelId) =>
      _remoteBot.getMessageIter(channelId);

  @override
  Future<void> editMessage(
    String channelId,
    String messageId,
    String content,
  ) => _remoteBot.editMessage(channelId, messageId, content);

  @override
  Future<void> deleteMessage(String channelId, String messageId) =>
      _remoteBot.deleteMessage(channelId, messageId);

  // Reaction methods (part of MessageInterface in upstream)

  @override
  Future<void> createReaction(
    String channelId,
    String messageId,
    String emojiId,
  ) => _remoteBot.createReaction(channelId, messageId, emojiId);

  @override
  Future<void> deleteReaction(
    String channelId,
    String messageId,
    String emojiId, {
    String? userId,
  }) =>
      _remoteBot.deleteReaction(channelId, messageId, emojiId, userId: userId);

  @override
  Future<void> clearReaction(
    String channelId,
    String messageId, {
    String? emojiId,
  }) => _remoteBot.clearReaction(channelId, messageId, emojiId: emojiId);

  @override
  Future<Pagination<User>> getReactionList(
    String channelId,
    String messageId,
    String emojiId, {
    String? next,
  }) => _remoteBot.getReactionList(channelId, messageId, emojiId, next: next);

  @override
  Stream<User> getReactionIter(
    String channelId,
    String messageId,
    String emojiId,
  ) => _remoteBot.getReactionIter(channelId, messageId, emojiId);

  // -- Upload method (1) --

  @override
  Future<List<String>> createUpload(List<dynamic> blobs) =>
      _remoteBot.createUpload(blobs);

  // -- GuildInterface (2 + 1 request) --

  @override
  Future<Guild> getGuild(String id) => _remoteBot.getGuild(id);

  @override
  Future<Pagination<Guild>> getGuildList({String? next}) =>
      _remoteBot.getGuildList(next: next);

  @override
  Stream<Guild> getGuildIter() => _remoteBot.getGuildIter();

  @override
  Future<void> handleGuildRequest(
    String messageId,
    bool approve, {
    String? comment,
  }) => _remoteBot.handleGuildRequest(messageId, approve, comment: comment);

  // -- GuildMemberInterface (6 + 1 request) --

  @override
  Future<GuildMember> getGuildMember(String guildId, String userId) =>
      _remoteBot.getGuildMember(guildId, userId);

  @override
  Future<Pagination<GuildMember>> getGuildMemberList(
    String guildId, {
    String? next,
  }) => _remoteBot.getGuildMemberList(guildId, next: next);

  @override
  Stream<GuildMember> getGuildMemberIter(String guildId) =>
      _remoteBot.getGuildMemberIter(guildId);

  @override
  Future<void> muteGuildMember(
    String guildId,
    String userId, {
    int? duration,
    String? reason,
  }) => _remoteBot.muteGuildMember(
    guildId,
    userId,
    duration: duration,
    reason: reason,
  );

  @override
  Future<void> kickGuildMember(
    String guildId,
    String userId, {
    bool? permanent,
  }) => _remoteBot.kickGuildMember(guildId, userId, permanent: permanent);

  @override
  Future<void> setGuildMemberRole(
    String guildId,
    String userId,
    String roleId,
  ) => _remoteBot.setGuildMemberRole(guildId, userId, roleId);

  @override
  Future<void> unsetGuildMemberRole(
    String guildId,
    String userId,
    String roleId,
  ) => _remoteBot.unsetGuildMemberRole(guildId, userId, roleId);

  @override
  Future<Pagination<GuildRole>> getGuildMemberRoleList(
    String guildId,
    String userId, {
    String? next,
  }) => _remoteBot.getGuildMemberRoleList(guildId, userId, next: next);

  @override
  Future<void> handleGuildMemberRequest(
    String messageId,
    bool approve, {
    String? comment,
  }) =>
      _remoteBot.handleGuildMemberRequest(messageId, approve, comment: comment);

  // -- GuildRoleInterface (4) --

  @override
  Future<Pagination<GuildRole>> getGuildRoleList(
    String guildId, {
    String? next,
  }) => _remoteBot.getGuildRoleList(guildId, next: next);

  @override
  Stream<GuildRole> getGuildRoleIter(String guildId) =>
      _remoteBot.getGuildRoleIter(guildId);

  @override
  Future<GuildRole> createGuildRole(
    String guildId, {
    String? name,
    int? color,
    int? position,
    BigInt? permissions,
    bool? hoist,
    bool? mentionable,
  }) => _remoteBot.createGuildRole(
    guildId,
    name: name,
    color: color,
    position: position,
    permissions: permissions,
    hoist: hoist,
    mentionable: mentionable,
  );

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
  }) => _remoteBot.updateGuildRole(
    guildId,
    roleId,
    name: name,
    color: color,
    position: position,
    permissions: permissions,
    hoist: hoist,
    mentionable: mentionable,
  );

  @override
  Future<void> deleteGuildRole(String guildId, String roleId) =>
      _remoteBot.deleteGuildRole(guildId, roleId);

  // -- UserInterface (1) --

  @override
  Future<User> getUser(String userId) => _remoteBot.getUser(userId);

  // -- FriendInterface (3 + 1 iterator) --

  @override
  Future<Pagination<Friend>> getFriendList({String? next}) =>
      _remoteBot.getFriendList(next: next);

  @override
  Stream<Friend> getFriendIter() => _remoteBot.getFriendIter();

  @override
  Future<void> deleteFriend(String userId) => _remoteBot.deleteFriend(userId);

  @override
  Future<void> handleFriendRequest(
    String messageId,
    bool approve, {
    String? comment,
  }) => _remoteBot.handleFriendRequest(messageId, approve, comment: comment);

  // -- CommandInterface (1) --

  @override
  Future<void> updateCommands(List<Command> commands) =>
      _remoteBot.updateCommands(commands);

  // -- Internal route handler --

  /// Forwards an internal route request to the remote server.
  ///
  /// Used by [SatoriServer._handleInternal] when a global route (`/_tmp/:id`,
  /// `/_api/:name`) misses locally and the real handler lives on the remote
  /// side. Returns the remote response verbatim — status, headers and bytes —
  /// so the local server can mirror it (including 404/405 and pagination
  /// headers). Auth token and identity headers ride along via [NitoriClient].
  Future<JsonFormBody> forwardInternal({
    required String method,
    required String path,
    Map<String, String> query = const <String, String>{},
    List<int> body = const <int>[],
    String? contentType,
    Map<String, String> extraHeaders = const <String, String>{},
  }) {
    final internalUrl = getInternalUrl(
      path,
      query: query.isEmpty ? null : query,
      slash: true,
    );
    return _remoteBot.client.forwardFullPathBytes(
      _remoteBot,
      internalUrl,
      body,
      method: method,
      contentType: contentType,
      extraHeaders: {
        ...extraHeaders,
        'satori-platform': _remoteBot.platform,
        'satori-user-id': _remoteBot.userId,
      },
    );
  }

  /// Handles the bot-level internal proxy route: `/*path` -> POST remote `/v1/internal/_api/*`.
  Future<InternalResponse> _handleInternalRoute(
    InternalRequest request,
    RemoteSatoriBot bot,
  ) async {
    final name = request.params['path']!; // e.g. '_api/someMethod'
    // Build the correct internal URL: /v1/internal/<platform>/<selfId>/_api/<name>
    // Use slash separator as expected by the remote server's path parsing.
    final internalUrl = getInternalUrl('/$name', slash: true);

    // Forward incoming headers (e.g., satori-pagination) to the remote server.
    final extraHeaders = <String, String>{
      'satori-platform': _remoteBot.platform,
      'satori-user-id': _remoteBot.userId,
    };
    // Pass through satori-pagination if present
    final pagination = request.headers['satori-pagination'];
    if (pagination != null) {
      extraHeaders['satori-pagination'] = pagination;
    }

    final response = await _remoteBot.client.forwardFullPathBytes(
      _remoteBot,
      internalUrl,
      request.body is List<int> ? request.body as List<int> : const <int>[],
      extraHeaders: extraHeaders,
    );
    return InternalResponse(
      status: response.statusCode,
      headers: response.headers,
      body: response.bytes,
    );
  }
}

/// Dynamic proxy for `bot.internal.*` calls on [RemoteSatoriBot].
///
/// Allows calling `bot.internal.someMethod(args)` which resolves to a
/// `POST /v1/internal/<platform>/<selfId>/_api/someMethod` route on the
/// remote server.
class _RemoteInternalProxy {
  _RemoteInternalProxy(this._bot);

  final RemoteSatoriBot _bot;

  @pragma('vm:prefer-inline')
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // invocation.memberName is a Symbol; extract the bare method name.
    final String cleanName = symbolName(invocation.memberName);
    final positionalArgs = invocation.positionalArguments;
    final namedArgs = invocation.namedArguments;

    // Build the request for the internal route on the remote server.
    // Path: /v1/internal/<platform>/<selfId>/_api/<methodName>
    final path = _bot.getInternalUrl('/_api/$cleanName', slash: true);
    final jsonBody = JsonForm.encode({
      'args': positionalArgs,
      'kwargs': namedArgs.map((k, v) => MapEntry(k.toString(), v)),
    });

    return _bot._remoteBot.client
        .requestFullPathBytes(
          _bot._remoteBot,
          path,
          jsonBody.bytes,
          extraHeaders: {
            'satori-platform': _bot._remoteBot.platform,
            'satori-user-id': _bot._remoteBot.userId,
          },
          contentType: jsonBody.contentType,
        )
        .then((response) {
          return JsonForm.decode(response.contentType, response.bytes);
        });
  }
}

/// Session host for [RemoteSatoriBot].
class _RemoteSessionHost implements SessionHost {
  _RemoteSessionHost(this._bot);

  final RemoteSatoriBot _bot;

  @override
  String get platform => _bot.platform;

  @override
  String get selfId => _bot.userId;

  @override
  Login get login => _bot.login;

  @override
  int get sequence => _bot.login.sn ?? 0;
}

/// A [SatoriAdapter] that bridges to a remote Satori server.
///
/// Connects to a remote Satori server via WebSocket (`/v1/events`), performs
/// IDENTIFY with token, handles READY/META/EVENT/PING/PONG, and supports
/// automatic reconnection with configurable retry semantics (handled by
/// [NitoriClient.Gateway]).
///
/// Events received from the remote server are converted to local [Event] objects
/// and emitted through the [events] stream. The local [SatoriServer] then
/// assigns fresh sequence numbers, applies alias rewriting, and broadcasts to
/// local gateway clients.
///
/// Login events (`login-added`, `login-updated`, `login-removed`) are used to
/// sync the local bot list but are NOT forwarded to the [events] stream (the
/// server's [_publish] filters them from replay anyway).
///
/// The remote server's `proxyUrls` from READY/META are exposed via
/// [proxyUrls] and included in local READY/META frames.
///
/// Sequence number mapping:
/// The local server assigns its own monotonically increasing sequence numbers
/// to events. This adapter maintains a bidirectional mapping between local
/// sequence numbers (assigned by the local server) and remote sequence numbers
/// (assigned by the remote server). This enables correct resume behavior on
/// both sides: local clients resume using local sn, while the remote connection
/// resumes using remote sn.
class RemoteSatoriAdapter implements SatoriAdapter {
  /// The underlying NitoriClient that maintains the gateway connection.
  final NitoriClient _client;

  /// Broadcast stream of events from the remote server.
  final StreamController<Event> _events = StreamController<Event>.broadcast();

  /// Bots keyed by login.sn.
  final Map<int, RemoteSatoriBot> _botsBySn = {};

  /// Proxy URLs from the remote server's READY/META.
  final List<String> _proxyUrls = [];

  /// Maps local sequence number (assigned by local server) -> remote sequence number.
  final Map<int, int> _localToRemoteSn = {};

  /// Maps remote sequence number -> local sequence number.
  final Map<int, int> _remoteToLocalSn = {};

  /// Queue of pending remote sequence numbers for events that have been emitted
  /// but not yet published by the local server. Used to correlate events in
  /// [onEventPublished] callback since the event is deep-copied.
  final Queue<int> _pendingRemoteSns = Queue<int>();

  /// Creates a new remote adapter.
  ///
  /// Parameters mirror [NitoriClient] constructor:
  /// - [baseUrl]: HTTP(S) base URL of the remote Satori server.
  /// - [token]: Access token for IDENTIFY.
  /// - [platform]: Platform identity, sent as `IDENTIFY.body.satori-platform`.
  /// - [userId]: User identity, sent as `IDENTIFY.body.satori-user-id`.
  /// - [retryTimes]: Initial connection retry budget.
  /// - [retryInterval]: Retry interval while budget not exhausted.
  /// - [retryLazy]: Retry interval after established connection drops and budget exhausted.
  /// - [heartbeatInterval]: PING interval while connected.
  RemoteSatoriAdapter({
    required String baseUrl,
    String? token,
    String? platform,
    String? userId,
    int retryTimes = 6,
    Duration retryInterval = const Duration(seconds: 5),
    Duration retryLazy = const Duration(minutes: 1),
    Duration heartbeatInterval = const Duration(seconds: 10),
  }) : _client = NitoriClient(
         baseUrl: baseUrl,
         token: token,
         platform: platform,
         userId: userId,
         retryTimes: retryTimes,
         retryInterval: retryInterval,
         retryLazy: retryLazy,
         heartbeatInterval: heartbeatInterval,
       ) {
    _client.events.listen(_onGatewayEvent);
    _client.onStatusChanged = _onStatusChanged;
    // Sync proxyUrls from META (these don't go through the events stream)
    _client.onMetaExternal = (urls) {
      _proxyUrls.clear();
      _proxyUrls.addAll(urls);
    };
    // Sync bots from client when READY is received (chained after internal _handleReady)
    _client.onReadyExternal = (logins, urls) {
      for (final login in logins) {
        _syncBot(login, 'added');
      }
    };
  }

  @override
  List<SatoriBot> get bots => _botsBySn.values.toList();

  @override
  Stream<Event> get events => _events.stream;

  @override
  List<String> get proxyUrls => List.unmodifiable(_proxyUrls);

  /// The underlying NitoriClient (for test access).
  NitoriClient get client => _client;

  /// Callback for [SatoriServer.onEventPublished] to record local<->remote sn mapping.
  ///
  /// Call this after creating both the adapter and the server:
  /// ```dart
  /// final adapter = RemoteSatoriAdapter(...);
  /// final server = SatoriServer(adapter: adapter, onEventPublished: adapter.onEventPublished);
  /// ```
  void _onEventPublished(Event event, int localSn) {
    if (_pendingRemoteSns.isEmpty) return;
    final remoteSn = _pendingRemoteSns.removeFirst();
    _localToRemoteSn[localSn] = remoteSn;
    _remoteToLocalSn[remoteSn] = localSn;
  }

  /// Callback for [SatoriServer.onClientResume] to handle local client resume.
  ///
  /// When a local gateway client reconnects with a local sequence number,
  /// this translates it to the remote sequence number and forces the remote
  /// gateway to reconnect with that remote sn, ensuring event replay
  /// continuity on both sides of the bridge.
  ///
  /// The remote gateway's sequence (last received remote sn) should only
  /// move FORWARD. If the translated remote sn is older than the current
  /// gateway sequence, we must NOT move it backward, as that would cause
  /// the remote server to replay already-delivered events on the next
  /// reconnect, causing duplicates.
  void _onClientResume(int localSn) {
    final remoteSn = translateLocalToRemoteSn(localSn);
    // Only advance the remote gateway's sequence forward; never move backward.
    final currentRemoteSn = _client.lastReceivedSn ?? 0;
    if (remoteSn > currentRemoteSn) {
      // Force the remote gateway to reconnect with the translated remote sn.
      // Setting the sequence triggers resume on next connection attempt.
      _client.resumeFrom(remoteSn);
    }
    // If remoteSn <= currentRemoteSn, leave gateway sequence untouched.
    // The local server's _replay() already handles replaying buffered events
    // to the local client using the local sn, which is correct.
  }

  /// Returns the callback to be passed to [SatoriServer.onEventPublished].
  void Function(Event, int) get onEventPublished => _onEventPublished;

  /// Returns the callback to be passed to [SatoriServer.onClientResume].
  void Function(int) get onClientResume => _onClientResume;

  /// Translates a local sequence number to the corresponding remote sequence number.
  ///
  /// Returns the remote sn if a mapping exists, otherwise returns the local sn
  /// (which may be used as a fallback).
  int translateLocalToRemoteSn(int localSn) {
    return _localToRemoteSn[localSn] ?? localSn;
  }

  /// Translates a remote sequence number to the corresponding local sequence number.
  int translateRemoteToLocalSn(int remoteSn) {
    return _remoteToLocalSn[remoteSn] ?? remoteSn;
  }

  /// Connects to the remote gateway and keeps it alive until [stop].
  Future<void> start() => _client.start();

  /// Disconnects the remote gateway.
  Future<void> stop() => _client.stop();

  /// Called when the gateway connection status changes.
  void _onStatusChanged(Status status) {
    if (status == Status.online) {
      // READY already delivered via _onGatewayEvent
    }
  }

  /// Handles a gateway event from the remote server.
  void _onGatewayEvent(GatewayEvent ge) {
    final raw = ge.raw;
    final type = ge.type;
    final sn = ge.sn;
    final login = ge.login;

    if (login == null) return; // malformed

    // Handle login events: sync bot list but don't forward to events stream.
    if (type!.startsWith('login-')) {
      final action = type.substring(
        'login-'.length,
      ); // 'added'|'updated'|'removed'
      _syncBot(login, action);
      // Do NOT forward login-* to _events (server._publish filters them from replay)
      return;
    }

    // Normal event: create Event from raw (snake_case keys).
    // Event.fromJson expects snake_case (fieldRename: snake).
    final event = Event.fromJson(raw);
    event.sn = sn;
    event.login = login;

    // Queue the remote sn for correlation in _onEventPublished.
    // The event will be deep-copied by the server, so we track by order.
    _pendingRemoteSns.add(sn ?? 0);

    _events.add(event);
  }

  /// Syncs a bot based on a login event.
  void _syncBot(Login login, String action) {
    switch (action) {
      case 'added':
        // Find the remote bot matching this login.
        final remoteBot = _client.bots.firstWhere(
          (b) => b.login?.sn == login.sn,
        );
        final bot = RemoteSatoriBot(this, remoteBot);
        _botsBySn[login.sn!] = bot;
        break;
      case 'updated':
        _botsBySn[login.sn!]?.updateLogin(login);
        break;
      case 'removed':
        _botsBySn.remove(login.sn)?.dispose();
        break;
    }
  }
}
