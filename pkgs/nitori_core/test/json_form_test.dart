import 'dart:convert';

import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

void main() {
  group('JsonForm.encode / decode', () {
    test('plain maps and lists round-trip as application/json', () {
      const data = <String, dynamic>{
        'method': 'get',
        'path': ['a', 'b'],
        'nested': <String, dynamic>{'page': null},
      };

      final body = JsonForm.encode(data);

      expect(body.contentType, 'application/json');
      expect(jsonDecode(utf8.decode(body.bytes)), <String, dynamic>{
        'method': 'get',
        'path': ['a', 'b'],
        'nested': <String, dynamic>{'page': null},
      });
      expect(JsonForm.decode(body.contentType, body.bytes), data);
    });

    test(r'a JsonBlob forces multipart with the "$" skeleton part', () {
      final data = <String, dynamic>{
        'file': JsonBlob(utf8.encode('hello'), filename: 'a.txt'),
      };

      final body = JsonForm.encode(data);

      expect(body.contentType, startsWith('multipart/form-data; boundary='));
      final raw = utf8.decode(body.bytes);
      expect(raw, contains('name="\$"'));
      expect(raw, contains('filename="a.txt"'));
      expect(raw, contains('hello'));
      final boundary = body.contentType.substring(
        body.contentType.indexOf('boundary=') + 'boundary='.length,
      );
      expect(raw.endsWith('--$boundary--\r\n'), isTrue);

      final decoded = JsonForm.decode(body.contentType, body.bytes);
      expect(decoded, isA<Map<String, dynamic>>());
      final blob = (decoded as Map<String, dynamic>)['file'];
      expect(blob, isA<JsonBlob>());
      expect(utf8.decode((blob as JsonBlob).bytes), 'hello');
      expect(blob.filename, 'a.txt');
      expect(blob.contentType, isNull);
    });

    test('nested blobs get distinct dotted part names and round-trip', () {
      final data = <String, dynamic>{
        'file': JsonBlob([1], filename: 'one.bin'),
        'meta': <String, dynamic>{
          'cover': JsonBlob(
            [2],
            filename: 'cover.png',
            contentType: 'image/png',
          ),
        },
        'items': <dynamic>[
          <String, dynamic>{
            'thumb': JsonBlob([3], filename: 't.png'),
          },
        ],
      };

      final body = JsonForm.encode(data);
      final raw = utf8.decode(body.bytes);
      expect(raw, contains('name="\$.file"'));
      expect(raw, contains('name="\$.meta.cover"'));
      expect(raw, contains('name="\$.items.0.thumb"'));
      expect(raw, contains('name="\$"'));
      expect(raw, contains('Content-Type: image/png'));

      final decoded =
          JsonForm.decode(body.contentType, body.bytes) as Map<String, dynamic>;
      expect((decoded['file'] as JsonBlob).bytes, const [1]);
      final cover = decoded['meta'];
      expect(cover, isA<Map<String, dynamic>>());
      final coverBlob = (cover as Map<String, dynamic>)['cover'] as JsonBlob;
      expect(coverBlob.filename, 'cover.png');
      expect(coverBlob.contentType, 'image/png');
      expect(coverBlob.bytes, const [2]);
      final items = decoded['items'] as List<dynamic>;
      final thumb =
          ((items.first as Map<String, dynamic>)['thumb']) as JsonBlob;
      expect(thumb.filename, 't.png');
      expect(thumb.bytes, const [3]);
      // Non-blob siblings survive the walk.
      expect(decoded['meta'], isA<Map<String, dynamic>>());
    });

    test('filenames with quotes and backslashes round-trip', () {
      final body = JsonForm.encode(<String, dynamic>{
        'file': JsonBlob(
          [1],
          filename: 'a "b" \\ c.txt',
          contentType: 'text/plain',
        ),
      });

      final decoded =
          JsonForm.decode(body.contentType, body.bytes) as Map<String, dynamic>;
      expect((decoded['file'] as JsonBlob).filename, 'a "b" \\ c.txt');
      expect((decoded['file'] as JsonBlob).contentType, 'text/plain');
    });

    test(r'blob-only scalar skeleton becomes a JSON "$" part', () {
      final body = JsonForm.encode(JsonBlob([7], filename: 'only.bin'));
      expect(body.contentType, startsWith('multipart/form-data;'));
      expect(utf8.decode(body.bytes), contains('name="\$"'));
      final decoded = JsonForm.decode(body.contentType, body.bytes);
      expect(decoded, isA<JsonBlob>());
      expect((decoded as JsonBlob).bytes, const [7]);
    });

    test('non-ASCII text survives the UTF-8 round-trip', () {
      final data = <String, dynamic>{'text': '你好, 日本語 — ünïcödé'};

      final body = JsonForm.encode(data);

      expect(body.contentType, 'application/json');
      expect(JsonForm.decode(body.contentType, body.bytes), <String, dynamic>{
        'text': '你好, 日本語 — ünïcödé',
      });

      final multipart = JsonForm.encode(<String, dynamic>{
        'text': '你好',
        'file': JsonBlob([9], filename: '文.txt'),
      });
      expect(
        (JsonForm.decode(multipart.contentType, multipart.bytes)
            as Map<String, dynamic>)['text'],
        '你好',
      );
      expect(utf8.decode(multipart.bytes), contains('filename="文.txt"'));
    });

    test('decode throws on an unsupported content type', () {
      expect(
        () => JsonForm.decode('text/plain', utf8.encode('hi')),
        throwsArgumentError,
      );
      expect(() => JsonForm.decode(null, const <int>[]), throwsArgumentError);
      expect(
        () => JsonForm.decode('application/xml', utf8.encode('<a/>')),
        throwsArgumentError,
      );
    });

    test(r'decode throws on a multipart body missing the "$" part', () {
      const boundary = '----nitori-x';
      final body = utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="a"\r\n'
        '\r\n'
        'x\r\n'
        '--$boundary--\r\n',
      );
      expect(
        () => JsonForm.decode('multipart/form-data; boundary=$boundary', body),
        throwsFormatException,
      );
    });

    test('a pagination-shaped list of maps with blobs round-trips', () {
      final data = <String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{
            'id': '1',
            'file': JsonBlob([10, 20], filename: 'p1'),
          },
          <String, dynamic>{
            'id': '2',
            'file': JsonBlob([30], filename: 'p2'),
          },
        ],
        'next': 'cursor',
        'prev': null,
      };

      final body = JsonForm.encode(data);
      expect(body.contentType, startsWith('multipart/form-data; boundary='));

      final decoded =
          JsonForm.decode(body.contentType, body.bytes) as Map<String, dynamic>;
      expect(decoded['next'], 'cursor');
      expect(decoded['prev'], isNull);
      final list = decoded['data'] as List<dynamic>;
      expect(list, hasLength(2));
      expect((list[0] as Map<String, dynamic>)['id'], '1');
      expect(
        ((list[0] as Map<String, dynamic>)['file'] as JsonBlob).bytes,
        const [10, 20],
      );
      expect(
        ((list[1] as Map<String, dynamic>)['file'] as JsonBlob).filename,
        'p2',
      );
    });
  });

  group('JsonForm.dump / load', () {
    test('dump sinks blobs at dotted paths and nulls them out', () {
      final parts = JsonFormParts();
      final data = <String, dynamic>{
        'a': JsonBlob([1], filename: 'a'),
        'list': <dynamic>[
          JsonBlob([2], filename: 'b'),
        ],
      };

      final dumped = JsonForm.dump(data, r'$', parts);

      expect(dumped, <String, dynamic>{
        'a': null,
        'list': <dynamic>[null],
      });
      expect(parts.parts.keys, <String>[r'$.a', r'$.list.0']);
      expect(parts.get(r'$.a')!.bytes, const [1]);
      expect(parts.get(r'$.list.0')!.filename, 'b');
      expect(parts.get(r'$.missing'), isNull);
    });

    test('load re-attaches sinks by path', () {
      final parts = JsonFormParts()
        ..append(r'$.a', JsonBlob([1], filename: 'a'));
      final skeleton = <String, dynamic>{
        'a': null,
        'b': <String, dynamic>{'keep': 1},
      };

      final loaded =
          JsonForm.load(skeleton, r'$', parts) as Map<String, dynamic>;

      expect((loaded['a'] as JsonBlob).bytes, const [1]);
      expect(loaded['b'], <String, dynamic>{'keep': 1});
    });
  });
}
