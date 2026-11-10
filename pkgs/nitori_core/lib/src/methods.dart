/// The Satori method registry, mirroring `packages/protocol/src/index.ts`.
///
/// [methods] maps each `resource.method` key to the Dart method name, the
/// wire-visible field names and the payload encoding, so that a driver can
/// dispatch a request by resource name instead of a switch statement.
library;

/// A single entry of the upstream `Methods` table.
class Method {
  const Method(this.name, this.fields, {this.isForm = false});

  /// Lower-case Dart method name used by the SDK.
  final String name;

  /// Wire-visible argument names, in call order.
  final List<String> fields;

  /// Whether the payload is sent as `multipart/form-data` instead of JSON.
  final bool isForm;
}

const Map<String, Method> methods = <String, Method>{
  'channel.get': Method('getChannel', ['channel_id', 'guild_id']),
  'channel.list': Method('getChannelList', ['guild_id', 'next']),
  'channel.create': Method('createChannel', ['guild_id', 'data']),
  'channel.update': Method('updateChannel', ['channel_id', 'data']),
  'channel.delete': Method('deleteChannel', ['channel_id']),
  'channel.mute': Method('muteChannel', ['channel_id', 'guild_id', 'enable']),
  'message.create':
      Method('createMessage', ['channel_id', 'content', 'referrer']),
  'message.update':
      Method('editMessage', ['channel_id', 'message_id', 'content']),
  'message.delete': Method('deleteMessage', ['channel_id', 'message_id']),
  'message.get': Method('getMessage', ['channel_id', 'message_id']),
  'message.list': Method(
      'getMessageList', ['channel_id', 'next', 'direction', 'limit', 'order']),
  'reaction.create':
      Method('createReaction', ['channel_id', 'message_id', 'emoji_id']),
  'reaction.delete': Method(
      'deleteReaction', ['channel_id', 'message_id', 'emoji_id', 'user_id']),
  'reaction.clear':
      Method('clearReaction', ['channel_id', 'message_id', 'emoji_id']),
  'reaction.list': Method(
      'getReactionList', ['channel_id', 'message_id', 'emoji_id', 'next']),
  'upload.create': Method('createUpload', [], isForm: true),
  'guild.get': Method('getGuild', ['guild_id']),
  'guild.list': Method('getGuildList', ['next']),
  'guild.member.get': Method('getGuildMember', ['guild_id', 'user_id']),
  'guild.member.list': Method('getGuildMemberList', ['guild_id', 'next']),
  'guild.member.kick':
      Method('kickGuildMember', ['guild_id', 'user_id', 'permanent']),
  'guild.member.mute':
      Method('muteGuildMember', ['guild_id', 'user_id', 'duration', 'reason']),
  'guild.member.role.set':
      Method('setGuildMemberRole', ['guild_id', 'user_id', 'role_id']),
  'guild.member.role.unset':
      Method('unsetGuildMemberRole', ['guild_id', 'user_id', 'role_id']),
  'guild.member.role.list':
      Method('getGuildMemberRoleList', ['guild_id', 'user_id', 'next']),
  'guild.role.list': Method('getGuildRoleList', ['guild_id', 'next']),
  'guild.role.create': Method('createGuildRole', ['guild_id', 'data']),
  'guild.role.update':
      Method('updateGuildRole', ['guild_id', 'role_id', 'data']),
  'guild.role.delete': Method('deleteGuildRole', ['guild_id', 'role_id']),
  'login.get': Method('getLogin', []),
  'user.get': Method('getUser', ['user_id']),
  'user.channel.create': Method('createDirectChannel', ['user_id', 'guild_id']),
  'friend.list': Method('getFriendList', ['next']),
  'friend.delete': Method('deleteFriend', ['user_id']),
  'friend.approve':
      Method('handleFriendRequest', ['message_id', 'approve', 'comment']),
  'guild.approve':
      Method('handleGuildRequest', ['message_id', 'approve', 'comment']),
  'guild.member.approve':
      Method('handleGuildMemberRequest', ['message_id', 'approve', 'comment']),
};

/// Every `resource.method` key that must be present in [methods].
const List<String> methodKeys = <String>[
  'channel.get',
  'channel.list',
  'channel.create',
  'channel.update',
  'channel.delete',
  'channel.mute',
  'message.create',
  'message.update',
  'message.delete',
  'message.get',
  'message.list',
  'reaction.create',
  'reaction.delete',
  'reaction.clear',
  'reaction.list',
  'upload.create',
  'guild.get',
  'guild.list',
  'guild.member.get',
  'guild.member.list',
  'guild.member.kick',
  'guild.member.mute',
  'guild.member.role.set',
  'guild.member.role.unset',
  'guild.member.role.list',
  'guild.role.list',
  'guild.role.create',
  'guild.role.update',
  'guild.role.delete',
  'login.get',
  'user.get',
  'user.channel.create',
  'friend.list',
  'friend.delete',
  'friend.approve',
  'guild.approve',
  'guild.member.approve',
];
