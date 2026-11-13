/// Shared protocol primitives and wire-format helpers: pagination, the
/// `transformKey` key rewriter and the shared string enums.
library;

import 'package:json_annotation/json_annotation.dart';

/// The `List` / `BidiList` payload shape of the protocol.
class Pagination<T> {
  Pagination(this.data, {this.next, this.prev});

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination<T>(
    (json['data'] as List<dynamic>).cast<T>(),
    next: json['next'] as String?,
    prev: json['prev'] as String?,
  );

  List<T> data;
  String? next;

  /// Only present in `BidiList` payloads.
  String? prev;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'data': data,
    if (next != null) 'next': next,
    if (prev != null) 'prev': prev,
  };
}

/// The `BidiList` payload shape: a page that can be walked in both directions.
class BidiList<T> {
  BidiList(this.data, {this.prev, this.next});

  factory BidiList.fromJson(Map<String, dynamic> json) => BidiList<T>(
    (json['data'] as List<dynamic>).cast<T>(),
    prev: json['prev'] as String?,
    next: json['next'] as String?,
  );

  List<T> data;
  String? prev;
  String? next;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'data': data,
    if (prev != null) 'prev': prev,
    if (next != null) 'next': next,
  };
}

/// Direction of a paginated request, carried by the `direction` field.
enum Direction {
  before('before'),
  after('after'),
  around('around');

  const Direction(this.value);

  final String value;
}

/// Sorting order of a paginated request, carried by the `order` field.
enum Order {
  asc('asc'),
  desc('desc');

  const Order(this.value);

  final String value;
}

/// Opcodes of the Satori WebSocket payloads.
@JsonEnum(valueField: 'value')
enum Opcode {
  event(0),
  ping(1),
  pong(2),
  identify(3),
  ready(4),
  meta(5);

  const Opcode(this.value);

  final int value;
}

/// Converts a `snake_case` wire key to the `camelCase` Dart field name.
String cashConvertSnakeToCamel(String key) {
  final parts = key.split('_');
  return parts.first +
      parts
          .skip(1)
          .map(
            (part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join();
}

/// Converts a `camelCase` Dart field name to its `snake_case` wire key.
String cashConvertCamelToSnake(String key) => key.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => '_${match[0]!.toLowerCase()}',
);

/// Recursively rewrites the keys of a JSON object.
///
/// Keys prefixed with `_` and the key `referrer` are passed through untouched:
/// the former are adapter-local attributes, the latter carries platform objects
/// that upstream forwards to `message.create` verbatim, so renaming them would
/// corrupt the payload.
dynamic transformKey(dynamic source, dynamic Function(String key) callback) {
  if (source is List) {
    return source.map((value) => transformKey(value, callback)).toList();
  }
  if (source is! Map) return source;
  final result = <String, dynamic>{};
  source.forEach((key, value) {
    final name = key.toString();
    final skip = name.startsWith('_') || name == 'referrer';
    result[skip ? name : callback(name)] = skip
        ? value
        : transformKey(value, callback);
  });
  return result;
}
