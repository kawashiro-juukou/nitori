/// The Satori HTTP API client: sends requests to the Satori server and
/// decodes their responses.
///
/// [SatoriApiClient] owns the shared `http.Client` and knows nothing about
/// the WebSocket gateway, the connection lifecycle or the event stream. It
/// talks to the server over `/v1/<key>` routes, builds the identity headers
/// from the per-request [SatoriApiIdentity], and maps non-200 responses to
/// [SatoriApiException].
///
/// The `NitoriBot` bot methods delegate here; the [NitoriClient] facade
/// exposes the same surface for backward compatibility.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nitori_core/nitori_core.dart';

/// Thrown when the server answers with a non-200 status.
class SatoriApiException implements Exception {
  SatoriApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'SatoriApiException: HTTP $statusCode $message';
}

/// The identity a request is made on behalf of.
///
/// [SatoriApiClient] only needs the platform / user id pair that becomes the
/// `satori-platform` / `satori-user-id` headers, so it does not depend on the
/// bot object that carries them.
class SatoriApiIdentity {
  const SatoriApiIdentity({required this.platform, required this.userId});

  final String platform;
  final String userId;
}

/// The HTTP API of a Satori server.
class SatoriApiClient {
  SatoriApiClient({
    required this.baseUrl,
    this.token,
    this.proxyUrls = const <String>[],
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// HTTP(S) base URL of the Satori server, e.g. `http://localhost:5140`.
  final String baseUrl;

  /// Access token sent as `Authorization: Bearer`.
  final String? token;

  /// Proxy URLs advertised by the server, used by [proxyUrl].
  List<String> proxyUrls;

  /// Shared HTTP client; inject one to control timeouts / TLS in tests.
  final http.Client _http;

  /// Resolves [url] through the server's media proxy when it is allowed.
  ///
  /// Returns `$baseUrl/v1/proxy/$url` if [url] starts with one of the
  /// server-advertised [proxyUrls]; returns null otherwise.
  String? proxyUrl(String url) {
    if (proxyUrls.any(url.startsWith)) {
      return '$baseUrl/v1/proxy/$url';
    }
    return null;
  }

  /// Like [proxyUrl] but falls back to [url] itself.
  String proxyUrlOr(String url) => proxyUrl(url) ?? url;

  /// Releases the shared HTTP client.
  ///
  /// The client is closed even when it was injected; callers that keep
  /// ownership of an injected client should not call [close].
  void close() => _http.close();

  /// Sends one bot API request and returns the decoded JSON response.
  ///
  /// Field names come from the [methods] registry; each Dart argument is keyed
  /// by the matching wire field and passed through [transformKey] so nested
  /// camelCase maps become snake_case on the wire.
  Future<dynamic> request(
    SatoriApiIdentity identity,
    String key,
    List<Object?> args,
  ) async {
    final method = methods[key];
    if (method == null) throw StateError('unknown method: $key');

    final uri = Uri.parse('$baseUrl/v1/$key');
    if (method.isForm) {
      final streamed = await _http.send(_multipartRequest(uri, identity, args));
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
    final response = await _http.post(
      uri,
      headers: _headers(identity),
      body: jsonEncode(payload),
    );
    return _decode(response);
  }

  /// Sends a request to an arbitrary route with optional extra headers.
  ///
  /// Reuses [request]'s encoding logic but skips the methods lookup, so the
  /// route need not be in the [methods] registry (for internal routes).
  Future<JsonFormBody> requestByKey(
    SatoriApiIdentity identity,
    String key,
    List<Object?> args, {
    Map<String, String>? extraHeaders,
  }) async {
    // Build payload the same way as request, but without method validation.
    final uri = Uri.parse('$baseUrl/v1/$key');
    final isForm = key == 'upload.create'; // Only known form method.

    if (isForm) {
      final streamed = await _http.send(
        _multipartRequest(uri, identity, args, extraHeaders: extraHeaders),
      );
      final response = await http.Response.fromStream(streamed);
      return _decodeToJsonFormBody(response);
    }

    // Use the first arg as the payload if it's a Map, otherwise wrap in array.
    final body = _internalBody(args);
    final headers = _headers(identity);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final response = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    return _decodeToJsonFormBody(response);
  }

  /// Makes a request with a full path (for internal routes).
  ///
  /// Unlike [requestByKey], this takes a full path starting with `/v1/` and
  /// doesn't prepend the base URL's v1 prefix.
  Future<JsonFormBody> requestFullPath(
    SatoriApiIdentity identity,
    String fullPath,
    List<Object?> args, {
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$baseUrl$fullPath');
    final body = _internalBody(args);
    final headers = _headers(identity);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final response = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    return _decodeToJsonFormBody(response);
  }

  /// Makes a request with a full path, sending raw bytes body.
  ///
  /// For internal routes that use multipart/form-data or already-encoded
  /// JsonForm. [method] defaults to POST; GET forwards carry no body.
  Future<JsonFormBody> requestFullPathBytes(
    SatoriApiIdentity identity,
    String fullPath,
    List<int> bodyBytes, {
    Map<String, String>? extraHeaders,
    String? contentType,
    String method = 'POST',
  }) async {
    final uri = Uri.parse('$baseUrl$fullPath');
    final headers = _headers(identity);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    if (contentType != null) headers['content-type'] = contentType;
    final response = await _http.send(
      http.Request(method, uri)
        ..headers.addAll(headers)
        ..bodyBytes = method == 'GET' || method == 'HEAD'
            ? const <int>[]
            : bodyBytes,
    );
    return _decodeToJsonFormBody(await http.Response.fromStream(response));
  }

  /// Forwards an internal route request to the remote server, returning the
  /// response verbatim (status, headers and bytes) instead of throwing on a
  /// non-200 status. Used by the protocol bridge to mirror remote `/_tmp` and
  /// `/_api` responses onto the local server.
  Future<JsonFormBody> forwardFullPathBytes(
    SatoriApiIdentity identity,
    String fullPath,
    List<int> bodyBytes, {
    Map<String, String>? extraHeaders,
    String? contentType,
    String method = 'POST',
  }) async {
    final uri = Uri.parse('$baseUrl$fullPath');
    final headers = _headers(identity);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    if (contentType != null) headers['content-type'] = contentType;
    final response = await _http.send(
      http.Request(method, uri)
        ..headers.addAll(headers)
        ..bodyBytes = method == 'GET' || method == 'HEAD'
            ? const <int>[]
            : bodyBytes,
    );
    return _toJsonFormBody(await http.Response.fromStream(response));
  }

  /// Downloads [url] as a byte stream.
  ///
  /// Routes through the server proxy when [useProxy] is true and the server
  /// advertises it; otherwise fetches [url] directly. Throws
  /// [SatoriApiException] on a non-200 status.
  Future<Stream<List<int>>> downloadStream(
    String url, {
    bool useProxy = true,
  }) async {
    final target = useProxy ? proxyUrlOr(url) : url;
    final response = await _http.send(http.Request('GET', Uri.parse(target)));
    if (response.statusCode != 200) {
      final bytes = await response.stream.toBytes();
      throw SatoriApiException(
        response.statusCode,
        utf8.decode(bytes, allowMalformed: true),
      );
    }
    return response.stream;
  }

  /// Downloads [url] and returns its bytes with the response content type.
  Future<({Uint8List bytes, String? contentType})> download(
    String url, {
    bool useProxy = true,
  }) async {
    final target = useProxy ? proxyUrlOr(url) : url;
    final response = await _http.send(http.Request('GET', Uri.parse(target)));
    if (response.statusCode != 200) {
      final bytes = await response.stream.toBytes();
      throw SatoriApiException(
        response.statusCode,
        utf8.decode(bytes, allowMalformed: true),
      );
    }
    final bytes = await response.stream.toBytes();
    return (
      bytes: Uint8List.fromList(bytes),
      contentType: response.headers['content-type'],
    );
  }

  // -- internals --

  Map<String, String> _headers(SatoriApiIdentity identity) => <String, String>{
    if (token != null) 'Authorization': 'Bearer $token',
    'satori-platform': identity.platform,
    'satori-user-id': identity.userId,
    'content-type': 'application/json',
  };

  /// Builds a multipart upload request for [uri], adding parts named `file`,
  /// `file1`, `file2`, ... from [blobs]. Accepts [List<int>], [String] and
  /// [JsonBlob] parts.
  http.MultipartRequest _multipartRequest(
    Uri uri,
    SatoriApiIdentity identity,
    List<Object?> blobs, {
    Map<String, String>? extraHeaders,
  }) {
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(identity));
    if (extraHeaders != null) request.headers.addAll(extraHeaders);
    for (var i = 0; i < blobs.length; i++) {
      final field = i == 0 ? 'file' : 'file${i + 1}';
      final blob = blobs[i];
      if (blob is List<int>) {
        request.files.add(http.MultipartFile.fromBytes(field, blob));
      } else if (blob is String) {
        request.files.add(http.MultipartFile.fromString(field, blob));
      } else if (blob is JsonBlob) {
        request.files.add(
          http.MultipartFile.fromBytes(
            field,
            blob.bytes,
            filename: blob.filename,
            contentType: blob.contentType == null
                ? null
                : MediaType.parse(blob.contentType!),
          ),
        );
      } else {
        throw ArgumentError('unsupported upload blob: ${blob.runtimeType}');
      }
    }
    return request;
  }

  /// Builds the JSON body for an internal-route request.
  ///
  /// The first argument is used verbatim when it is a map; otherwise the
  /// arguments are keyed by their positional index.
  Map<String, dynamic> _internalBody(List<Object?> args) {
    if (args.isNotEmpty && args.first is Map) {
      return args.first as Map<String, dynamic>;
    }
    return <String, dynamic>{
      for (var i = 0; i < args.length; i++) i.toString(): args[i],
    };
  }

  /// Decodes response to JsonFormBody (handles both JSON and multipart).
  JsonFormBody _decodeToJsonFormBody(http.Response response) {
    final body = _toJsonFormBody(response);
    if (response.statusCode != 200) {
      throw SatoriApiException(
        response.statusCode,
        utf8.decode(response.bodyBytes),
      );
    }
    return body;
  }

  JsonFormBody _toJsonFormBody(http.Response response) {
    final contentType = response.headers['content-type'] ?? 'application/json';
    // Skip hop-by-hop / auto-managed headers: http has already decompressed
    // the body, so content-encoding and content-length must not be forwarded.
    const skipped = {'content-encoding', 'content-length', 'transfer-encoding'};
    final headers = <String, String>{
      for (final entry in response.headers.entries)
        if (!skipped.contains(entry.key.toLowerCase()))
          entry.key.toLowerCase(): entry.value,
    };
    return JsonFormBody(
      response.bodyBytes,
      contentType,
      statusCode: response.statusCode,
      headers: headers,
    );
  }

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw SatoriApiException(response.statusCode, text);
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }
}
