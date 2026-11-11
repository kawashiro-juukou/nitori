/// The Satori client: a WebSocket gateway plus the HTTP API surface.
///
/// [NitoriClient] owns the gateway connection and the shared HTTP client;
/// [NitoriBot] represents one login and carries the `satori-platform` /
/// `satori-user-id` identity headers for every request it makes.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nitori_core/nitori_core.dart';

import 'gateway.dart';

/// Thrown when the server answers with a non-200 status.
class SatoriApiException implements Exception {
  SatoriApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'SatoriApiException: HTTP $statusCode $message';
}

/// Connects to a Satori server and exposes its bots and event stream.
class NitoriClient {
  NitoriClient({
    required this.baseUrl,
    this.token,
    http.Client? httpClient,
    int retryTimes = 6,
    Duration retryInterval = const Duration(seconds: 5),
    Duration retryLazy = const Duration(minutes: 1),
    Duration heartbeatInterval = const Duration(seconds: 10),
  })  : _http = httpClient ?? http.Client(),
        _gateway = Gateway(
          baseUrl: baseUrl,
          token: token,
          retryTimes: retryTimes,
          retryInterval: retryInterval,
          retryLazy: retryLazy,
          heartbeatInterval: heartbeatInterval,
        ) {
    _gateway.onReady = _handleReady;
    _gateway.onMeta = (urls) => proxyUrls = urls;
    _gateway.onStatusChanged = (status) => onStatusChanged?.call(status);
    _gateway.events.listen(_handleLoginEvent);
  }

  /// HTTP(S) base URL of the Satori server, e.g. `http://localhost:5140`.
  final String baseUrl;

  /// Access token sent as `Authorization: Bearer` and `IDENTIFY.body.token`.
  final String? token;

  /// Connection lifecycle of the WebSocket gateway.
  final Gateway _gateway;

  /// Shared HTTP client; inject one to control timeouts / TLS in tests.
  final http.Client _http;

  /// Bots resolved from READY and kept in sync by `login-*` events.
  final List<NitoriBot> bots = <NitoriBot>[];

  /// Proxy URLs advertised by the server, useful for proxying media.
  List<String> proxyUrls = const <String>[];

  /// Live event stream of the gateway.
  Stream<GatewayEvent> get events => _gateway.events;

  Status get status => _gateway.status;

  /// Fired whenever the connection status changes.
  void Function(Status status)? onStatusChanged;

  /// Connects to the gateway and keeps it alive until [stop].
  Future<void> start() => _gateway.start();

  /// Disconnects the gateway, keeping the HTTP client open.
  Future<void> stop() async {
    await _gateway.stop();
  }

  /// Disconnects and releases the shared HTTP client.
  Future<void> close() async {
    await _gateway.stop();
    _http.close();
  }

  void _handleReady(List<Login> logins, List<String> proxyUrls) {
    this.proxyUrls = proxyUrls;
    for (final login in logins) {
      _addBot(login);
    }
  }

  void _handleLoginEvent(GatewayEvent event) {
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

  /// Sends one API request and returns the decoded JSON response.
  ///
  /// Field names come from the [methods] registry; each Dart argument is keyed
  /// by the matching wire field and passed through [transformKey] so nested
  /// camelCase maps become snake_case on the wire.
  Future<dynamic> _request(
      NitoriBot bot, String key, List<Object?> args) async {
    final method = methods[key];
    if (method == null) throw StateError('unknown method: $key');

    final uri = Uri.parse('$baseUrl/v1/$key');
    if (method.isForm) {
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_headers(bot));
      for (var i = 0; i < args.length; i++) {
        final field = i == 0 ? 'file' : 'file${i + 1}';
        final blob = args[i];
        if (blob is List<int>) {
          request.files.add(http.MultipartFile.fromBytes(field, blob));
        } else if (blob is String) {
          request.files.add(http.MultipartFile.fromString(field, blob));
        } else {
          throw ArgumentError('unsupported upload blob: ${blob.runtimeType}');
        }
      }
      final streamed = await _http.send(request);
      return _decode(await http.Response.fromStream(streamed));
    }

    final payload = <String, dynamic>{};
    for (var i = 0; i < method.fields.length; i++) {
      final arg = args[i];
      if (arg == null) continue;
      final field = method.fields[i];
      payload[field] = field == 'referrer'
          ? arg
          : transformKey(arg, cashConvertCamelToSnake);
    }
    final response = await _http.post(uri,
        headers: _headers(bot), body: jsonEncode(payload));
    return _decode(response);
  }

  Map<String, String> _headers(NitoriBot bot) => <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
        'satori-platform': bot.platform,
        'satori-user-id': bot.userId,
        'content-type': 'application/json',
      };

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw SatoriApiException(response.statusCode, text);
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }
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

  Future<Pagination<Channel>> getChannelList(String guildId,
      {String? next}) async {
    final data =
        await client._request(this, 'channel.list', <Object?>[guildId, next]);
    return _pagination(data, Channel.fromJson);
  }

  Future<Channel> createChannel(
      String guildId, Map<String, dynamic> data) async {
    final result =
        await client._request(this, 'channel.create', <Object?>[guildId, data]);
    return Channel.fromJson(result as Map<String, dynamic>);
  }

  Future<void> updateChannel(
      String channelId, Map<String, dynamic> data) async {
    await client._request(this, 'channel.update', <Object?>[channelId, data]);
  }

  Future<void> deleteChannel(String channelId) async {
    await client._request(this, 'channel.delete', <Object?>[channelId]);
  }

  Future<void> muteChannel(String channelId,
      {String? guildId, bool? enable}) async {
    await client
        ._request(this, 'channel.mute', <Object?>[channelId, guildId, enable]);
  }

  // -- message --

  Future<List<Message>> createMessage(String channelId, String content,
      {dynamic referrer}) async {
    final data = await client._request(this, 'message.create', <Object?>[
      channelId,
      content,
      referrer,
    ]);
    return (data as List<dynamic>)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends a message and returns only the message IDs.
  ///
  /// Delegates to [createMessage] and extracts the IDs.
  Future<List<String>> sendMessage(String channelId, String content,
      {dynamic referrer, bool? linkPreview}) async {
    final created = await createMessage(channelId, content, referrer: referrer);
    return <String>[for (final message in created) message.id!];
  }

  Future<void> editMessage(
      String channelId, String messageId, String content) async {
    await client._request(
        this, 'message.update', <Object?>[channelId, messageId, content]);
  }

  Future<void> deleteMessage(String channelId, String messageId) async {
    await client._request(this, 'message.delete', <Object?>[
      channelId,
      messageId,
    ]);
  }

  Future<Message> getMessage(String channelId, String messageId) async {
    final data = await client._request(this, 'message.get', <Object?>[
      channelId,
      messageId,
    ]);
    return Message.fromJson(data as Map<String, dynamic>);
  }

  Future<BidiList<Message>> getMessageList(String channelId,
      {String? next, Direction? direction, int? limit, Order? order}) async {
    final data = await client._request(this, 'message.list', <Object?>[
      channelId,
      next,
      direction?.value,
      limit,
      order?.value,
    ]);
    return _bidiList(data, Message.fromJson);
  }

  // -- reaction --

  Future<void> createReaction(
      String channelId, String messageId, String emojiId) async {
    await client._request(this, 'reaction.create', <Object?>[
      channelId,
      messageId,
      emojiId,
    ]);
  }

  Future<void> deleteReaction(
      String channelId, String messageId, String emojiId,
      {String? userId}) async {
    await client._request(this, 'reaction.delete', <Object?>[
      channelId,
      messageId,
      emojiId,
      userId,
    ]);
  }

  Future<void> clearReaction(String channelId, String messageId,
      {String? emojiId}) async {
    await client._request(this, 'reaction.clear', <Object?>[
      channelId,
      messageId,
      emojiId,
    ]);
  }

  Future<Pagination<User>> getReactionList(
      String channelId, String messageId, String emojiId,
      {String? next}) async {
    final data = await client._request(this, 'reaction.list', <Object?>[
      channelId,
      messageId,
      emojiId,
      next,
    ]);
    return _pagination(data, User.fromJson);
  }

  // -- upload --

  Future<List<String>> createUpload(List<dynamic> blobs) async {
    final data =
        await client._request(this, 'upload.create', List<Object?>.of(blobs));
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

  Future<GuildMember> getGuildMember(String guildId, String userId) async {
    final data = await client._request(this, 'guild.member.get', <Object?>[
      guildId,
      userId,
    ]);
    return GuildMember.fromJson(data as Map<String, dynamic>);
  }

  Future<Pagination<GuildMember>> getGuildMemberList(String guildId,
      {String? next}) async {
    final data = await client
        ._request(this, 'guild.member.list', <Object?>[guildId, next]);
    return _pagination(data, GuildMember.fromJson);
  }

  Future<void> kickGuildMember(String guildId, String userId,
      {bool? permanent}) async {
    await client._request(this, 'guild.member.kick', <Object?>[
      guildId,
      userId,
      permanent,
    ]);
  }

  Future<void> muteGuildMember(String guildId, String userId,
      {int? duration, String? reason}) async {
    await client._request(this, 'guild.member.mute', <Object?>[
      guildId,
      userId,
      duration,
      reason,
    ]);
  }

  Future<void> setGuildMemberRole(
      String guildId, String userId, String roleId) async {
    await client._request(this, 'guild.member.role.set', <Object?>[
      guildId,
      userId,
      roleId,
    ]);
  }

  Future<void> unsetGuildMemberRole(
      String guildId, String userId, String roleId) async {
    await client._request(this, 'guild.member.role.unset', <Object?>[
      guildId,
      userId,
      roleId,
    ]);
  }

  Future<Pagination<GuildRole>> getGuildMemberRoleList(
      String guildId, String userId,
      {String? next}) async {
    final data =
        await client._request(this, 'guild.member.role.list', <Object?>[
      guildId,
      userId,
      next,
    ]);
    return _pagination(data, GuildRole.fromJson);
  }

  Future<Pagination<GuildRole>> getGuildRoleList(String guildId,
      {String? next}) async {
    final data = await client
        ._request(this, 'guild.role.list', <Object?>[guildId, next]);
    return _pagination(data, GuildRole.fromJson);
  }

  Future<GuildRole> createGuildRole(
      String guildId, Map<String, dynamic> data) async {
    final result = await client
        ._request(this, 'guild.role.create', <Object?>[guildId, data]);
    return GuildRole.fromJson(result as Map<String, dynamic>);
  }

  Future<void> updateGuildRole(
      String guildId, String roleId, Map<String, dynamic> data) async {
    await client._request(this, 'guild.role.update', <Object?>[
      guildId,
      roleId,
      data,
    ]);
  }

  Future<void> deleteGuildRole(String guildId, String roleId) async {
    await client
        ._request(this, 'guild.role.delete', <Object?>[guildId, roleId]);
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
  Future<List<String>> sendPrivateMessage(String userId, String content,
      {String? guildId, dynamic referrer, bool? linkPreview}) async {
    final channel = await createDirectChannel(userId, guildId: guildId);
    return sendMessage(channel.id, content,
        referrer: referrer, linkPreview: linkPreview);
  }

  Future<Pagination<Friend>> getFriendList({String? next}) async {
    final data = await client._request(this, 'friend.list', <Object?>[next]);
    return _pagination(data, Friend.fromJson);
  }

  Future<void> deleteFriend(String userId) async {
    await client._request(this, 'friend.delete', <Object?>[userId]);
  }

  Future<void> handleFriendRequest(String messageId, bool approve,
      {String? comment}) async {
    await client._request(this, 'friend.approve', <Object?>[
      messageId,
      approve,
      comment,
    ]);
  }

  Future<void> handleGuildRequest(String messageId, bool approve,
      {String? comment}) async {
    await client._request(this, 'guild.approve', <Object?>[
      messageId,
      approve,
      comment,
    ]);
  }

  Future<void> handleGuildMemberRequest(String messageId, bool approve,
      {String? comment}) async {
    await client._request(this, 'guild.member.approve', <Object?>[
      messageId,
      approve,
      comment,
    ]);
  }

  Pagination<T> _pagination<T>(
      dynamic json, T Function(Map<String, dynamic>) fromJson) {
    final map = json as Map<String, dynamic>;
    final data = (map['data'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
    return Pagination<T>(data, next: map['next'] as String?);
  }

  BidiList<T> _bidiList<T>(
      dynamic json, T Function(Map<String, dynamic>) fromJson) {
    final map = json as Map<String, dynamic>;
    final data = (map['data'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
    return BidiList<T>(data,
        prev: map['prev'] as String?, next: map['next'] as String?);
  }
}
