import '../base.dart';

class QuoteElement extends BaseElement {
  QuoteElement({attributes, children})
      : super('quote', attributes: attributes, children: children);
}

class AuthorElement extends BaseElement {
  String? userId;
  String? nickname;
  String? avatar;

  AuthorElement({this.userId, this.nickname, this.avatar, children})
      : super('author',
            attributes: {userId, nickname, avatar}, children: children);
}
