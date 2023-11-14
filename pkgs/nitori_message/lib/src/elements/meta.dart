import '../base.dart';

class Quote extends Base {
  Quote({attributes, children})
      : super('quote', attributes: attributes, children: children);
}

class Author extends Base {
  String? userId;
  String? nickname;
  String? avatar;

  Author({this.userId, this.nickname, this.avatar, children})
      : super('author',
            attributes: {
              'user-id': userId,
              'nickname': nickname,
              'avatar': avatar
            },
            children: children);
}
