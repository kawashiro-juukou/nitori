/// The Satori client: a WebSocket gateway plus the HTTP API surface.
///
/// [NitoriClient] owns the gateway connection and the shared HTTP client;
/// [NitoriBot] represents one login and carries the `satori-platform` /
/// `satori-user-id` identity headers for every request it makes.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:nitori_core/nitori_core.dart';
import 'package:nitori_message/nitori_message.dart' hide Message;

import 'api_client.dart';
import 'gateway_client.dart';

export 'api_client.dart'
    show SatoriApiClient, SatoriApiException, SatoriApiIdentity;

/// Connects to a Satori server and exposes its bots and event stream.
class NitoriClient {
  NitoriClient({
    required this.baseUrl,
    this.token,
    this.platform,
    this.userId,
    http.Client? httpClient,
    int retryTimes = 6,
    Duration retryInterval = const Duration(seconds: 5),
    Duration retryLazy = const Duration(minutes: 1),
    Duration heartbeatInterval = const Duration(seconds: 10),
  }) : _api = SatoriApiClient(
         baseUrl: baseUrl,
         token: token,
         httpClient: httpClient,
       ),
       _gateway = SatoriGatewayClient(
         baseUrl: baseUrl,
         token: token,
         platform: platform,
         userId: userId,
         retryTimes: retryTimes,
         retryInterval: retryInterval,
         retryLazy: retryLazy,
         heartbeatInterval: heartbeatInterval,
       ) {
    // Set up gateway callbacks in constructor body so external callbacks can be chained
    _gateway.onReady = (logins, urls) {
      _handleReady(logins, urls);
      _onReadyExternal?.call(logins, urls);
    };
    _gateway.onMeta = (urls) {
      _api.proxyUrls = urls;
      _onMetaExternal?.call(urls);
    };
    _gateway.onStatusChanged = (status) {
      onStatusChanged?.call(status);
    };
    _gateway.events.listen(_handleLoginEvent);
    _gateway.events.listen(_handleInteractionEvent);
  }

  /// HTTP(S) base URL of the Satori server, e.g. `http://localhost:5140`.
  final String baseUrl;

  /// Access token sent as `Authorization: Bearer` and `IDENTIFY.body.token`.
  final String? token;

  /// Platform identity sent as `IDENTIFY.body.satori-platform`.
  final String? platform;

  /// User identity sent as `IDENTIFY.body.satori-user-id`.
  final String? userId;

  /// Connection lifecycle of the WebSocket gateway.
  final SatoriGatewayClient _gateway;

  /// The underlying gateway for test access.
  SatoriGatewayClient get gateway => _gateway;

  /// HTTP API surface; owns the shared `http.Client`.
  final SatoriApiClient _api;

  /// The HTTP API client used for bot requests.
  SatoriApiClient get api => _api;

  /// Bots resolved from READY and kept in sync by `login-*` events.
  final List<NitoriBot> bots = <NitoriBot>[];

  /// Proxy URLs advertised by the server, useful for proxying media.
  List<String> get proxyUrls => _api.proxyUrls;
  set proxyUrls(List<String> urls) => _api.proxyUrls = urls;

  /// Resolves [url] through the server's media proxy when it is allowed.
  ///
  /// Returns `$baseUrl/v1/proxy/$url` if [url] starts with one of the
  /// server-advertised [proxyUrls]; returns null otherwise.
  String? proxyUrl(String url) => _api.proxyUrl(url);

  /// Like [proxyUrl] but falls back to [url] itself.
  String proxyUrlOr(String url) => _api.proxyUrlOr(url);

  /// Live event stream of the gateway.
  Stream<SatoriGatewayEvent> get events => _gateway.events;

  /// Events decoded into the protocol [Event] model, excluding `login-*`
  /// frames (bots are kept in sync separately).
  Stream<Event> get eventStream => _gateway.events
      .where((e) => !(e.type?.startsWith('login-') ?? false))
      .map((e) => e.event);

  /// The sequence number (sn) of the last received EVENT frame.
  /// Returns null if no event has been received yet.
  int? get lastReceivedSn => _gateway.sequence;

  /// Sets the resume sequence number for the next IDENTIFY.
  ///
  /// When the gateway reconnects, it will include this `sn` in the IDENTIFY
  /// payload so the server replays events after this sequence number.
  /// This enables application-layer idempotency: the client can store the
  /// last processed `sn` and call [resumeFrom] on restart to avoid
  /// re-processing already-handled events.
  Future<void> resumeFrom(int sn) async {
    _gateway.sequence = sn;
  }

  Status get status => _gateway.status;

  /// Fired whenever the connection status changes.
  void Function(Status status)? onStatusChanged;

  /// Called when a button handler throws; uncaught errors fall back to the zone.
  void Function(Object error, StackTrace stackTrace)? onButtonError;

  /// Internal: called by the gateway when READY is received.
  void Function(List<Login> logins, List<String> proxyUrls)? _onReadyExternal;

  /// Internal: called by the gateway when META is received.
  void Function(List<String> proxyUrls)? _onMetaExternal;

  /// Sets an external callback for READY (chained after internal _handleReady).
  set onReadyExternal(
    void Function(List<Login> logins, List<String> proxyUrls)? callback,
  ) {
    _onReadyExternal = callback;
  }

  /// Sets an external callback for META (chained after internal proxyUrls update).
  set onMetaExternal(void Function(List<String> proxyUrls)? callback) {
    _onMetaExternal = callback;
  }

  /// Connects to the gateway and keeps it alive until [stop].
  Future<void> start() => _gateway.start();

  /// Disconnects the gateway, keeping the HTTP client open.
  Future<void> stop() async {
    await _gateway.stop();
  }

  /// Disconnects and releases the shared HTTP client.
  Future<void> close() async {
    await _gateway.stop();
    _api.close();
  }

  void _handleReady(List<Login> logins, List<String> proxyUrls) {
    _api.proxyUrls = proxyUrls;
    for (final login in logins) {
      _addBot(login);
    }
  }

  void _handleLoginEvent(SatoriGatewayEvent event) {
    final login = event.login;
    if (login == null) return;
    switch (event.type) {
      case 'login-added':
        _addBot(login);
      case 'login-updated':
        _updateBot(login);
      case 'login-removed':
        _removeBot(login);
    }
  }

  /// Handles `interaction/button` events and dispatches them to registered
  /// button handlers on the owning bot.
  void _handleInteractionEvent(SatoriGatewayEvent event) {
    if (event.type != EventName.interactionButton.value) return;
    final Event decoded;
    try {
      decoded = event.event;
    } on Object {
      return; // malformed frame: the stream must stay alive
    }
    final id = decoded.button?.id;
    if (id == null) return;
    final handler = _botBySn(decoded.login?.sn)?.callbacks[id];
    if (handler == null) return;
    Future<void>.sync(() => handler(decoded)).catchError((
      Object error,
      StackTrace stack,
    ) {
      final callback = onButtonError;
      if (callback != null) {
        callback(error, stack);
      } else {
        Zone.current.handleUncaughtError(error, stack);
      }
    });
  }

  NitoriBot? _botBySn(int? sn) {
    for (final bot in bots) {
      if (bot.login?.sn == sn) return bot;
    }
    return null;
  }

  void _addBot(Login login) {
    if (_botBySn(login.sn) != null) return;
    bots.add(NitoriBot(this, login: login));
  }

  void _updateBot(Login login) {
    final bot = _botBySn(login.sn);
    if (bot != null) {
      bot.login = login;
    } else {
      bots.add(NitoriBot(this, login: login));
    }
  }

  void _removeBot(Login login) {
    bots.removeWhere((bot) => bot.login?.sn == login.sn);
  }

  // -- multi-login management --

  /// Returns the bot matching [platform] and [userId], or null if not found.
  NitoriBot? getBot(String platform, String userId) {
    for (final bot in bots) {
      if (bot.platform == platform && bot.userId == userId) return bot;
    }
    return null;
  }

  /// Adds a bot for the given [login].
  ///
  /// If a bot with the same sn already exists, does nothing.
  void addBot(Login login) {
    if (_botBySn(login.sn) != null) return;
    bots.add(NitoriBot(this, login: login));
  }

  /// Removes the bot with the given [sn].
  void removeBot(int sn) {
    bots.removeWhere((bot) => bot.login?.sn == sn);
  }

  /// Returns all bots for the given [platform].
  Iterable<NitoriBot> botsByPlatform(String platform) {
    return bots.where((bot) => bot.platform == platform);
  }

  /// Sends one API request and returns the decoded JSON response.
  Future<dynamic> _request(NitoriBot bot, String key, List<Object?> args) =>
      _api.request(_identity(bot), key, args);

  SatoriApiIdentity _identity(NitoriBot bot) =>
      SatoriApiIdentity(platform: bot.platform, userId: bot.userId);

  /// Public version of [_request] that allows arbitrary key and extra headers.
  ///
  /// Does NOT require [methods][key] to exist (for internal routes).
  /// Reuses [_request]'s encoding logic but skips the methods lookup.
  Future<JsonFormBody> request(
    NitoriBot bot,
    String key,
    List<Object?> args, {
    Map<String, String>? extraHeaders,
  }) =>
      _api.requestByKey(_identity(bot), key, args, extraHeaders: extraHeaders);

  /// Makes a request with a full path (for internal routes).
  ///
  /// Unlike [request], this takes a full path starting with `/v1/` and doesn't
  /// prepend the base URL's v1 prefix.
  Future<JsonFormBody> requestFullPath(
    NitoriBot bot,
    String fullPath,
    List<Object?> args, {
    Map<String, String>? extraHeaders,
  }) => _api.requestFullPath(
    _identity(bot),
    fullPath,
    args,
    extraHeaders: extraHeaders,
  );

  /// Makes a request with a full path, sending raw bytes body.
  ///
  /// For internal routes that use multipart/form-data or already-encoded
  /// JsonForm. [method] defaults to POST; GET forwards carry no body.
  Future<JsonFormBody> requestFullPathBytes(
    NitoriBot bot,
    String fullPath,
    List<int> bodyBytes, {
    Map<String, String>? extraHeaders,
    String? contentType,
    String method = 'POST',
  }) => _api.requestFullPathBytes(
    _identity(bot),
    fullPath,
    bodyBytes,
    extraHeaders: extraHeaders,
    contentType: contentType,
    method: method,
  );

  /// Forwards an internal route request to the remote server, returning the
  /// response verbatim (status, headers and bytes) instead of throwing on a
  /// non-200 status. Used by the protocol bridge to mirror remote `/_tmp` and
  /// `/_api` responses onto the local server.
  Future<JsonFormBody> forwardFullPathBytes(
    NitoriBot bot,
    String fullPath,
    List<int> bodyBytes, {
    Map<String, String>? extraHeaders,
    String? contentType,
    String method = 'POST',
  }) => _api.forwardFullPathBytes(
    _identity(bot),
    fullPath,
    bodyBytes,
    extraHeaders: extraHeaders,
    contentType: contentType,
    method: method,
  );

  /// Downloads [url] as a byte stream.
  ///
  /// Routes through the server proxy when [useProxy] is true and the server
  /// advertises it; otherwise fetches [url] directly. Throws
  /// [SatoriApiException] on a non-200 status.
  Future<Stream<List<int>>> downloadStream(
    String url, {
    bool useProxy = true,
  }) => _api.downloadStream(url, useProxy: useProxy);

  /// Downloads [url] and returns its bytes with the response content type.
  Future<({Uint8List bytes, String? contentType})> download(
    String url, {
    bool useProxy = true,
  }) => _api.download(url, useProxy: useProxy);
}

/// A single login: carries the identity headers and exposes the full HTTP API.
class NitoriBot {
  NitoriBot(this.client, {this.login, String? platform, String? userId})
    : platform = platform ?? login?.platform ?? '',
      userId = userId ?? login?.user?.id ?? '';

  final NitoriClient client;

  /// The login this bot represents; refreshed on `login-updated`.
  Login? login;

  /// Value of the `satori-platform` header.
  String platform;

  /// Value of the `satori-user-id` header.
  String userId;

  // -- channel --

  Future<Channel> getChannel(String channelId, {String? guildId}) async {
    final data = await client._request(this, 'channel.get', <Object?>[
      channelId,
      guildId,
    ]);
    return Channel.fromJson(data as Map<String, dynamic>);
  }

  Future<Pagination<Channel>> getChannelList(
    String guildId, {
    String? next,
  }) async {
    final data = await client._request(this, 'channel.list', <Object?>[
      guildId,
      next,
    ]);
    return _pagination(data, Channel.fromJson);
  }

  Future<Channel> createChannel(
    String guildId,
    Map<String, dynamic> data,
  ) async {
    final result = await client._request(this, 'channel.create', <Object?>[
      guildId,
      data,
    ]);
    return Channel.fromJson(result as Map<String, dynamic>);
  }

  Future<void> updateChannel(
    String channelId,
    Map<String, dynamic> data,
  ) async {
    await client._request(this, 'channel.update', <Object?>[channelId, data]);
  }

  Future<void> deleteChannel(String channelId) async {
    await client._request(this, 'channel.delete', <Object?>[channelId]);
  }

  Future<void> muteChannel(
    String channelId, {
    String? guildId,
    bool? enable,
  }) async {
    await client._request(this, 'channel.mute', <Object?>[
      channelId,
      guildId,
      enable,
    ]);
  }

  Stream<Channel> getChannelIter(String guildId) async* {
    var next = '';
    while (true) {
      final page = await getChannelList(
        guildId,
        next: next.isEmpty ? null : next,
      );
      for (final channel in page.data) {
        yield channel;
      }
      if (page.next == null || page.next!.isEmpty) break;
      next = page.next!;
    }
  }

  // -- message --

  Future<List<Message>> createMessage(
    String channelId,
    Object content, {
    dynamic referrer,
  }) async {
    final data = await client._request(this, 'message.create', <Object?>[
      channelId,
      _renderContent(content),
      referrer,
    ]);
    return (data as List<dynamic>)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends a message and returns only the message IDs.
  ///
  /// Delegates to [createMessage] and extracts the IDs.
  Future<List<String>> sendMessage(
    String channelId,
    Object content, {
    dynamic referrer,
  }) async {
    final created = await createMessage(channelId, content, referrer: referrer);
    return <String>[for (final message in created) message.id!];
  }

  /// Handlers keyed by `button.id`, invoked on `interaction/button` events.
  final Map<String, FutureOr<void> Function(Event event)> callbacks =
      <String, FutureOr<void> Function(Event event)>{};

  /// Registers [handler] for clicks on buttons carrying [id].
  void onButton(String id, FutureOr<void> Function(Event event) handler) {
    callbacks[id] = handler;
  }

  /// Removes the handler registered for [id].
  void offButton(String id) {
    callbacks.remove(id);
  }

  Future<void> editMessage(
    String channelId,
    String messageId,
    Object content,
  ) async {
    await client._request(this, 'message.update', <Object?>[
      channelId,
      messageId,
      _renderContent(content),
    ]);
  }

  Future<void> deleteMessage(String channelId, String messageId) async {
    await client._request(this, 'message.delete', <Object?>[
      channelId,
      messageId,
    ]);
  }

  /// Serialises typed message content to the wire markup string.
  ///
  /// Accepts a [String], a single [Node] or an [Iterable] of [Node]s; each node
  /// is rendered with its [Node.toString] and joined with no separator. Anything
  /// else throws [ArgumentError].
  String _renderContent(Object content) {
    if (content is String) return content;
    if (content is Node) return content.toString();
    if (content is Iterable<Node>) {
      return content.map((n) => n.toString()).join('');
    }
    throw ArgumentError.value(
      content,
      'content',
      'String, Node or Iterable<Node>',
    );
  }

  Future<Message> getMessage(String channelId, String messageId) async {
    final data = await client._request(this, 'message.get', <Object?>[
      channelId,
      messageId,
    ]);
    return Message.fromJson(data as Map<String, dynamic>);
  }

  Future<BidiList<Message>> getMessageList(
    String channelId, {
    String? next,
    Direction? direction,
    int? limit,
    Order? order,
  }) async {
    final data = await client._request(this, 'message.list', <Object?>[
      channelId,
      next,
      direction?.value,
      limit,
      order?.value,
    ]);
    return _bidiList(data, Message.fromJson);
  }

  Stream<Message> getMessageIter(String channelId) async* {
    var next = '';
    Direction? dir = Direction.before;
    while (true) {
      final page = await getMessageList(
        channelId,
        next: next.isEmpty ? null : next,
        direction: dir,
      );
      for (final message in page.data) {
        yield message;
      }
      if (page.next == null || page.next!.isEmpty) break;
      next = page.next!;
      dir = Direction.around; // subsequent pages use around
    }
  }

  // -- reaction --

  Future<void> createReaction(
    String channelId,
    String messageId,
    String emojiId,
  ) async {
    await client._request(this, 'reaction.create', <Object?>[
      channelId,
      messageId,
      emojiId,
    ]);
  }

  Future<void> deleteReaction(
    String channelId,
    String messageId,
    String emojiId, {
    String? userId,
  }) async {
    await client._request(this, 'reaction.delete', <Object?>[
      channelId,
      messageId,
      emojiId,
      userId,
    ]);
  }

  Future<void> clearReaction(
    String channelId,
    String messageId, {
    String? emojiId,
  }) async {
    await client._request(this, 'reaction.clear', <Object?>[
      channelId,
      messageId,
      emojiId,
    ]);
  }

  Future<Pagination<User>> getReactionList(
    String channelId,
    String messageId,
    String emojiId, {
    String? next,
  }) async {
    final data = await client._request(this, 'reaction.list', <Object?>[
      channelId,
      messageId,
      emojiId,
      next,
    ]);
    return _pagination(data, User.fromJson);
  }

  Stream<User> getReactionIter(
    String channelId,
    String messageId,
    String emojiId,
  ) async* {
    var next = '';
    while (true) {
      final page = await getReactionList(
        channelId,
        messageId,
        emojiId,
        next: next.isEmpty ? null : next,
      );
      for (final user in page.data) {
        yield user;
      }
      if (page.next == null || page.next!.isEmpty) break;
      next = page.next!;
    }
  }

  // -- upload --

  Future<List<String>> createUpload(List<Object> blobs) async {
    final data = await client._request(
      this,
      'upload.create',
      List<Object>.of(blobs),
    );
    return (data as Map<String, dynamic>).values.cast<String>().toList();
  }

  // -- guild --

  Future<Guild> getGuild(String guildId) async {
    final data = await client._request(this, 'guild.get', <Object?>[guildId]);
    return Guild.fromJson(data as Map<String, dynamic>);
  }

  Future<Pagination<Guild>> getGuildList({String? next}) async {
    final data = await client._request(this, 'guild.list', <Object?>[next]);
    return _pagination(data, Guild.fromJson);
  }

  Stream<Guild> getGuildIter() async* {
    var next = '';
    while (true) {
      final page = await getGuildList(next: next.isEmpty ? null : next);
      for (final guild in page.data) {
        yield guild;
      }
      if (page.next == null || page.next!.isEmpty) break;
      next = page.next!;
    }
  }

  Future<GuildMember> getGuildMember(String guildId, String userId) async {
    final data = await client._request(this, 'guild.member.get', <Object?>[
      guildId,
      userId,
    ]);
    return GuildMember.fromJson(data as Map<String, dynamic>);
  }

  Future<Pagination<GuildMember>> getGuildMemberList(
    String guildId, {
    String? next,
  }) async {
    final data = await client._request(this, 'guild.member.list', <Object?>[
      guildId,
      next,
    ]);
    return _pagination(data, GuildMember.fromJson);
  }

  Stream<GuildMember> getGuildMemberIter(String guildId) async* {
    var next = '';
    while (true) {
      final page = await getGuildMemberList(
        guildId,
        next: next.isEmpty ? null : next,
      );
      for (final member in page.data) {
        yield member;
      }
      if (page.next == null || page.next!.isEmpty) break;
      next = page.next!;
    }
  }

  Future<void> kickGuildMember(
    String guildId,
    String userId, {
    bool? permanent,
  }) async {
    await client._request(this, 'guild.member.kick', <Object?>[
      guildId,
      userId,
      permanent,
    ]);
  }

  Future<void> muteGuildMember(
    String guildId,
    String userId, {
    int? duration,
    String? reason,
  }) async {
    await client._request(this, 'guild.member.mute', <Object?>[
      guildId,
      userId,
      duration,
      reason,
    ]);
  }

  Future<void> setGuildMemberRole(
    String guildId,
    String userId,
    String roleId,
  ) async {
    await client._request(this, 'guild.member.role.set', <Object?>[
      guildId,
      userId,
      roleId,
    ]);
  }

  Future<void> unsetGuildMemberRole(
    String guildId,
    String userId,
    String roleId,
  ) async {
    await client._request(this, 'guild.member.role.unset', <Object?>[
      guildId,
      userId,
      roleId,
    ]);
  }

  Future<Pagination<GuildRole>> getGuildMemberRoleList(
    String guildId,
    String userId, {
    String? next,
  }) async {
    final data = await client._request(
      this,
      'guild.member.role.list',
      <Object?>[guildId, userId, next],
    );
    return _pagination(data, GuildRole.fromJson);
  }

  Future<Pagination<GuildRole>> getGuildRoleList(
    String guildId, {
    String? next,
  }) async {
    final data = await client._request(this, 'guild.role.list', <Object?>[
      guildId,
      next,
    ]);
    return _pagination(data, GuildRole.fromJson);
  }

  Stream<GuildRole> getGuildRoleIter(String guildId) async* {
    var next = '';
    while (true) {
      final page = await getGuildRoleList(
        guildId,
        next: next.isEmpty ? null : next,
      );
      for (final role in page.data) {
        yield role;
      }
      if (page.next == null || page.next!.isEmpty) break;
      next = page.next!;
    }
  }

  Future<GuildRole> createGuildRole(
    String guildId, {
    String? name,
    int? color,
    int? position,
    BigInt? permissions,
    bool? hoist,
    bool? mentionable,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (color != null) data['color'] = color;
    if (position != null) data['position'] = position;
    if (permissions != null) data['permissions'] = permissions.toString();
    if (hoist != null) data['hoist'] = hoist;
    if (mentionable != null) data['mentionable'] = mentionable;
    final result = await client._request(this, 'guild.role.create', <Object?>[
      guildId,
      data,
    ]);
    return GuildRole.fromJson(result as Map<String, dynamic>);
  }

  Future<void> updateGuildRole(
    String guildId,
    String roleId, {
    String? name,
    int? color,
    int? position,
    BigInt? permissions,
    bool? hoist,
    bool? mentionable,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (color != null) data['color'] = color;
    if (position != null) data['position'] = position;
    if (permissions != null) data['permissions'] = permissions.toString();
    if (hoist != null) data['hoist'] = hoist;
    if (mentionable != null) data['mentionable'] = mentionable;
    await client._request(this, 'guild.role.update', <Object?>[
      guildId,
      roleId,
      data,
    ]);
  }

  Future<void> deleteGuildRole(String guildId, String roleId) async {
    await client._request(this, 'guild.role.delete', <Object?>[
      guildId,
      roleId,
    ]);
  }

  // -- login / user / friend --

  Future<Login> getLogin() async {
    final data = await client._request(this, 'login.get', const <Object?>[]);
    return Login.fromJson(data as Map<String, dynamic>);
  }

  Future<User> getUser(String userId) async {
    final data = await client._request(this, 'user.get', <Object?>[userId]);
    return User.fromJson(data as Map<String, dynamic>);
  }

  Future<Channel> createDirectChannel(String userId, {String? guildId}) async {
    final data = await client._request(this, 'user.channel.create', <Object?>[
      userId,
      guildId,
    ]);
    return Channel.fromJson(data as Map<String, dynamic>);
  }

  /// Sends a private message by creating a direct channel and then sending.
  ///
  /// Convenience method matching the upstream SDK's `sendPrivateMessage`.
  Future<List<String>> sendPrivateMessage(
    String userId,
    Object content, {
    String? guildId,
    dynamic referrer,
  }) async {
    final channel = await createDirectChannel(userId, guildId: guildId);
    return sendMessage(channel.id, content, referrer: referrer);
  }

  Future<Pagination<Friend>> getFriendList({String? next}) async {
    final data = await client._request(this, 'friend.list', <Object?>[next]);
    return _pagination(data, Friend.fromJson);
  }

  Stream<Friend> getFriendIter() async* {
    var next = '';
    while (true) {
      final page = await getFriendList(next: next.isEmpty ? null : next);
      for (final friend in page.data) {
        yield friend;
      }
      if (page.next == null || page.next!.isEmpty) break;
      next = page.next!;
    }
  }

  Future<void> deleteFriend(String userId) async {
    await client._request(this, 'friend.delete', <Object?>[userId]);
  }

  Future<void> handleFriendRequest(
    String messageId,
    bool approve, {
    String? comment,
  }) async {
    await client._request(this, 'friend.approve', <Object?>[
      messageId,
      approve,
      comment,
    ]);
  }

  Future<void> handleGuildRequest(
    String messageId,
    bool approve, {
    String? comment,
  }) async {
    await client._request(this, 'guild.approve', <Object?>[
      messageId,
      approve,
      comment,
    ]);
  }

  Future<void> handleGuildMemberRequest(
    String messageId,
    bool approve, {
    String? comment,
  }) async {
    await client._request(this, 'guild.member.approve', <Object?>[
      messageId,
      approve,
      comment,
    ]);
  }

  Future<void> updateCommands(List<Command> commands) async {
    await client._request(this, 'command.update', <Object?>[
      commands.map((c) => c.toJson()).toList(),
    ]);
  }

  Pagination<T> _pagination<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final map = json as Map<String, dynamic>;
    final data = (map['data'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
    return Pagination<T>(data, next: map['next'] as String?);
  }

  BidiList<T> _bidiList<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final map = json as Map<String, dynamic>;
    final data = (map['data'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
    return BidiList<T>(
      data,
      prev: map['prev'] as String?,
      next: map['next'] as String?,
    );
  }
}
