/// A minimal in-memory adapter, useful for tests and local development.
///
/// Holds a single [InMemoryBot] and a broadcast event stream. Call [emit] to
/// push events onto the gateway; call [close] to shut down the stream.
library;

import 'dart:async';

import 'package:nitori_core/nitori_core.dart';

import 'adapter.dart';

/// Serves one [InMemoryBot] and exposes [emit] to push gateway events.
///
/// Intended for unit tests and local development. Not suitable for production
/// use — all state is in-memory and lost on restart.
class InMemoryAdapter extends SatoriAdapter {
  /// Creates an adapter with a single [bot] and optional [proxyUrls].
  ///
  /// The [proxyUrls] list is advertised in META and READY frames.
  InMemoryAdapter({required this.bot, List<String>? proxyUrls})
      : proxyUrls = List<String>.unmodifiable(proxyUrls ?? const <String>[]);

  /// The single bot served by this adapter.
  final InMemoryBot bot;

  @override
  final List<String> proxyUrls;

  @override
  List<SatoriBot> get bots => <SatoriBot>[bot];

  final StreamController<Event> _events = StreamController<Event>.broadcast();

  @override
  Stream<Event> get events => _events.stream;

  /// Broadcasts [event] to every connected gateway client.
  ///
  /// The event is added to the internal stream which the server subscribes to.
  void emit(Event event) => _events.add(event);

  /// Closes the event stream, disconnecting all gateway clients.
  Future<void> close() => _events.close();
}

/// An in-memory bot backed by plain maps.
///
/// Provides a fully functional [SatoriBot] implementation using in-memory
/// collections. Suitable for tests, local development, and prototyping.
/// All state is ephemeral and reset on construction.
class InMemoryBot extends SatoriBot {
  /// Creates a bot for [user] on the given [platform] with initial [sn] and [features].
  ///
  /// The [user] becomes the bot's own identity and is added to the user store.
  /// Default platform is `'memory'`, default sequence number is `1`.
  InMemoryBot({
    required User user,
    String platform = 'memory',
    int sn = 1,
    List<String>? features,
  }) : login = Login(
          status: Status.online,
          user: user,
          platform: platform,
          sn: sn,
          adapter: 'memory',
          features: features ?? const <String>[],
        ) {
    users[user.id] = user;
  }

  @override
  Login login;

  @override
  String get platform => login.platform ?? '';

  @override
  String get userId => login.user?.id ?? '';

  // In-memory stores for each entity type.
  final Map<String, Channel> channels = <String, Channel>{};
  final Map<String, Guild> guilds = <String, Guild>{};
  final Map<String, User> users = <String, User>{};
  final Map<String, Message> messages = <String, Message>{};
  final Map<String, GuildMember> members = <String, GuildMember>{};
  final Map<String, GuildRole> roles = <String, GuildRole>{};
  final Map<String, Friend> friends = <String, Friend>{};

  // Reaction tracking: messageId -> emojiId -> Set of userIds.
  final Map<String, Map<String, Set<String>>> _reactions =
      <String, Map<String, Set<String>>>{};
  // Member roles: "guildId/userId" -> Set of roleIds.
  final Map<String, Set<String>> _memberRoles = <String, Set<String>>{};

  int _messageSequence = 0;
  int _roleSequence = 0;
  int _uploadSequence = 0;

  @override
  Future<Channel> getChannel(String id) async =>
      channels[id] ?? (throw StateError('channel not found: $id'));

  @override
  Future<Pagination<Channel>> getChannelList(String guildId,
          {String? next}) async =>
      Pagination<Channel>(channels.values.toList());

  @override
  Future<Channel> createChannel(
      String guildId, Map<String, dynamic> data) async {
    final channel = Channel.fromJson(data);
    channels[channel.id] = channel;
    return channel;
  }

  @override
  Future<void> updateChannel(
      String channelId, Map<String, dynamic> data) async {
    final current = channels[channelId];
    if (current == null) throw StateError('channel not found: $channelId');
    final json = <String, dynamic>{...current.toJson(), ...data};
    json['id'] = channelId;
    channels[channelId] = Channel.fromJson(json);
  }

  @override
  Future<void> deleteChannel(String id) async {
    channels.remove(id);
  }

  @override
  Future<Channel> createDirectChannel(String userId, {String? guildId}) async {
    final user = users[userId];
    final channel = Channel(
      id: 'direct:$userId',
      type: ChannelType.direct,
      name: user?.name,
    );
    channels[channel.id] = channel;
    return channel;
  }

  @override
  Future<void> muteChannel(String channelId,
      {String? guildId, bool? enable}) async {}

  @override
  Future<List<Message>> createMessage(String channelId, String content,
      {dynamic referrer, bool? linkPreview}) async {
    final message = Message(
      id: 'm${++_messageSequence}',
      content: content,
      channel: channels[channelId],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    messages[message.id!] = message;
    return <Message>[message];
  }

  @override
  Future<List<String>> sendMessage(String channelId, String content,
      {dynamic referrer, bool? linkPreview}) async {
    final created = await createMessage(channelId, content,
        referrer: referrer, linkPreview: linkPreview);
    return <String>[for (final message in created) message.id!];
  }

  @override
  Future<Message> getMessage(String channelId, String messageId) async =>
      messages[messageId] ??
      (throw StateError('message not found: $messageId'));

  @override
  Future<BidiList<Message>> getMessageList(String channelId,
      {String? next, Direction? direction, int? limit, Order? order}) async {
    final data = messages.values
        .where((message) => message.channel?.id == channelId)
        .toList();
    if (order == Order.desc) {
      data.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
    }
    if (limit != null && data.length > limit) {
      return BidiList<Message>(data.sublist(0, limit));
    }
    return BidiList<Message>(data);
  }

  @override
  Future<void> editMessage(
      String channelId, String messageId, String content) async {
    messages[messageId]?.content = content;
  }

  @override
  Future<void> deleteMessage(String channelId, String messageId) async {
    messages.remove(messageId);
  }

  @override
  Future<void> createReaction(
      String channelId, String messageId, String emojiId) async {
    _reactions
        .putIfAbsent(messageId, () => <String, Set<String>>{})
        .putIfAbsent(emojiId, () => <String>{})
        .add(userId);
  }

  @override
  Future<void> deleteReaction(
      String channelId, String messageId, String emojiId,
      {String? userId}) async {
    _reactions[messageId]?[emojiId]?.remove(userId ?? this.userId);
  }

  @override
  Future<void> clearReaction(String channelId, String messageId,
      {String? emojiId}) async {
    if (emojiId != null) {
      _reactions[messageId]?.remove(emojiId);
    } else {
      _reactions.remove(messageId);
    }
  }

  @override
  Future<Pagination<User>> getReactionList(
      String channelId, String messageId, String emojiId,
      {String? next}) async {
    final ids = _reactions[messageId]?[emojiId] ?? const <String>{};
    return Pagination<User>(
      <User>[for (final id in ids) users[id] ?? User(id: id)],
    );
  }

  @override
  Future<List<String>> createUpload(List<dynamic> blobs) async => <String>[
        for (var i = 0; i < blobs.length; i++)
          'memory://upload/${++_uploadSequence}',
      ];

  @override
  Future<Guild> getGuild(String id) async =>
      guilds[id] ?? (throw StateError('guild not found: $id'));

  @override
  Future<Pagination<Guild>> getGuildList({String? next}) async =>
      Pagination<Guild>(guilds.values.toList());

  @override
  Future<void> handleGuildRequest(String messageId, bool approve,
      {String? comment}) async {}

  @override
  Future<void> handleGuildMemberRequest(String messageId, bool approve,
      {String? comment}) async {}

  @override
  Future<GuildMember> getGuildMember(String guildId, String userId) async =>
      members['$guildId/$userId'] ??
      (throw StateError('member not found: $guildId/$userId'));

  @override
  Future<Pagination<GuildMember>> getGuildMemberList(String guildId,
      {String? next}) async {
    final data = <GuildMember>[
      for (final entry in members.entries)
        if (entry.key.startsWith('$guildId/')) entry.value,
    ];
    return Pagination<GuildMember>(data);
  }

  @override
  Future<void> muteGuildMember(String guildId, String userId,
      {int? duration, String? reason}) async {}

  @override
  Future<void> kickGuildMember(String guildId, String userId,
      {bool? permanent}) async {
    members.remove('$guildId/$userId');
  }

  @override
  Future<void> setGuildMemberRole(
      String guildId, String userId, String roleId) async {
    _memberRoles.putIfAbsent('$guildId/$userId', () => <String>{}).add(roleId);
  }

  @override
  Future<void> unsetGuildMemberRole(
      String guildId, String userId, String roleId) async {
    _memberRoles['$guildId/$userId']?.remove(roleId);
  }

  @override
  Future<Pagination<GuildRole>> getGuildMemberRoleList(
      String guildId, String userId,
      {String? next}) async {
    final ids = _memberRoles['$guildId/$userId'] ?? const <String>{};
    return Pagination<GuildRole>(
      <GuildRole>[
        for (final id in ids) roles[id] ?? GuildRole(id: id),
      ],
    );
  }

  @override
  Future<Pagination<GuildRole>> getGuildRoleList(String guildId,
          {String? next}) async =>
      Pagination<GuildRole>(roles.values.toList());

  @override
  Future<GuildRole> createGuildRole(String guildId,
      {String? name,
      int? color,
      int? position,
      BigInt? permissions,
      bool? hoist,
      bool? mentionable}) async {
    final role = GuildRole(
      id: 'r${++_roleSequence}',
      name: name,
      color: color,
      position: position,
      permissions: permissions,
      hoist: hoist,
      mentionable: mentionable,
    );
    roles[role.id] = role;
    return role;
  }

  @override
  Future<void> updateGuildRole(String guildId, String roleId,
      {String? name,
      int? color,
      int? position,
      BigInt? permissions,
      bool? hoist,
      bool? mentionable}) async {
    final current = roles[roleId];
    if (current == null) throw StateError('role not found: $roleId');
    roles[roleId] = GuildRole(
      id: current.id,
      name: name ?? current.name,
      color: color ?? current.color,
      position: position ?? current.position,
      permissions: permissions ?? current.permissions,
      hoist: hoist ?? current.hoist,
      mentionable: mentionable ?? current.mentionable,
    );
  }

  @override
  Future<void> deleteGuildRole(String guildId, String roleId) async {
    roles.remove(roleId);
  }

  @override
  Future<User> getUser(String userId) async =>
      users[userId] ?? (throw StateError('user not found: $userId'));

  @override
  Future<Pagination<Friend>> getFriendList({String? next}) async =>
      Pagination<Friend>(friends.values.toList());

  @override
  Future<void> deleteFriend(String userId) async {
    friends.remove(userId);
  }

  @override
  Future<void> handleFriendRequest(String messageId, bool approve,
      {String? comment}) async {}
}
