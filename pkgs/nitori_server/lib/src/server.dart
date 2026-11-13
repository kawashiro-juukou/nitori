/// Satori protocol server: the `/v1/<method>` HTTP API and `/v1/events`
/// WebSocket gateway.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';
import 'package:nitori_core/nitori_core.dart';

import 'adapter.dart';
import 'rate_limiter.dart';

/// Constant-time string equality check to avoid timing side-channels.
bool _constantTimeEquals(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  if (aBytes.length != bBytes.length) return false;
  var diff = 0;
  for (var i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff == 0;
}

/// One [Event] held for replay, stamped with when this server enqueued it.
class _BufferedEvent {
  _BufferedEvent(this.event, this.enqueuedAt);

  final Event event;
  final int enqueuedAt;
}

/// One connected gateway client.
class _GatewayClient {
  _GatewayClient(this.socket, this.remoteAddress);

  final WebSocket socket;
  final String? remoteAddress;
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
    this.maxBufferSize = 1000,
    this.httpRateLimit,
    this.wsConnectRateLimit,
    this.wsEventRateLimit,
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

  /// Largest number of events kept in the replay buffer.
  final int maxBufferSize;

  /// Rate limit configuration for HTTP API requests (`/v1/*`).
  final RateLimiterConfig? httpRateLimit;

  /// Rate limit configuration for WebSocket connections (IDENTIFY).
  final RateLimiterConfig? wsConnectRateLimit;

  /// Rate limit configuration for WebSocket event frames (upstream).
  final RateLimiterConfig? wsEventRateLimit;

  final Set<_GatewayClient> _clients = <_GatewayClient>{};
  final ListQueue<_BufferedEvent> _buffer = ListQueue<_BufferedEvent>();

  late final RateLimiter? _httpRateLimiter =
      httpRateLimit != null ? RateLimiter(httpRateLimit!) : null;
  late final RateLimiter? _wsConnectRateLimiter =
      wsConnectRateLimit != null ? RateLimiter(wsConnectRateLimit!) : null;
  late final RateLimiter? _wsEventRateLimiter =
      wsEventRateLimit != null ? RateLimiter(wsEventRateLimit!) : null;

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
    _subscription ??= adapter.events.listen(
      _publish,
      onError: _report,
    );
    server.listen(_handleRequest);
  }

  /// Closes the gateway clients, the event subscription and the server.
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    // Close each socket individually, collecting any errors to report after
    // all sockets have been attempted. This ensures the server socket is
    // always closed while not silently swallowing failures.
    final errors = <Object>[];
    for (final client in _clients) {
      try {
        await client.socket.close();
      } catch (e) {
        errors.add(e);
      }
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    if (errors.isNotEmpty) {
      _report(StateError('errors closing ${errors.length} client socket(s)'),
          StackTrace.current);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      // HTTP rate limiting check (applies to all /v1/* endpoints)
      int? httpRetryAfter;
      try {
        httpRetryAfter = _httpRateLimiter?.checkHttp(request);
      } catch (e, st) {
        _report(e, st);
      }
      if (httpRetryAfter != null) {
        await _sendRateLimitError(request, httpRetryAfter);
        return;
      }

      if (request.uri.path == '/v1/events') {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          await _sendError(request, HttpStatus.upgradeRequired,
              'WebSocket upgrade required');
          return;
        }
        _attach(await WebSocketTransformer.upgrade(request),
            remoteAddress: request.connectionInfo?.remoteAddress.address);
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

  Future<void> _sendRateLimitError(
      HttpRequest request, int retryAfterMs) async {
    try {
      final seconds = (retryAfterMs / 1000).ceil();
      request.response
        ..statusCode = HttpStatus.tooManyRequests
        ..headers.set('Retry-After', seconds.toString())
        ..write('Too Many Requests');
      await request.response.close();
    } catch (_) {
      return;
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
        final parts = await _parseMultipart(
            request.headers.contentType?.toString(), await _readBytes(request));
        // Detect duplicate part names before building the result map.
        final seenNames = <String>{};
        for (final part in parts) {
          if (!seenNames.add(part.name)) {
            throw _HttpError(
                HttpStatus.badRequest, 'duplicate part name: ${part.name}');
          }
        }
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
    } on UnimplementedError {
      // An integration that does not implement a method answers 404, not 500.
      response.statusCode = HttpStatus.notFound;
      response.write('method not supported');
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
      response.write('Internal Server Error');
    } finally {
      await response.close();
    }
  }

  void _checkAuth(HttpRequest request) {
    if (token == null) return;
    final header = request.headers.value('authorization');
    if (header == null ||
        !header.startsWith('Bearer ') ||
        !_constantTimeEquals(header.substring('Bearer '.length), token!)) {
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
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
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

  Future<List<_FormPart>> _parseMultipart(
      String? contentType, List<int> body) async {
    if (contentType == null) {
      throw _HttpError(HttpStatus.badRequest, 'missing multipart content type');
    }
    final boundary = ContentType.parse(contentType).parameters['boundary'];
    if (boundary == null) {
      throw _HttpError(HttpStatus.badRequest, 'missing multipart boundary');
    }

    final parts = <_FormPart>[];
    final stream =
        MimeMultipartTransformer(boundary).bind(Stream.fromIterable([body]));

    // Use runZonedGuarded to catch errors from microtasks during stream subscription.
    final completer = Completer<void>();
    StreamSubscription<MimeMultipart>? subscription;
    await runZonedGuarded(() async {
      subscription = stream.listen(
        (part) async {
          final name = _partName(part, parts.length + 1);
          final data = <int>[];
          try {
            await for (final chunk in part) {
              data.addAll(chunk);
            }
          } on Object catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(_HttpError(
                  HttpStatus.badRequest, 'invalid multipart body: $e'));
            }
            await subscription?.cancel();
            return;
          }
          parts.add(_FormPart(name, data));
        },
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) {
            completer.completeError(_HttpError(
                HttpStatus.badRequest, 'invalid multipart body: $e'));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );
    }, (Object e, StackTrace st) {
      // Catch synchronous errors during listen() call.
      if (!completer.isCompleted) {
        completer.completeError(
            _HttpError(HttpStatus.badRequest, 'invalid multipart body: $e'));
      }
    });

    // Wait for completion and propagate any error.
    try {
      await completer.future;
    } finally {
      await subscription?.cancel();
    }
    return parts;
  }

  // The wire name is what the response maps upload URLs back onto.
  String _partName(MimeMultipart part, int index) {
    final disposition = part.headers['content-disposition'];
    if (disposition == null) return 'file$index';
    final headerValue = HeaderValue.parse(disposition);
    return headerValue.parameters['name'] ?? 'file$index';
  }

  void _attach(WebSocket socket, {String? remoteAddress}) {
    final client = _GatewayClient(socket, remoteAddress);
    _clients.add(client);
    // Pings reap sockets whose peer vanished without closing.
    socket.pingInterval = const Duration(seconds: 30);
    _trySend(socket, Opcode.meta, <String, dynamic>{
      'proxy_urls': adapter.proxyUrls,
    });
    socket.listen(
      (data) => _handleFrame(client, data),
      onDone: () => _drop(client),
      onError: (Object _) => _drop(client),
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

    // WS event rate limiting check (for any upstream frame from authorized client)
    if (client.authorized && _wsEventRateLimiter != null) {
      int? wsEventRetryAfter;
      try {
        final ip = client.remoteAddress ?? 'unknown';
        wsEventRetryAfter = _wsEventRateLimiter.checkWsEvent(ip);
      } catch (e, st) {
        _report(e, st);
      }
      if (wsEventRetryAfter != null) {
        unawaited(client.socket.close(4029, 'rate limited'));
        return;
      }
    }

    final body = payload['body'];
    final identify =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

    switch (payload['op']) {
      // Opcode.identify
      case 3:
        // WS connection rate limiting check
        int? wsConnectRetryAfter;
        try {
          wsConnectRetryAfter = _wsConnectRateLimiter?.checkWsConnect(identify);
        } catch (e, st) {
          _report(e, st);
        }
        if (wsConnectRetryAfter != null) {
          unawaited(client.socket.close(4029, 'rate limited'));
          return;
        }

        if (token != null) {
          final provided = identify['token'];
          if (provided is! String || !_constantTimeEquals(provided, token!)) {
            unawaited(client.socket.close(4004, 'invalid token'));
            return;
          }
        }
        client.authorized = true;
        final meta = Meta(
          logins: <Login>[for (final bot in adapter.bots) bot.login],
          proxyUrls: adapter.proxyUrls,
        );
        _trySend(client.socket, Opcode.ready, meta.toJson());
        final sn = identify['sn'];
        if (sn is int && sn > 0) _replay(client, sn);
        break;
      // Opcode.ping
      case 1:
        _trySend(client.socket, Opcode.pong, <String, dynamic>{});
        break;
    }
  }

  void _replay(_GatewayClient client, int sn) {
    _prune(DateTime.now().millisecondsSinceEpoch);
    for (final buffered in _buffer) {
      if ((buffered.event.sn ?? 0) <= sn) continue;
      _trySend(client.socket, Opcode.event, buffered.event.toJson());
    }
  }

  void _publish(Event event) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _prune(now);

    // Use deepCopy to isolate nested objects (login, channel, guild, message,
    // etc.) so adapter mutations after emit don't affect the replay buffer.
    final buffered = event.deepCopy()
      ..sn = ++_sequence
      ..timestamp = event.timestamp ?? now;
    _applyEventAliases(buffered);
    if (!_isLoginEvent(buffered.type)) {
      _buffer.add(_BufferedEvent(buffered, now));
      while (_buffer.length > maxBufferSize) {
        _buffer.removeFirst();
      }
    }

    final String encoded;
    try {
      encoded = jsonEncode(<String, dynamic>{
        'op': Opcode.event.value,
        'body': buffered.toJson(),
      });
    } catch (error, stackTrace) {
      // A single unserializable event must not cost every client its
      // connection.
      _report(error, stackTrace);
      return;
    }

    for (final client in _clients.toList()) {
      if (!client.authorized) continue;
      _write(client.socket, encoded);
    }
  }

  // Session resume never replays login events.
  bool _isLoginEvent(String type) =>
      type == 'login-added' ||
      type == 'login-updated' ||
      type == 'login-removed';

  // An adapter emitting any member of an alias group means the whole group, so
  // the canonical (first) name replaces the emitted one on the wire.
  void _applyEventAliases(Event event) {
    for (final aliases in eventAliases) {
      if (!aliases.contains(event.type)) continue;
      event.type = aliases.first;
      return;
    }
  }

  void _drop(_GatewayClient client) {
    _clients.remove(client);
    unawaited(client.socket.close(1001, 'connection lost'));
  }

  // Reports a failure the protocol has no channel for: an adapter's event
  // stream erroring, or one event that cannot be encoded.
  void _report(Object error, StackTrace stackTrace) {
    stderr.writeln('nitori_server: ${error.runtimeType}: $error');
    stderr.writeln(stackTrace);
  }

  // Ages out by when the server enqueued the event, never by the timestamp the
  // adapter chose for it.
  void _prune(int now) {
    final cutoff = now - resumeTimeout.inMilliseconds;
    while (_buffer.isNotEmpty && _buffer.first.enqueuedAt < cutoff) {
      _buffer.removeFirst();
    }
  }

  void _send(WebSocket socket, Opcode opcode, Object body) {
    _write(
        socket,
        jsonEncode(<String, dynamic>{
          'op': opcode.value,
          'body': body,
        }));
  }

  void _write(WebSocket socket, String encoded) {
    socket.add(encoded);
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
