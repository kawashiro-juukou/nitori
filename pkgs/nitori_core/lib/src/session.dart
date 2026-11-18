import './channel.dart';
import './element_codec.dart';
import './event.dart';
import './guild_member.dart';
import './login.dart';
import './message.dart';
import './resource.dart';
import './user.dart';

/// Host context that backs a [Session].
///
/// `nitori_core` is a leaf package and cannot depend on `nitori_client` /
/// `nitori_server`, so everything a session needs from the bot is narrowed to
/// this interface. A null host (detached session) falls back to `event.*`.
abstract class SessionHost {
  String get platform;
  String get selfId;
  Login get login;
  int get sequence;
}

/// The context of a message dispatch: the [Event] under handling plus the host
/// it arrived through.
///
/// Mirrors upstream `@satorijs/core` `Session`. `transform` is deliberately not
/// ported: it renders components through the host app's component registry,
/// which is a component-rendering concern outside the core models.
class Session {
  Session(this.event, {this.host}) {
    event.selfId ??= host?.selfId;
    event.platform ??= host?.platform;
    event.timestamp ??= DateTime.now().millisecondsSinceEpoch;
    sn = host?.sequence;
  }

  /// The underlying event.
  final Event event;

  /// Host that produced the event; null for detached (test) sessions.
  final SessionHost? host;

  /// Sequence number assigned by the host.
  int? sn;

  // -- passthrough accessors --

  // `subtype` is not ported: nitori's [Event] has no such field, adapters
  // discriminate locally through `_type` / `_data` instead.

  // Setter accessors are not ported for the id-bearing reads below: the nitori
  // models require ids at construction (`User.id`, `Channel.id`), so unlike
  // upstream's `??= {}` defaults a null-skip setter would need fabricated
  // defaults. Mutate `event.*` directly when a setter is needed.

  String get type => event.type;

  String? get selfId => event.selfId;

  String? get platform => event.platform;

  int? get timestamp => event.timestamp;

  String? get userId => event.user?.id;

  String? get channelId => event.channel?.id;

  String? get channelName => event.channel?.name;

  String? get guildId => event.guild?.id;

  String? get guildName => event.guild?.name;

  String? get messageId => event.message?.id;

  String? get operatorId => event.operator?.id;

  String? get roleId => event.role?.id;

  Message? get quote => event.message?.quote;

  dynamic get referrer => event.referrer;

  bool get isDirect => event.channel?.type == ChannelType.direct;

  set isDirect(bool value) {
    // The fabricated empty id mirrors upstream's bare `{}` default.
    (event.channel ??= Channel(id: '', type: ChannelType.text)).type = value
        ? ChannelType.direct
        : ChannelType.text;
  }

  /// The message author: user and member payloads merged, member winning on
  /// overlapping display fields.
  GuildMember get author {
    final member = event.member;
    final user = event.user;
    return GuildMember(
      user: user ?? User(id: userId ?? ''),
      name: member?.name ?? user?.name,
      nick: member?.nick ?? user?.nick,
      avatar: member?.avatar ?? user?.avatar,
    );
  }

  // -- composite ids --

  String get uid => '$platform:$userId';

  String get gid => '$platform:$guildId';

  String get cid => '$platform:$channelId';

  String get fid => '$platform:$channelId:$userId';

  String get sid => '$platform:$selfId';

  // -- elements and content --

  List<ElementNode>? get elements {
    final elements = event.message?.elements;
    if (elements == null) return null;
    return decodeElementNodes(elements);
  }

  set elements(List<ElementNode>? value) {
    event.message ??= Message();
    event.message!.elements = value == null ? null : encodeElementNodes(value);
  }

  String? get content {
    final content = event.message?.content;
    if (content != null) return content;
    final elements = event.message?.elements;
    if (elements == null || elements.isEmpty) return null;
    return decodeElementNodes(
      elements,
    ).map((element) => element.toString()).join();
  }

  set content(String? value) {
    event.message ??= Message();
    event.message!.quote = null;
    if (value == null) {
      event.message!.elements = null;
      return;
    }
    var elements = parseElements(value);
    if (elements.isNotEmpty && elements.first.type == 'quote') {
      final quote = elements.removeAt(0);
      event.message!.quote = decodeResource(quote) as Message;
    }
    event.message!.elements = encodeElementNodes(elements);
  }

  /// Sets the adapter-local discriminator (`_type`) and payload (`_data`).
  void setInternal(String type, dynamic data) {
    event.eventType = type;
    event.eventData = data;
  }

  /// Serializes the session as the wire event: injects `sn` and the host
  /// [Login], and folds structured elements back into `content`, prefixing the
  /// encoded quote when one is present.
  Map<String, dynamic> toJSON() {
    final data = event.toJson();
    data['sn'] = sn;
    final login = host?.login;
    if (login != null) data['login'] = login.toJson();
    final message = data['message'];
    if (message is Map<String, dynamic>) {
      final elements = message['elements'];
      if (elements is List) {
        final content = decodeElementNodes(
          elements.cast<Map<String, Object?>>(),
        ).map((element) => element.toString()).join();
        message['content'] = content;
        message.remove('elements');
        final quote = message['quote'];
        if (quote is Map<String, dynamic>) {
          message['content'] =
              '${encodeResource('quote', Message.fromJson(quote))}$content';
        }
      }
    }
    return data;
  }
}
