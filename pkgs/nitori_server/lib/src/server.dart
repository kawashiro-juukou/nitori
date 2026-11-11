/// Satori protocol server: the `/v1/<method>` HTTP API and `/v1/events`
/// WebSocket gateway.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nitori_core/nitori_core.dart';

import 'adapter.dart';

/// One connected gateway client.
class _GatewayClient {
  _GatewayClient(this.socket);

  final WebSocket socket;
  bool authorized = false;
}

/// An HTTP error returned to the caller.
class _HttpError implements Exception {
  _HttpError(this.statusCode, this.message);

  final int statusCode;
  final String message;
}

/// A multipart form part.
class _FormPart {
  _FormPart(this.name, this.data);

  final String name;
  final List<int> data;
}

/// Serves the Satori HTTP API and WebSocket gateway for [adapter].
class SatoriServer {
  SatoriServer({
    required this.adapter,
    this.token,
    this.resumeTimeout = const Duration(minutes: 5),
    this.maxRequestBodySize = 32 * 1024 * 1024,
  });

  /// Platform integration providing bots and events.
  final SatoriAdapter adapter;

  /// When set, HTTP requests need `Authorization: Bearer <token>` and gateways
  /// need the same value in the IDENTIFY body.
  final String? token;

  /// How long emitted events stay buffered for replay.
  final Duration resumeTimeout;

  /// Largest request body accepted, in bytes.
  final int maxRequestBodySize;

  final Set<_GatewayClient> _clients = <_GatewayClient>{};
  final List<Event> _buffer = <Event>[];

  int _sequence = 0;
  HttpServer? _server;
  StreamSubscription<Event>? _subscription;

  /// Binds to [address] and [port], then starts serving.
  Future<HttpServer> bind({
    Object? address,
    int port = 5140,
  }) async {
    final server =
        await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    await serve(server);
    return server;
  }

  /// Serves requests on an already bound [server].
  Future<void> serve(HttpServer server) async {
    _server = server;
    _subscription ??= adapter.events.listen(_publish);
    server.listen(_handleRequest);
  }

  /// Closes the gateway clients, the event subscription and the server.
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    for (final client in _clients.toList()) {
      await client.socket.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.uri.path == '/v1/events') {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          await _sendError(request, HttpStatus.upgradeRequired,
              'WebSocket upgrade required');
          return;
        }
        _attach(await WebSocketTransformer.upgrade(request));
        return;
      }

      if (!request.uri.path.startsWith('/v1/')) {
        await _sendError(request, HttpStatus.notFound, 'Not Found');
        return;
      }

      final key = request.uri.path.substring('/v1/'.length);
      if (!methods.containsKey(key)) {
        await _sendError(request, HttpStatus.notFound, 'method not found');
        return;
      }
      if (request.method != 'POST') {
        await _sendError(request, HttpStatus.methodNotAllowed,
            'Please use POST method to send requests.');
        return;
      }
      await _handlePost(request, key);
    } catch (_) {
      await _sendError(
          request, HttpStatus.internalServerError, 'Internal Server Error');
    }
  }

  Future<void> _handlePost(HttpRequest request, String key) async {
    final response = request.response;
    try {
      _checkAuth(request);
      final bot = _selectBot(request);
      final method = methods[key]!;
      Object? result;

      if (method.isForm) {
        final parts = _parseMultipart(
            request.headers.contentType?.toString(), await _readBytes(request));
        final urls = await bot
            .createUpload(<dynamic>[for (final part in parts) part.data]);
        result = <String, dynamic>{
          for (var i = 0; i < parts.length; i++) parts[i].name: urls[i],
        };
      } else {
        final body = _decodeJson(await _readBytes(request));
        result = await _invoke(bot, key, body);
      }

      response.statusCode = HttpStatus.ok;
      if (result != null) {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(result));
      }
    } on _HttpError catch (error) {
      response.statusCode = error.statusCode;
      response.write(error.message);
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
      response.write('Internal Server Error');
    } finally {
      await response.close();
    }
  }

  void _checkAuth(HttpRequest request) {
    if (token == null) return;
    if (request.headers.value('authorization') != 'Bearer $token') {
      throw _HttpError(HttpStatus.forbidden, 'invalid token');
    }
  }

  SatoriBot _selectBot(HttpRequest request) {
    final platform = request.headers.value('satori-platform');
    final userId = request.headers.value('satori-user-id');
    for (final bot in adapter.bots) {
      if (bot.platform == platform && bot.userId == userId) return bot;
    }
    throw _HttpError(HttpStatus.forbidden, 'login not found');
  }

  Future<Object?> _invoke(
      SatoriBot bot, String key, Map<String, dynamic> body) async {
    switch (key) {
      case 'channel.get':
        return (await bot.getChannel(_string(body, 'channel_id'))).toJson();
      case 'channel.list':
        return (await bot.getChannelList(_string(body, 'guild_id'),
                next: _optionalString(body, 'next')))
            .toJson();
      case 'channel.create':
        return (await bot.createChannel(
                _string(body, 'guild_id'), _map(body, 'data')))
            .toJson();
      case 'channel.update':
        await bot.updateChannel(
            _string(body, 'channel_id'), _map(body, 'data'));
        return null;
      case 'channel.delete':
        await bot.deleteChannel(_string(body, 'channel_id'));
        return null;
      case 'channel.mute':
        await bot.muteChannel(_string(body, 'channel_id'),
            guildId: _optionalString(body, 'guild_id'),
            enable: _optionalBool(body, 'enable'));
        return null;
      case 'message.create':
        final messages = await bot.createMessage(
            _string(body, 'channel_id'), _string(body, 'content'),
            referrer: body['referrer']);
        return <Object?>[for (final message in messages) message.toJson()];
      case 'message.update':
        await bot.editMessage(_string(body, 'channel_id'),
            _string(body, 'message_id'), _string(body, 'content'));
        return null;
      case 'message.delete':
        await bot.deleteMessage(
            _string(body, 'channel_id'), _string(body, 'message_id'));
        return null;
      case 'message.get':
        return (await bot.getMessage(
                _string(body, 'channel_id'), _string(body, 'message_id')))
            .toJson();
      case 'message.list':
        return (await bot.getMessageList(_string(body, 'channel_id'),
                next: _optionalString(body, 'next'),
                direction: _direction(body['direction']),
                limit: _optionalInt(body, 'limit'),
                order: _order(body['order'])))
            .toJson();
      case 'reaction.create':
        await bot.createReaction(_string(body, 'channel_id'),
            _string(body, 'message_id'), _string(body, 'emoji_id'));
        return null;
      case 'reaction.delete':
        await bot.deleteReaction(_string(body, 'channel_id'),
            _string(body, 'message_id'), _string(body, 'emoji_id'),
            userId: _optionalString(body, 'user_id'));
        return null;
      case 'reaction.clear':
        await bot.clearReaction(
            _string(body, 'channel_id'), _string(body, 'message_id'),
            emojiId: _optionalString(body, 'emoji_id'));
        return null;
      case 'reaction.list':
        return (await bot.getReactionList(_string(body, 'channel_id'),
                _string(body, 'message_id'), _string(body, 'emoji_id'),
                next: _optionalString(body, 'next')))
            .toJson();
      case 'guild.get':
        return (await bot.getGuild(_string(body, 'guild_id'))).toJson();
      case 'guild.list':
        return (await bot.getGuildList(next: _optionalString(body, 'next')))
            .toJson();
      case 'guild.member.get':
        return (await bot.getGuildMember(
                _string(body, 'guild_id'), _string(body, 'user_id')))
            .toJson();
      case 'guild.member.list':
        return (await bot.getGuildMemberList(_string(body, 'guild_id'),
                next: _optionalString(body, 'next')))
            .toJson();
      case 'guild.member.kick':
        await bot.kickGuildMember(
            _string(body, 'guild_id'), _string(body, 'user_id'),
            permanent: _optionalBool(body, 'permanent'));
        return null;
      case 'guild.member.mute':
        await bot.muteGuildMember(
            _string(body, 'guild_id'), _string(body, 'user_id'),
            duration: _optionalInt(body, 'duration'),
            reason: _optionalString(body, 'reason'));
        return null;
      case 'guild.member.role.set':
        await bot.setGuildMemberRole(_string(body, 'guild_id'),
            _string(body, 'user_id'), _string(body, 'role_id'));
        return null;
      case 'guild.member.role.unset':
        await bot.unsetGuildMemberRole(_string(body, 'guild_id'),
            _string(body, 'user_id'), _string(body, 'role_id'));
        return null;
      case 'guild.member.role.list':
        return (await bot.getGuildMemberRoleList(
                _string(body, 'guild_id'), _string(body, 'user_id'),
                next: _optionalString(body, 'next')))
            .toJson();
      case 'guild.role.list':
        return (await bot.getGuildRoleList(_string(body, 'guild_id'),
                next: _optionalString(body, 'next')))
            .toJson();
      case 'guild.role.create':
        final data = _map(body, 'data');
        return (await bot.createGuildRole(_string(body, 'guild_id'),
                name: _optionalString(data, 'name'),
                color: _optionalInt(data, 'color'),
                position: _optionalInt(data, 'position'),
                permissions: _optionalBigInt(data, 'permissions'),
                hoist: _optionalBool(data, 'hoist'),
                mentionable: _optionalBool(data, 'mentionable')))
            .toJson();
      case 'guild.role.update':
        final data = _map(body, 'data');
        await bot.updateGuildRole(
            _string(body, 'guild_id'), _string(body, 'role_id'),
            name: _optionalString(data, 'name'),
            color: _optionalInt(data, 'color'),
            position: _optionalInt(data, 'position'),
            permissions: _optionalBigInt(data, 'permissions'),
            hoist: _optionalBool(data, 'hoist'),
            mentionable: _optionalBool(data, 'mentionable'));
        return null;
      case 'guild.role.delete':
        await bot.deleteGuildRole(
            _string(body, 'guild_id'), _string(body, 'role_id'));
        return null;
      case 'login.get':
        return (await bot.getLogin()).toJson();
      case 'user.get':
        return (await bot.getUser(_string(body, 'user_id'))).toJson();
      case 'user.channel.create':
        return (await bot.createDirectChannel(_string(body, 'user_id'),
                guildId: _optionalString(body, 'guild_id')))
            .toJson();
      case 'friend.list':
        return (await bot.getFriendList(next: _optionalString(body, 'next')))
            .toJson();
      case 'friend.delete':
        await bot.deleteFriend(_string(body, 'user_id'));
        return null;
      case 'friend.approve':
        await bot.handleFriendRequest(_string(body, 'message_id'),
            _optionalBool(body, 'approve') ?? false,
            comment: _optionalString(body, 'comment'));
        return null;
      case 'guild.approve':
        await bot.handleGuildRequest(_string(body, 'message_id'),
            _optionalBool(body, 'approve') ?? false,
            comment: _optionalString(body, 'comment'));
        return null;
      case 'guild.member.approve':
        await bot.handleGuildMemberRequest(_string(body, 'message_id'),
            _optionalBool(body, 'approve') ?? false,
            comment: _optionalString(body, 'comment'));
        return null;
      default:
        throw _HttpError(HttpStatus.notFound, 'method not found');
    }
  }

  Future<List<int>> _readBytes(HttpRequest request) async {
    final declared = request.headers.contentLength;
    if (declared > maxRequestBodySize) {
      throw _HttpError(
          HttpStatus.requestEntityTooLarge, 'request body too large');
    }
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > maxRequestBodySize) {
        throw _HttpError(
            HttpStatus.requestEntityTooLarge, 'request body too large');
      }
    }
    return bytes;
  }

  Map<String, dynamic> _decodeJson(List<int> bytes) {
    if (bytes.isEmpty) return <String, dynamic>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw _HttpError(HttpStatus.badRequest, 'invalid request body');
    }
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw _HttpError(HttpStatus.badRequest, 'invalid request body');
  }

  String? _optionalString(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value == null) return null;
    if (value is String) return value;
    throw _HttpError(HttpStatus.badRequest, 'invalid $key');
  }

  String _string(Map<String, dynamic> body, String key) =>
      _optionalString(body, key) ??
      (throw _HttpError(HttpStatus.badRequest, 'missing $key'));

  Map<String, dynamic> _map(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw _HttpError(HttpStatus.badRequest, 'missing $key');
  }

  int? _optionalInt(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw _HttpError(HttpStatus.badRequest, 'invalid $key');
  }

  bool? _optionalBool(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value == null) return null;
    if (value is bool) return value;
    throw _HttpError(HttpStatus.badRequest, 'invalid $key');
  }

  BigInt? _optionalBigInt(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value == null) return null;
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) {
      final parsed = BigInt.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw _HttpError(HttpStatus.badRequest, 'invalid $key');
  }

  Direction? _direction(Object? value) {
    if (value == null) return null;
    for (final direction in Direction.values) {
      if (direction.value == value) return direction;
    }
    throw _HttpError(HttpStatus.badRequest, 'invalid direction');
  }

  Order? _order(Object? value) {
    if (value == null) return null;
    for (final order in Order.values) {
      if (order.value == value) return order;
    }
    throw _HttpError(HttpStatus.badRequest, 'invalid order');
  }

  List<_FormPart> _parseMultipart(String? contentType, List<int> body) {
    final match =
        RegExp(r'boundary="?([^";]+)"?').firstMatch(contentType ?? '');
    if (match == null) {
      throw _HttpError(HttpStatus.badRequest, 'missing multipart boundary');
    }

    final boundary = utf8.encode('--${match.group(1)}');
    final headerEnd = utf8.encode('\r\n\r\n');
    final parts = <_FormPart>[];
    var position = _indexOf(body, boundary, 0);

    while (position != -1) {
      final start = position + boundary.length;
      if (start + 1 < body.length &&
          body[start] == 45 &&
          body[start + 1] == 45) {
        break;
      }
      final headersEnd = _indexOf(body, headerEnd, start);
      if (headersEnd == -1) break;
      final headers =
          utf8.decode(body.sublist(start, headersEnd), allowMalformed: true);
      final next = _indexOf(body, boundary, headersEnd + headerEnd.length);
      if (next == -1) break;

      var contentEnd = next;
      if (contentEnd >= 2 &&
          body[contentEnd - 2] == 13 &&
          body[contentEnd - 1] == 10) {
        contentEnd -= 2;
      }
      final name = RegExp(r'name="([^"]*)"').firstMatch(headers)?.group(1) ??
          'file${parts.length + 1}';
      parts.add(_FormPart(
          name, body.sublist(headersEnd + headerEnd.length, contentEnd)));
      position = next;
    }
    return parts;
  }

  int _indexOf(List<int> source, List<int> pattern, int start) {
    for (var i = start; i <= source.length - pattern.length; i++) {
      var match = true;
      for (var j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  void _attach(WebSocket socket) {
    final client = _GatewayClient(socket);
    _clients.add(client);
    _trySend(socket, Opcode.meta, <String, dynamic>{
      'proxy_urls': adapter.proxyUrls,
    });
    socket.listen(
      (data) => _handleFrame(client, data),
      onDone: () => _clients.remove(client),
      onError: (Object _) => _clients.remove(client),
      cancelOnError: true,
    );
  }

  void _handleFrame(_GatewayClient client, dynamic data) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(data as String);
      payload = Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      unawaited(client.socket.close(4000, 'invalid message'));
      return;
    }

    final body = payload['body'];
    final identify =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

    switch (payload['op']) {
      // Opcode.identify
      case 3:
        if (token != null && identify['token'] != token) {
          unawaited(client.socket.close(4004, 'invalid token'));
          return;
        }
        client.authorized = true;
        final meta = Meta(
          logins: <Login>[for (final bot in adapter.bots) bot.login],
          proxyUrls: adapter.proxyUrls,
        );
        _trySend(client.socket, Opcode.ready, meta.toJson());
        final sn = identify['sn'];
        if (sn is int) _replay(client, sn);
        break;
      // Opcode.ping
      case 1:
        _trySend(client.socket, Opcode.pong, <String, dynamic>{});
        break;
    }
  }

  void _replay(_GatewayClient client, int sn) {
    _prune(DateTime.now().millisecondsSinceEpoch);
    for (final event in _buffer) {
      if ((event.sn ?? 0) <= sn) continue;
      _trySend(client.socket, Opcode.event, event.toJson());
    }
  }

  void _publish(Event event) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _prune(now);
    event.sn = ++_sequence;
    event.timestamp ??= now;
    _buffer.add(event);

    final body = event.toJson();
    for (final client in _clients.toList()) {
      if (!client.authorized) continue;
      if (!_trySend(client.socket, Opcode.event, body)) {
        _clients.remove(client);
      }
    }
  }

  void _prune(int now) {
    final cutoff = now - resumeTimeout.inMilliseconds;
    while (_buffer.isNotEmpty && (_buffer.first.timestamp ?? 0) < cutoff) {
      _buffer.removeAt(0);
    }
  }

  void _send(WebSocket socket, Opcode opcode, Object body) {
    socket.add(jsonEncode(<String, dynamic>{
      'op': opcode.value,
      'body': body,
    }));
  }

  bool _trySend(WebSocket socket, Opcode opcode, Object body) {
    try {
      _send(socket, opcode, body);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendError(
      HttpRequest request, int statusCode, String message) async {
    try {
      request.response
        ..statusCode = statusCode
        ..write(message);
      await request.response.close();
    } catch (_) {
      return;
    }
  }
}
