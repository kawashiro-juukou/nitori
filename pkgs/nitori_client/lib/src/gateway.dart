/// WebSocket gateway of the Satori protocol.
///
/// Implements the client side of `/v1/events`: IDENTIFY with token and resume
/// sequence, 10s PING heartbeats, and automatic reconnection following the
/// `retryTimes` / `retryInterval` / `retryLazy` semantics of the upstream
/// `WsClientBase` (`packages/core/src/adapter.ts`).
library;

import 'dart:async';
import 'dart:convert';

import 'package:nitori_core/nitori_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One EVENT frame received from the gateway.
///
/// [data] is the event body with keys rewritten to camelCase, ready for
/// consumers. [raw] keeps the untouched snake_case payload so nested model
/// objects (which expect wire keys) can still be parsed from it.
///
/// The core package only carries a placeholder `Event` model today; replace
/// the map payload with a typed model once it lands.
class GatewayEvent {
  GatewayEvent(this.raw)
    : data = transformKey(raw, cashConvertSnakeToCamel) as Map<String, dynamic>;

  /// Original snake_case event body.
  final Map<String, dynamic> raw;

  /// Event body with camelCase keys.
  final Map<String, dynamic> data;

  /// Event sequence number; the gateway replays from here on reconnect.
  int? get sn => raw['sn'] as int?;

  /// Event type, e.g. `message-created` or `login-added`.
  String? get type => raw['type'] as String?;

  /// The login this event belongs to, when present.
  Login? get login => raw['login'] == null
      ? null
      : Login.fromJson(raw['login'] as Map<String, dynamic>);
}

/// Thrown when the gateway gives up reconnecting after [Gateway.retryTimes]
/// failed initial attempts.
class GatewayException implements Exception {
  GatewayException(this.message);

  final String message;

  @override
  String toString() => 'GatewayException: $message';
}

/// A single `/v1/events` connection lifecycle.
class Gateway {
  Gateway({
    required this.baseUrl,
    this.token,
    this.retryTimes = 6,
    this.retryInterval = const Duration(seconds: 5),
    this.retryLazy = const Duration(minutes: 1),
    this.heartbeatInterval = const Duration(seconds: 10),
  });

  /// HTTP(S) base URL of the Satori server; the WebSocket endpoint is derived
  /// by swapping the scheme and appending `/v1/events`.
  final String baseUrl;

  /// Access token, sent as `IDENTIFY.body.token`.
  final String? token;

  /// Initial-connection retry budget; after this many failures the gateway
  /// goes offline instead of retrying.
  final int retryTimes;

  /// Retry interval while the retry budget is not exhausted.
  final Duration retryInterval;

  /// Retry interval after an established connection drops and the retry
  /// budget is exhausted.
  final Duration retryLazy;

  /// How often a PING is sent while connected.
  final Duration heartbeatInterval;

  /// Sequence number of the last EVENT received; carried by the next IDENTIFY
  /// so the server replays buffered events after `sn`.
  int? sequence;

  /// Proxy URLs advertised by the READY / META payloads.
  List<String> proxyUrls = const <String>[];

  Status get status => _status;
  Status _status = Status.offline;

  /// Fired whenever [status] changes.
  void Function(Status status)? onStatusChanged;

  /// Fired once per READY with the resolved logins and proxy URLs.
  void Function(List<Login> logins, List<String> proxyUrls)? onReady;

  /// Fired on META with the updated proxy URLs.
  void Function(List<String> proxyUrls)? onMeta;

  final StreamController<GatewayEvent> _events =
      StreamController<GatewayEvent>.broadcast();

  /// Stream of EVENT frames (including `login-*` ones).
  Stream<GatewayEvent> get events => _events.stream;

  bool _running = false;
  int _connectionId = 0;
  int _retryCount = 0;
  Timer? _retryTimer;
  Timer? _heartbeat;
  WebSocketChannel? _socket;

  /// Connects to the gateway and keeps it alive until [stop].
  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _connect(initial: true);
  }

  /// Closes the connection and cancels pending reconnects.
  Future<void> stop() async {
    _running = false;
    _connectionId++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    await _socket?.sink.close();
    _socket = null;
    _setStatus(Status.disconnect);
  }

  Future<void> _connect({bool initial = false}) async {
    final connectionId = ++_connectionId;
    final socket = WebSocketChannel.connect(_wsUri());
    try {
      await socket.ready;
    } catch (error) {
      if (!_running || connectionId != _connectionId) return;
      _scheduleReconnect(connectionId, initial, 'failed to connect: $error');
      return;
    }
    if (!_running || connectionId != _connectionId) {
      socket.sink.close();
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
    _socket = socket;
    _setStatus(Status.online);

    socket.stream.listen(
      _handleFrame,
      onError: (Object error, StackTrace stackTrace) {
        _heartbeat?.cancel();
        _scheduleReconnect(connectionId, false, 'connection error: $error');
      },
      onDone: () {
        _heartbeat?.cancel();
        _scheduleReconnect(connectionId, false, 'connection closed');
      },
    );

    socket.sink.add(_identify());
    _heartbeat = Timer.periodic(heartbeatInterval, (_) {
      socket.sink.add(_ping());
    });
  }

  /// Schedules the next attempt; mirrors `WsClientBase.reconnect`.
  void _scheduleReconnect(int connectionId, bool initial, String message) {
    if (!_running || connectionId != _connectionId) return;

    var timeout = retryInterval;
    if (_retryCount >= retryTimes) {
      if (initial) {
        _setStatus(Status.offline);
        _events.addError(GatewayException(message));
        return;
      }
      timeout = retryLazy;
    }

    _retryCount++;
    _setStatus(Status.reconnect);
    _retryTimer?.cancel();
    _retryTimer = Timer(timeout, () {
      if (!_running || connectionId != _connectionId) return;
      _connect();
    });
  }

  void _handleFrame(dynamic frame) {
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(frame as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final body = parsed['body'];
    if (body is! Map<String, dynamic>) return;

    print('Gateway._handleFrame: op=${parsed['op']}, body.keys=${body.keys}');

    switch (parsed['op'] as int?) {
      // Opcode.event (0)
      case 0:
        sequence = body['sn'] as int? ?? sequence;
        _events.add(GatewayEvent(body));
      // Opcode.ready (4)
      case 4:
        proxyUrls = List<String>.from(
          body['proxy_urls'] as List<dynamic>? ?? const <dynamic>[],
        );
        final logins = <Login>[
          for (final json
              in body['logins'] as List<dynamic>? ?? const <dynamic>[])
            Login.fromJson(json as Map<String, dynamic>),
        ];
        print('Gateway: READY with ${logins.length} logins');
        onReady?.call(logins, proxyUrls);
      // Opcode.meta (5)
      case 5:
        proxyUrls = List<String>.from(
          body['proxy_urls'] as List<dynamic>? ?? const <dynamic>[],
        );
        onMeta?.call(proxyUrls);
      // Opcode.pong (2)
      case 2:
        break;
    }
  }

  String _identify() => jsonEncode(<String, dynamic>{
    'op': Opcode.identify.value,
    'body': <String, dynamic>{
      if (token != null) 'token': token,
      if (sequence != null) 'sn': sequence,
    },
  });

  String _ping() => jsonEncode(<String, dynamic>{
    'op': Opcode.ping.value,
    'body': <String, dynamic>{},
  });

  Uri _wsUri() {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    var path = uri.path;
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri.parse('$scheme://${uri.authority}$path/v1/events');
  }

  void _setStatus(Status status) {
    if (_status == status) return;
    _status = status;
    onStatusChanged?.call(status);
  }
}
