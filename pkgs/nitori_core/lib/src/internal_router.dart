/// Path-pattern router for internal HTTP endpoints, mirroring the upstream
/// `@satorijs/core` `InternalRouter` (`packages/core/src/internal.ts`).
library;

/// Callback invoked by a matching [InternalRoute]; [B] is the bot type the
/// router hands back unchanged.
typedef InternalRouteCallback<B> =
    Future<InternalResponse> Function(InternalRequest request, B bot);

/// Framework-neutral inbound request seen by [InternalRouter.handle].
class InternalRequest {
  InternalRequest({
    required this.method,
    required this.path,
    Map<String, String>? params,
    Map<String, String>? query,
    Map<String, String>? headers,
    this.body,
  }) : params = params ?? const <String, String>{},
       query = query ?? const <String, String>{},
       headers = headers ?? const <String, String>{};

  /// HTTP method (`GET`, `POST`, ...).
  ///
  /// The router itself never filters on it; method checks belong inside the
  /// callback, which is what upstream routes do as well. The caller decides
  /// 404/405 from [InternalRouter.handle] returning null or the callback's
  /// response.
  final String method;

  /// Request path without the query string; the pattern is matched against it.
  final String path;

  /// Path parameters extracted by the matched pattern; empty until
  /// [InternalRouter.handle] runs, which fills them via [withParams].
  final Map<String, String> params;

  /// Query parameters with lower-cased names as given by the caller; when a
  /// key repeats on the wire the caller keeps the last value.
  final Map<String, String> query;

  /// Header names lower-cased.
  final Map<String, String> headers;

  /// Raw body bytes; null when the request carried no body.
  final List<int>? body;

  /// Copy of this request with the matched pattern's [params] filled in.
  InternalRequest withParams(Map<String, String> params) => InternalRequest(
    method: method,
    path: path,
    params: params,
    query: query,
    headers: headers,
    body: body,
  );
}

/// Framework-neutral outbound response returned by an [InternalRouteCallback].
class InternalResponse {
  const InternalResponse({
    this.status = 200,
    this.headers = const <String, String>{},
    this.body = const <int>[],
  });

  /// HTTP status; defaults to 200.
  final int status;

  /// Response headers; names are lower-cased like [InternalRequest.headers].
  final Map<String, String> headers;

  /// Raw body bytes; empty when the response carries none.
  final List<int> body;
}

/// A registered route: pattern plus its precompiled pattern and callback.
class InternalRoute<B> {
  InternalRoute(this.pattern, this.regexp, this.keys, this.callback);

  /// The pattern string passed to [InternalRouter.define].
  final String pattern;

  /// Precompiled match of [pattern]; built once in [InternalRouter.define]
  /// and never recompiled per request.
  final RegExp regexp;

  /// Capture-group names of `:name` / `*name` parameters, in group order.
  final List<String> keys;

  final InternalRouteCallback<B> callback;
}

/// Minimal rooted path-pattern router, mirroring upstream `InternalRouter`.
///
/// Patterns are matched exactly and support:
/// * literals — regex metacharacters are escaped, so `/a.b` matches only
///   `/a.b` (a trailing slash does not match);
/// * `:name` — one path segment (`[^/]+`, so `foo.bar` is one segment);
/// * `*name` — catch-all including slashes (`.*`, may capture the empty
///   string, so `/*path` matches `/` with `path == ''`).
///
/// [handle] returns the first matching route's callback result, or null when
/// no route matches; method filtering is the callback's job. [B] lets
/// `nitori_server` register routes against `SatoriBot` without `nitori_core`
/// depending on the server.
class InternalRouter<B> {
  /// Routes in registration order; the first match wins.
  final List<InternalRoute<B>> routes = <InternalRoute<B>>[];

  /// Compiles rooted [path] and appends the route.
  ///
  /// Throws [ArgumentError] when [path] is not rooted or a parameter name is
  /// missing.
  InternalRoute<B> define(String path, InternalRouteCallback<B> callback) {
    if (!path.startsWith('/')) {
      throw ArgumentError.value(path, 'path', 'pattern must be rooted');
    }
    final (regexp, keys) = _compilePattern(path);
    final route = InternalRoute<B>(path, regexp, keys, callback);
    routes.add(route);
    return route;
  }

  /// Routes [request] through [routes] in order and awaits the first match's
  /// callback; returns null when nothing matches.
  Future<InternalResponse?> handle(B bot, InternalRequest request) async {
    for (final route in routes) {
      final match = route.regexp.firstMatch(request.path);
      if (match == null) continue;
      final params = <String, String>{
        for (var i = 0; i < route.keys.length; i++)
          route.keys[i]: match.group(i + 1)!,
      };
      return route.callback(request.withParams(params), bot);
    }
    return null;
  }
}

(RegExp, List<String>) _compilePattern(String pattern) {
  final keys = <String>[];
  final buffer = StringBuffer('^');
  final literal = StringBuffer();
  var index = 0;

  void flushLiteral() {
    if (literal.isEmpty) return;
    buffer.write(RegExp.escape(literal.toString()));
    literal.clear();
  }

  while (index < pattern.length) {
    final char = pattern[index];
    if (char == ':' || char == '*') {
      var end = index + 1;
      while (end < pattern.length && _isNameChar(pattern[end])) {
        end++;
      }
      if (end == index + 1) {
        throw ArgumentError.value(
          pattern,
          'pattern',
          'missing parameter name after "$char"',
        );
      }
      flushLiteral();
      keys.add(pattern.substring(index + 1, end));
      buffer.write(char == ':' ? '([^/]+)' : '(.*)');
      index = end;
    } else {
      literal.write(char);
      index++;
    }
  }
  flushLiteral();
  buffer.write(r'$');
  return (RegExp(buffer.toString()), keys);
}

bool _isNameChar(String char) {
  final code = char.codeUnitAt(0);
  return code == 0x5f || // _
      (code >= 0x30 && code <= 0x39) || // 0-9
      (code >= 0x41 && code <= 0x5a) || // A-Z
      (code >= 0x61 && code <= 0x7a); // a-z
}
