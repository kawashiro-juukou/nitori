/// Hybrid JSON + `multipart/form-data` codec, mirroring the upstream
/// `@satorijs/core` `JsonForm` (`packages/core/src/internal.ts`).
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// A binary file part carried through [JsonForm].
///
/// Stands in for the platform `Blob` / `File` of the upstream JS codec: any
/// [JsonBlob] in a tree is split out into a multipart part named by its dotted
/// path, and re-attached as a [JsonBlob] on decode. Part names carry a
/// `filename` parameter whenever [filename] is non-null; an absent filename is
/// encoded as `filename=""` so the part still round-trips as a file.
class JsonBlob {
  JsonBlob(this.bytes, {this.filename, this.contentType});

  /// Raw file bytes; never transcoded.
  final List<int> bytes;

  /// Optional form filename, emitted as the `filename` disposition parameter.
  final String? filename;

  /// Optional MIME type of [bytes], emitted as the part's `Content-Type`.
  final String? contentType;

  @override
  bool operator ==(Object other) =>
      other is JsonBlob &&
      other.filename == filename &&
      other.contentType == contentType &&
      _sameBytes(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(filename, contentType, Object.hashAll(bytes));

  @override
  String toString() =>
      'JsonBlob(filename: $filename, contentType: $contentType, '
      'bytes: ${bytes.length})';
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Sink receiving the file parts split out by [JsonForm.dump].
abstract interface class JsonFormSink {
  /// Stores [blob] under the dotted [path] it occupied in the source tree
  /// (`$.key` / `$.index`, rooted at [JsonForm.jsonPart]).
  void append(String path, JsonBlob blob);
}

/// Source consulted by [JsonForm.load] when re-attaching file parts.
abstract interface class JsonFormSource {
  /// Returns the part stored under [path], or null when that path held no
  /// file.
  JsonBlob? get(String path);
}

/// Map-backed [JsonFormSink] / [JsonFormSource] pair.
///
/// Splitting a tree with [JsonForm.dump] and re-attaching it with
/// [JsonForm.load] against the same instance round-trips every [JsonBlob]
/// without serializing the multipart wire format — the shape the server needs
/// when it stores file parts out of band.
class JsonFormParts implements JsonFormSink, JsonFormSource {
  /// Parts keyed by their dotted tree path.
  final Map<String, JsonBlob> parts = <String, JsonBlob>{};

  @override
  void append(String path, JsonBlob blob) => parts[path] = blob;

  @override
  JsonBlob? get(String path) => parts[path];
}

/// Serialized body produced by [JsonForm.encode].
class JsonFormBody {
  const JsonFormBody(this.bytes, this.contentType);

  /// Raw body bytes.
  final List<int> bytes;

  /// `application/json`, or `multipart/form-data; boundary=...` when the
  /// payload carried file parts.
  final String contentType;
}

/// Hybrid JSON + `multipart/form-data` codec, mirroring upstream `JsonForm`.
///
/// A tree is split by walking it: every [JsonBlob] becomes a form part named
/// by its dotted path (`$.key` / `$.0` under the root [JsonForm.jsonPart]) and
/// is replaced with `null` in the JSON skeleton; [load] re-attaches the parts
/// at the paths whose skeleton value is `null`.
class JsonForm {
  JsonForm._();

  /// Name of the form part carrying the JSON skeleton of a multipart body
  /// (upstream `$`).
  static const String jsonPart = r'$';

  /// Walks [data], appending every [JsonBlob] found to [form] under
  /// `[path].[key]` / `[path].[index]` and returning a copy of the tree with
  /// each blob replaced by `null`. Values that are neither maps, lists nor
  /// [JsonBlob]s are returned as-is.
  static dynamic dump(dynamic data, String path, JsonFormSink form) {
    if (data is JsonBlob) {
      form.append(path, data);
      return null;
    }
    if (data is List) {
      return <dynamic>[
        for (var i = 0; i < data.length; i++) dump(data[i], '$path.$i', form),
      ];
    }
    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final name = key.toString();
        result[name] = dump(value, '$path.$name', form);
      });
      return result;
    }
    return data;
  }

  /// Inverse of [dump]: wherever [data] is `null`, reads the part stored at
  /// that path from [form] and puts it back into the returned copy. Non-null
  /// leaves are returned as-is.
  static dynamic load(dynamic data, String path, JsonFormSource form) {
    final value = form.get(path);
    if (value != null) return value;
    if (data is List) {
      return <dynamic>[
        for (var i = 0; i < data.length; i++) load(data[i], '$path.$i', form),
      ];
    }
    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final name = key.toString();
        result[name] = load(value, '$path.$name', form);
      });
      return result;
    }
    return data;
  }

  /// Serializes [data] for the wire. Trees without [JsonBlob]s become plain
  /// `application/json`; trees carrying file parts become
  /// `multipart/form-data` with the JSON skeleton in the [jsonPart] part.
  static JsonFormBody encode(dynamic data) {
    final encoder = _MultipartEncoder();
    final json = jsonEncode(dump(data, jsonPart, encoder));
    if (!encoder.hasParts) {
      return JsonFormBody(utf8.encode(json), 'application/json');
    }
    encoder.appendText(jsonPart, json);
    return encoder.finish();
  }

  /// Inverse of [encode]: `multipart/form-data` reads the [jsonPart] skeleton
  /// and re-attaches every file part through [load]; `application/json`
  /// parses [bytes] as UTF-8 JSON. Any other [contentType] throws
  /// [ArgumentError]; malformed bodies throw [FormatException].
  static dynamic decode(String? contentType, List<int> bytes) {
    final type = _mediaTypeOf(contentType);
    if (type == 'multipart/form-data') {
      final parts = _parseMultipart(bytes, _boundaryOf(contentType!));
      final skeleton = _firstTextPart(parts, jsonPart);
      if (skeleton == null) {
        throw const FormatException('missing JSON skeleton part');
      }
      return load(
        jsonDecode(utf8.decode(skeleton.body)),
        jsonPart,
        _PartSource(parts),
      );
    }
    if (type == 'application/json') {
      return jsonDecode(utf8.decode(bytes));
    }
    throw ArgumentError.value(
      contentType,
      'contentType',
      'unsupported content type',
    );
  }
}

// -- multipart wire format (RFC 7578) --

String? _mediaTypeOf(String? contentType) =>
    contentType?.split(';').first.trim().toLowerCase();

String _boundaryOf(String contentType) {
  for (final parameter in contentType.split(';').skip(1)) {
    final eq = parameter.indexOf('=');
    if (eq < 0) continue;
    if (parameter.substring(0, eq).trim().toLowerCase() != 'boundary') continue;
    var value = parameter.substring(eq + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    if (value.isNotEmpty) return value;
  }
  throw const FormatException('multipart boundary missing');
}

/// Quotes a disposition parameter (RFC 7578 quoted-string): strips CR/LF
/// (header injection) and backslash-escapes `\` and `"`.
String _escapeDispositionParam(String value) => value
    .replaceAll('\r', '')
    .replaceAll('\n', '')
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"');

/// Sanitizes an unquoted header value (e.g. `Content-Type`).
String _escapeHeaderValue(String value) =>
    value.replaceAll('\r', '').replaceAll('\n', '');

/// Inverse of [_escapeDispositionParam].
String _unescapeQuoted(String value) {
  final buffer = StringBuffer();
  var escaped = false;
  for (final code in value.runes) {
    if (escaped) {
      buffer.writeCharCode(code);
      escaped = false;
    } else if (code == 0x5c) {
      escaped = true;
    } else {
      buffer.writeCharCode(code);
    }
  }
  if (escaped) buffer.writeCharCode(0x5c);
  return buffer.toString();
}

String _randomHex(int byteCount) {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < byteCount; i++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

class _MultipartEncoder implements JsonFormSink {
  _MultipartEncoder() : boundary = '----nitori-${_randomHex(8)}';

  final String boundary;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  var _partCount = 0;

  bool get hasParts => _partCount > 0;

  @override
  void append(String path, JsonBlob blob) {
    _writeHeaders(
      'name="${_escapeDispositionParam(path)}"; '
      'filename="${_escapeDispositionParam(blob.filename ?? '')}"',
    );
    final contentType = blob.contentType;
    if (contentType != null) {
      _writeText('Content-Type: ${_escapeHeaderValue(contentType)}\r\n');
    }
    _writeText('\r\n');
    _buffer.add(blob.bytes);
    _writeText('\r\n');
    _partCount++;
  }

  void appendText(String name, String value) {
    _writeHeaders('name="${_escapeDispositionParam(name)}"');
    _writeText('\r\n');
    _buffer.add(utf8.encode(value));
    _writeText('\r\n');
    _partCount++;
  }

  JsonFormBody finish() {
    _writeText('--$boundary--\r\n');
    return JsonFormBody(
      _buffer.takeBytes(),
      'multipart/form-data; boundary=$boundary',
    );
  }

  void _writeHeaders(String dispositionParameters) {
    _writeText('--$boundary\r\n');
    _writeText('Content-Disposition: form-data; $dispositionParameters\r\n');
  }

  void _writeText(String text) => _buffer.add(utf8.encode(text));
}

class _MultipartPart {
  const _MultipartPart({
    required this.name,
    required this.body,
    this.filename,
    this.contentType,
  });

  final String name;

  /// Null when the part is a plain text field (no `filename` parameter).
  final String? filename;
  final String? contentType;
  final List<int> body;
}

class _PartSource implements JsonFormSource {
  _PartSource(this.parts);

  final Map<String, List<_MultipartPart>> parts;

  /// First-wins, mirroring `FormData.get`: only a part carrying a `filename`
  /// re-attaches as a [JsonBlob]; text fields fall through to the JSON value.
  @override
  JsonBlob? get(String path) {
    final list = parts[path];
    if (list == null || list.isEmpty) return null;
    final part = list.first;
    final filename = part.filename;
    if (filename == null) return null;
    return JsonBlob(
      part.body,
      filename: filename.isEmpty ? null : filename,
      contentType: part.contentType,
    );
  }
}

/// The first part under [name] that carries no `filename` — the JSON
/// skeleton. A root-level blob also occupies [JsonForm.jsonPart], so the
/// skeleton is not necessarily the first part under that name.
_MultipartPart? _firstTextPart(
  Map<String, List<_MultipartPart>> parts,
  String name,
) {
  for (final part in parts[name] ?? const <_MultipartPart>[]) {
    if (part.filename == null) return part;
  }
  return null;
}

/// Splits [bytes] on `--boundary` delimiters. Parts sharing a name keep their
/// wire order.
Map<String, List<_MultipartPart>> _parseMultipart(
  List<int> bytes,
  String boundary,
) {
  final delimiter = utf8.encode('--$boundary');
  final parts = <String, List<_MultipartPart>>{};
  var cursor = 0;
  while (true) {
    final start = _indexOfBytes(bytes, delimiter, cursor, bytes.length);
    if (start < 0) break;
    var pos = start + delimiter.length;
    if (pos + 1 < bytes.length &&
        bytes[pos] == 0x2d &&
        bytes[pos + 1] == 0x2d) {
      break; // closing delimiter: --boundary--
    }
    if (pos < bytes.length && bytes[pos] == 0x0d) {
      pos++;
      if (pos < bytes.length && bytes[pos] == 0x0a) pos++;
    } else if (pos < bytes.length && bytes[pos] == 0x0a) {
      pos++;
    } else if (pos >= bytes.length) {
      break; // dangling boundary, nothing follows
    } else {
      throw const FormatException('malformed multipart boundary');
    }
    final next = _indexOfBytes(bytes, delimiter, pos, bytes.length);
    if (next < 0) throw const FormatException('unterminated multipart body');
    var end = next;
    if (end >= pos + 2 && bytes[end - 2] == 0x0d && bytes[end - 1] == 0x0a) {
      end -= 2;
    } else if (end >= pos + 1 && bytes[end - 1] == 0x0a) {
      end -= 1;
    }
    final part = _parsePart(bytes, pos, end);
    parts.putIfAbsent(part.name, () => <_MultipartPart>[]).add(part);
    cursor = next;
  }
  return parts;
}

_MultipartPart _parsePart(List<int> bytes, int start, int end) {
  var separator = _indexOfBytes(bytes, const [13, 10, 13, 10], start, end);
  var separatorLength = 4;
  if (separator < 0) {
    separator = _indexOfBytes(bytes, const [10, 10], start, end);
    separatorLength = 2;
  }
  if (separator < 0) {
    throw const FormatException('multipart part lacks a header block');
  }

  final headers = <String, String>{};
  final headerText = utf8.decode(bytes.sublist(start, separator));
  for (final line in const LineSplitter().convert(headerText)) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    headers[line.substring(0, colon).trim().toLowerCase()] = line
        .substring(colon + 1)
        .trim();
  }

  final disposition = headers['content-disposition'];
  if (disposition == null || !disposition.startsWith('form-data')) {
    throw const FormatException('multipart part lacks content-disposition');
  }
  final name = _readDispositionParam(disposition, 'name');
  if (name == null) {
    throw const FormatException('multipart part lacks a name');
  }
  final filename = _readDispositionParam(disposition, 'filename');

  return _MultipartPart(
    name: _unescapeQuoted(name),
    filename: filename == null ? null : _unescapeQuoted(filename),
    contentType: headers['content-type'],
    body: bytes.sublist(separator + separatorLength, end),
  );
}

/// Reads a quoted disposition parameter, honoring backslash escapes. The
/// returned value is still escaped; [_unescapeQuoted] reverses it.
String? _readDispositionParam(String disposition, String key) =>
    RegExp('\\b$key="((?:[^"\\\\]|\\\\.)*)"').firstMatch(disposition)?.group(1);

/// First occurrence of [needle] in [haystack] within `[start, end)`, else -1.
int _indexOfBytes(List<int> haystack, List<int> needle, int start, int end) {
  final limit = end - needle.length;
  for (var i = start; i <= limit; i++) {
    var j = 0;
    while (j < needle.length && haystack[i + j] == needle[j]) {
      j++;
    }
    if (j == needle.length) return i;
  }
  return -1;
}
