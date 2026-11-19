import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nitori_client/nitori_client.dart';
import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

/// Minimal in-process HTTP endpoint for exercising media endpoints.
class MockMediaApi {
  MockMediaApi._(this.server);

  final HttpServer server;
  final List<String> paths = <String>[];

  /// Handles each request; defaults to a 404.
  Future<({int status, Object? body, Map<String, String>? headers})> Function(
    HttpRequest request,
    String body,
  )?
  handler;

  static Future<MockMediaApi> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final mock = MockMediaApi._(server);
    server.listen(mock._handleRequest);
    return mock;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    paths.add(request.uri.path);

    final result =
        await handler?.call(request, body) ??
        (
          status: HttpStatus.notFound,
          body: <String, dynamic>{},
          headers: <String, String>{},
        );
    final response = request.response..statusCode = result.status;
    if (result.headers != null) {
      result.headers!.forEach((k, v) => response.headers.add(k, v));
    }
    if (result.body is List<int>) {
      response.add(result.body as List<int>);
    } else {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(result.body));
    }
    await response.close();
  }

  Future<void> close() async {
    await server.close();
  }
}

NitoriBot botFor(MockMediaApi api) => NitoriBot(
  NitoriClient(baseUrl: 'http://127.0.0.1:${api.server.port}').api,
  platform: 'mock',
  userId: 'bot-1',
);

void main() {
  late MockMediaApi api;

  setUp(() async {
    api = await MockMediaApi.start();
  });

  tearDown(() async {
    await api.close();
  });

  group('proxyUrl', () {
    test('returns proxied url when prefix matches', () {
      final client = NitoriClient(baseUrl: 'http://127.0.0.1:5140')
        ..proxyUrls = <String>['https://cdn.example.com'];
      expect(
        client.proxyUrl('https://cdn.example.com/avatar.png'),
        'http://127.0.0.1:5140/v1/proxy/https://cdn.example.com/avatar.png',
      );
    });

    test('returns null when no prefix matches', () {
      final client = NitoriClient(baseUrl: 'http://127.0.0.1:5140')
        ..proxyUrls = <String>['https://cdn.example.com'];
      expect(client.proxyUrl('https://other.com/avatar.png'), isNull);
    });

    test('proxyUrlOr falls back to the original url', () {
      final client = NitoriClient(baseUrl: 'http://127.0.0.1:5140')
        ..proxyUrls = <String>['https://cdn.example.com'];
      expect(
        client.proxyUrlOr('https://cdn.example.com/avatar.png'),
        'http://127.0.0.1:5140/v1/proxy/https://cdn.example.com/avatar.png',
      );
      expect(
        client.proxyUrlOr('https://other.com/avatar.png'),
        'https://other.com/avatar.png',
      );
    });
  });

  group('upload', () {
    test('createUpload sends a multipart form for List<int>', () async {
      late String contentType;
      api.handler = (request, body) async {
        contentType = request.headers.value('content-type') ?? '';
        expect(body, contains('hi'));
        return (
          status: HttpStatus.ok,
          body: <String, dynamic>{'file': 'http://example/1'},
          headers: <String, String>{},
        );
      };

      final bot = botFor(api);
      final urls = await bot.createUpload(<Object>[
        <int>[104, 105],
      ]);

      expect(urls, <String>['http://example/1']);
      expect(contentType, startsWith('multipart/form-data'));
    });

    test('createUpload sends JsonBlob filename and content type', () async {
      late String contentType;
      String? seenFilename;
      String? seenPartContentType;
      api.handler = (request, body) async {
        contentType = request.headers.value('content-type') ?? '';
        final boundary = ContentType.parse(contentType).parameters['boundary'];
        if (boundary == null) {
          fail('no multipart boundary');
        }
        final parts = _splitMultipart(body, boundary);
        for (final part in parts) {
          final name = part.headers['content-disposition']?.toString();
          if (name?.contains('filename=') == true) {
            seenFilename = name;
          }
          final ct = part.headers['content-type'];
          if (ct != null) seenPartContentType = ct;
        }
        return (
          status: HttpStatus.ok,
          body: <String, dynamic>{'file': 'http://example/1'},
          headers: <String, String>{},
        );
      };

      final bot = botFor(api);
      final urls = await bot.createUpload(<Object>[
        JsonBlob(
          <int>[104, 105],
          filename: 'hi.txt',
          contentType: 'text/plain',
        ),
      ]);

      expect(urls, <String>['http://example/1']);
      expect(contentType, startsWith('multipart/form-data'));
      expect(seenFilename, contains('filename="hi.txt"'));
      expect(seenPartContentType, 'text/plain');
    });
  });

  group('download', () {
    test('downloadStream yields proxied bytes', () async {
      final base = 'http://127.0.0.1:${api.server.port}';
      final expected = <int>[1, 2, 3, 4, 5];
      api.handler = (request, body) async {
        expect(request.uri.path.startsWith('/v1/proxy/'), isTrue);
        return (
          status: HttpStatus.ok,
          body: expected,
          headers: <String, String>{'content-type': 'image/png'},
        );
      };

      final client = NitoriClient(baseUrl: base)
        ..proxyUrls = <String>['https://cdn.example.com'];
      final stream = await client.downloadStream(
        'https://cdn.example.com/image.png',
      );

      final bytes = <int>[];
      await for (final chunk in stream) {
        bytes.addAll(chunk);
      }
      expect(bytes, expected);
      expect(api.paths.single.startsWith('/v1/proxy/'), isTrue);
    });

    test('downloadStream with useProxy false hits raw path', () async {
      final base = 'http://127.0.0.1:${api.server.port}';
      final expected = <int>[9, 9];
      api.handler = (request, body) async {
        expect(request.uri.path, '/raw');
        return (
          status: HttpStatus.ok,
          body: expected,
          headers: <String, String>{},
        );
      };

      final client = NitoriClient(baseUrl: base);
      final stream = await client.downloadStream('$base/raw', useProxy: false);

      final bytes = <int>[];
      await for (final chunk in stream) {
        bytes.addAll(chunk);
      }
      expect(bytes, expected);
    });

    test('download returns bytes and content type', () async {
      final base = 'http://127.0.0.1:${api.server.port}';
      final expected = <int>[7, 8, 9];
      api.handler = (request, body) async {
        return (
          status: HttpStatus.ok,
          body: expected,
          headers: <String, String>{'content-type': 'image/jpeg'},
        );
      };

      final client = NitoriClient(baseUrl: base);
      final result = await client.download('$base/raw');

      expect(result.bytes, expected);
      expect(result.contentType, 'image/jpeg');
    });

    test('download throws SatoriApiException on non-200', () async {
      final base = 'http://127.0.0.1:${api.server.port}';
      api.handler = (request, body) async => (
        status: HttpStatus.notFound,
        body: <String, dynamic>{'error': 'missing'},
        headers: <String, String>{},
      );

      final client = NitoriClient(baseUrl: base);
      await expectLater(
        client.download('$base/missing'),
        throwsA(
          isA<SatoriApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            HttpStatus.notFound,
          ),
        ),
      );
    });
  });
}

/// Splits a multipart body into parts keyed by their headers.
List<_MultipartPart> _splitMultipart(String body, String boundary) {
  final delimiter = '--$boundary';
  final sections = body.split(delimiter);
  // Drop the prologue and the final closing boundary.
  return sections.skip(1).takeWhile((s) => !s.trim().startsWith('--')).map((s) {
    final trimmed = s.trim();
    final idx = trimmed.indexOf('\r\n\r\n');
    if (idx == -1) {
      return _MultipartPart(<String, String>{}, '');
    }
    final headerBlock = trimmed.substring(0, idx);
    final headers = <String, String>{};
    for (final line in headerBlock.split('\r\n')) {
      final colon = line.indexOf(':');
      if (colon == -1) continue;
      headers[line.substring(0, colon).trim().toLowerCase()] = line
          .substring(colon + 1)
          .trim();
    }
    final content = trimmed.substring(idx + 4).replaceAll('\r\n', '');
    return _MultipartPart(headers, content);
  }).toList();
}

class _MultipartPart {
  _MultipartPart(this.headers, this.content);
  final Map<String, String> headers;
  final String content;
}
