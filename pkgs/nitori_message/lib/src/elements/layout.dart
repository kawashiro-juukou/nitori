import '../base.dart';

class Br extends Base {
  Br() : super('br');
}

class P extends Base {
  P({attributes, children})
      : super('p', attributes: attributes, children: children);
}

class Message extends Base {
  String? id;
  bool? forward;

  Message({this.id, this.forward, children})
      : super('message',
            attributes: {'id': id, 'forward': forward}, children: children);
}
