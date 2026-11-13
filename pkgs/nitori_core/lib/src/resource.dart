import './channel.dart';
import './escaping.dart';
import './guild.dart';
import './guild_member.dart';
import './message.dart';
import './user.dart';

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _listEquals(List<ElementNode> a, List<ElementNode> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// A node of the Satori element DSL.
///
/// The typed element models live in `nitori_message`, and `nitori_core` cannot
/// depend on it without inverting the package graph. Resources are therefore
/// encoded to and decoded from this minimal structural node, so the element DSL
/// keeps a representation here and `nitori_message` can convert to and from it
/// when the two need to interoperate.
class ElementNode {
  ElementNode(
    this.type, {
    Map<String, String>? attributes,
    List<ElementNode>? children,
    this.text = '',
  }) : attributes = attributes ?? const <String, String>{},
       children = children ?? const <ElementNode>[];

  /// Tag name. Bare text runs are represented as a `text` node.
  final String type;

  /// Attribute names exactly as they appear on the wire (`snake_case`).
  final Map<String, String> attributes;

  final List<ElementNode> children;

  /// Raw (unescaped) text carried by this node.
  final String text;

  bool get _isEmpty => children.isEmpty && text.isEmpty;

  @override
  String toString() {
    if (type == 'text') return escapeText(text);
    final attrs = attributes.entries
        .map((entry) => ' ${entry.key}="${escapeAttribute(entry.value)}"')
        .join();
    if (_isEmpty) return '<$type$attrs/>';
    return '<$type$attrs>'
        '${children.map((child) => child.toString()).join()}'
        '${escapeText(text)}'
        '</$type>';
  }

  @override
  bool operator ==(Object other) =>
      other is ElementNode &&
      other.type == type &&
      other.text == text &&
      _mapEquals(other.attributes, attributes) &&
      _listEquals(other.children, children);

  @override
  int get hashCode =>
      Object.hash(type, text, attributes.length, children.length);
}

/// Attribute lists mirroring the upstream `Definitions` table, in wire
/// (`snake_case`) spelling, including the deliberate omissions: `member` carries
/// no id because the id lives on its user, and `Channel.parentId` /
/// `Channel.position` are never resource attributes.
const Map<String, List<String>> resourceAttrs = <String, List<String>>{
  'user': <String>['id', 'name', 'nick', 'avatar', 'is_bot'],
  'member': <String>['name', 'nick', 'avatar'],
  'channel': <String>['id', 'type', 'name'],
  'guild': <String>['id', 'name', 'avatar'],
  'quote': <String>['id'],
};

/// Nested resource keys, in the order upstream serializes them.
const Map<String, List<String>> _resourceChildren = <String, List<String>>{
  'quote': <String>['quote', 'user', 'member', 'channel'],
};

/// Key holding content parsed into element children.
const Map<String, String> _resourceContent = <String, String>{
  'quote': 'content',
};

String? _wireString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

Map<String, String> _encodeAttrs(String type, Object resource) {
  final attrs = <String, String>{};
  for (final key in resourceAttrs[type]!) {
    final value = _wireString(_readAttr(type, key, resource));
    if (value != null) attrs[key] = value;
  }
  return attrs;
}

Object? _readAttr(String type, String key, Object resource) {
  switch (type) {
    case 'user':
      final user = resource as User;
      switch (key) {
        case 'id':
          return user.id;
        case 'name':
          return user.name;
        case 'nick':
          return user.nick;
        case 'avatar':
          return user.avatar;
        case 'is_bot':
          return user.isBot;
      }
    case 'member':
      final member = resource as GuildMember;
      switch (key) {
        case 'name':
          return member.name;
        case 'nick':
          return member.nick;
        case 'avatar':
          return member.avatar;
      }
    case 'channel':
      final channel = resource as Channel;
      switch (key) {
        case 'id':
          return channel.id;
        case 'type':
          return channel.type.value;
        case 'name':
          return channel.name;
      }
    case 'guild':
      final guild = resource as Guild;
      switch (key) {
        case 'id':
          return guild.id;
        case 'name':
          return guild.name;
        case 'avatar':
          return guild.avatar;
      }
    case 'quote':
      return (resource as Message).id;
  }
  throw ArgumentError.value(key, 'key', 'unknown attribute of resource $type');
}

/// Encodes a resource into its element form.
///
/// Mirrors upstream `Resource.encode`: attributes are picked from the resource,
/// nested resources are appended as child elements and a `content` field is
/// parsed into element children.
ElementNode encodeResource(String type, Object resource) {
  final node = ElementNode(type, attributes: _encodeAttrs(type, resource));
  for (final child in _resourceChildren[type] ?? const <String>[]) {
    if (_readChild(type, child, resource) case final value?) {
      node.children.add(encodeResource(child, value));
    }
  }
  final content = _resourceContent[type] == null
      ? null
      : _readAttr(_resourceContent[type]!, 'content', resource);
  if (content is String && content.isNotEmpty) {
    node.children.addAll(parseElements(content));
  }
  return node;
}

Object? _readChild(String type, String key, Object resource) {
  switch (type) {
    case 'quote':
      final quote = resource as Message;
      switch (key) {
        case 'quote':
          return quote.quote;
        case 'user':
          return quote.user;
        case 'member':
          return quote.member;
        case 'channel':
          return quote.channel;
      }
  }
  throw ArgumentError.value(key, 'key', 'unknown child of resource $type');
}

/// Decodes a resource element back into its data.
///
/// Returns the typed model for `user`, `channel` and `guild`, a [Message] for
/// `quote` and the raw attribute map for `member`: a member resource carries no
/// user id on the wire, so a `GuildMember` cannot always be rebuilt from it.
///
/// The upstream splice semantics are kept: the first child matching a resource
/// key is removed from the tree and decoded recursively, and leftover children
/// are joined back into the content.
Object? decodeResource(ElementNode element) {
  switch (element.type) {
    case 'user':
      return User.fromJson(_typedAttrs(element));
    case 'member':
      final data = _typedAttrs(element);
      final user = _findChild(element, 'user');
      if (user != null) {
        data['user'] = User.fromJson(_typedAttrs(user));
      }
      return data;
    case 'channel':
      final data = _typedAttrs(element);
      final type = data['type'];
      if (type is String) {
        data['type'] = int.tryParse(type) ?? type;
      }
      return Channel.fromJson(data);
    case 'guild':
      return Guild.fromJson(_typedAttrs(element));
    case 'quote':
      return _decodeQuote(element);
    default:
      throw ArgumentError.value(element.type, 'type', 'unknown resource');
  }
}

/// Attribute map with the wire value types the models expect: booleans and
/// enum-carrying numbers are parsed out of their string form.
Map<String, dynamic> _typedAttrs(ElementNode element) {
  final data = <String, dynamic>{};
  element.attributes.forEach((key, value) {
    switch (key) {
      case 'is_bot':
        data[key] = value == 'true' || value == 'false';
        break;
      case 'type':
      case 'position':
        data[key] = int.tryParse(value) ?? value;
        break;
      default:
        data[key] = value;
    }
  });
  return data;
}

Message _decodeQuote(ElementNode element) {
  final data = <String, dynamic>{};
  var remaining = <ElementNode>[...element.children];
  for (final child in _resourceChildren['quote']!) {
    final index = remaining.indexWhere((node) => node.type == child);
    if (index == -1) continue;
    final node = remaining.removeAt(index);
    switch (child) {
      case 'quote':
        data['quote'] = decodeResource(node);
        break;
      case 'user':
        data['user'] = decodeResource(node);
        break;
      case 'member':
        data['member'] = decodeResource(node);
        break;
      case 'channel':
        data['channel'] = decodeResource(node);
        break;
    }
  }
  if (remaining.isNotEmpty) {
    data['content'] = remaining.map((node) => node.toString()).join();
  }
  return Message.fromJson(data);
}

ElementNode? _findChild(ElementNode element, String type) {
  for (final child in element.children) {
    if (child.type == type) return child;
  }
  return null;
}

/// Parses the element DSL of a raw content string.
///
/// Only the structure needed to round-trip resources is kept: text runs and
/// elements with their attributes; nested elements are preserved as children.
List<ElementNode> parseElements(String content) => _Parser(content).parse();

class _Parser {
  _Parser(this.source);

  final String source;
  int _index = 0;

  List<ElementNode> parse() => _parseNodes(null);

  List<ElementNode> _parseNodes(String? closer) {
    final nodes = <ElementNode>[];
    while (_index < source.length) {
      final next = source.indexOf('<', _index);
      if (next == -1) {
        final tail = source.substring(_index);
        _index = source.length;
        if (tail.isNotEmpty) _addText(nodes, tail);
        break;
      }
      if (next > _index) {
        _addText(nodes, source.substring(_index, next));
        _index = next;
      }
      if (closer != null && source.startsWith('</$closer>', _index)) {
        _index = source.indexOf('>', _index) + 1;
        return nodes;
      }
      if (source.startsWith('</', _index)) {
        throw FormatException('unmatched closing tag', source, _index);
      }
      _index++;
      nodes.add(_parseElement());
    }
    if (closer != null) {
      throw FormatException('unterminated <$closer>', source, _index);
    }
    return nodes;
  }

  void _addText(List<ElementNode> nodes, String text) =>
      nodes.add(ElementNode('text', text: unescape(text)));

  ElementNode _parseElement() {
    final close = source.indexOf('>', _index);
    if (close == -1) {
      throw FormatException('unterminated element', source, _index);
    }
    final tag = source.substring(_index, close).trim();
    _index = close + 1;
    if (tag.isEmpty) throw FormatException('empty tag', source, _index);
    var type = tag;
    var attributesStart = -1;
    final space = tag.indexOf(' ');
    if (space != -1) {
      type = tag.substring(0, space);
      attributesStart = space + 1;
    }
    final attributes = attributesStart == -1
        ? const <String, String>{}
        : _parseAttributes(tag.substring(attributesStart));
    if (tag.endsWith('/')) {
      return ElementNode(type, attributes: attributes);
    }
    return ElementNode(
      type,
      attributes: attributes,
      children: _parseNodes(type),
    );
  }

  Map<String, String> _parseAttributes(String source) {
    final attrs = <String, String>{};
    for (final match in RegExp(r'([\w-]+)="([^"]*)"').allMatches(source)) {
      attrs[match.group(1)!] = unescape(match.group(2)!);
    }
    return attrs;
  }
}
