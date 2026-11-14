import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

class _FakeBot {
  _FakeBot(this.id);

  final String id;
}

Future<InternalResponse> _echo(InternalRequest request, _FakeBot bot) async =>
    InternalResponse(
      status: 200,
      headers: <String, String>{'x-echo-bot': bot.id},
      body: <int>[
        for (final entry in request.params.entries)
          ...'${entry.key}=${entry.value};'.codeUnits,
      ],
    );

InternalRouteCallback<_FakeBot> _capture(_Capture capture) {
  return (request, bot) async {
    capture.request = request;
    capture.bot = bot;
    return const InternalResponse();
  };
}

class _Capture {
  InternalRequest? request;
  _FakeBot? bot;
}

InternalRequest _request(
  String path, {
  String method = 'GET',
  Map<String, String>? query,
  Map<String, String>? headers,
  List<int>? body,
}) => InternalRequest(
  method: method,
  path: path,
  query: query,
  headers: headers,
  body: body,
);

void main() {
  group('InternalRouter.define / handle', () {
    test('literal route matches exactly; non-match returns null', () async {
      final router = InternalRouter<_FakeBot>()
        ..define('/ping', (request, bot) async => const InternalResponse());

      expect(await router.handle(_FakeBot('b'), _request('/ping')), isNotNull);
      expect(await router.handle(_FakeBot('b'), _request('/pong')), isNull);
      // Anchored match: a trailing slash does not match.
      expect(await router.handle(_FakeBot('b'), _request('/ping/')), isNull);
    });

    test(':id extracts one segment as a param', () async {
      final capture = _Capture();
      final router = InternalRouter<_FakeBot>()
        ..define('/_tmp/:id', _capture(capture));

      await router.handle(_FakeBot('b'), _request('/_tmp/abc'));

      expect(capture.request!.params, <String, String>{'id': 'abc'});
      expect(capture.request!.path, '/_tmp/abc');
    });

    test(':name matches dotted segments (no slash inside)', () async {
      final capture = _Capture();
      final router = InternalRouter<_FakeBot>()
        ..define('/_api/:name', _capture(capture));

      await router.handle(_FakeBot('b'), _request('/_api/foo.bar'));

      expect(capture.request!.params, <String, String>{'name': 'foo.bar'});
    });

    test('*path captures multi-segment and empty paths', () async {
      final capture = _Capture();
      final router = InternalRouter<_FakeBot>()
        ..define('/*path', _capture(capture));

      await router.handle(_FakeBot('b'), _request('/a/b/c'));
      expect(capture.request!.params, <String, String>{'path': 'a/b/c'});

      // `.*` also captures the empty string, so the bare root matches.
      await router.handle(_FakeBot('b'), _request('/'));
      expect(capture.request!.params, <String, String>{'path': ''});
    });

    test('first-defined route wins when several match', () async {
      final hits = <String>[];
      final router = InternalRouter<_FakeBot>()
        ..define('/*rest', (request, bot) async {
          hits.add('splat');
          return const InternalResponse();
        })
        ..define('/exact', (request, bot) async {
          hits.add('exact');
          return const InternalResponse();
        });

      await router.handle(_FakeBot('b'), _request('/exact'));
      expect(hits, <String>['splat']);
    });

    test('passes the query map through to the callback', () async {
      final capture = _Capture();
      final router = InternalRouter<_FakeBot>()
        ..define('/q', _capture(capture));

      await router.handle(
        _FakeBot('b'),
        _request('/q', query: <String, String>{'page': '2'}),
      );

      expect(capture.request!.query, <String, String>{'page': '2'});
    });

    test('passes headers through with lower-cased names', () async {
      final capture = _Capture();
      final router = InternalRouter<_FakeBot>()
        ..define('/h', _capture(capture));

      await router.handle(
        _FakeBot('b'),
        _request('/h', headers: <String, String>{'x-token': 'secret'}),
      );

      expect(capture.request!.headers, <String, String>{'x-token': 'secret'});
    });

    test('callback receives the same bot instance (generics)', () async {
      final capture = _Capture();
      final router = InternalRouter<_FakeBot>()
        ..define('/bot', _capture(capture));
      final bot = _FakeBot('bot-1');

      await router.handle(bot, _request('/bot'));

      expect(identical(capture.bot, bot), isTrue);
    });

    test('callback response comes back from handle', () async {
      final router = InternalRouter<_FakeBot>()..define('/echo/:id', _echo);

      final response = await router.handle(
        _FakeBot('bot-9'),
        _request('/echo/42'),
      );

      expect(response, isNotNull);
      expect(response!.status, 200);
      expect(response.headers, <String, String>{'x-echo-bot': 'bot-9'});
      expect(String.fromCharCodes(response.body), 'id=42;');
    });

    test('unmatched path returns null', () async {
      final router = InternalRouter<_FakeBot>()
        ..define('/known', (request, bot) async => const InternalResponse());

      expect(await router.handle(_FakeBot('b'), _request('/nope')), isNull);
      expect(await router.handle(_FakeBot('b'), _request('/')), isNull);
    });

    test('regex-special literals match literally, not as wildcards', () async {
      final capture = _Capture();
      final router = InternalRouter<_FakeBot>()
        ..define('/a.b', _capture(capture));

      await router.handle(_FakeBot('b'), _request('/a.b'));
      expect(capture.request!.path, '/a.b');

      // `.` must not act as a wildcard.
      expect(await router.handle(_FakeBot('b'), _request('/axb')), isNull);
    });

    test('rejects unrooted patterns and bare param markers', () {
      final router = InternalRouter<_FakeBot>();
      expect(
        () => router.define(
          'relative',
          (request, bot) async => const InternalResponse(),
        ),
        throwsArgumentError,
      );
      expect(
        () => router.define(
          '/bad/:',
          (request, bot) async => const InternalResponse(),
        ),
        throwsArgumentError,
      );
    });
  });
}
