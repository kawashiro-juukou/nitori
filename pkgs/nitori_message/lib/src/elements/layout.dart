import '../base.dart';

class BrElement extends BaseElement {
  BrElement() : super('br');
}

class PElement extends BaseElement {
  PElement({attributes, children})
      : super('p', attributes: attributes, children: children);
}

class MessageElement extends BaseElement {
  String? id;
  bool? forward;

  MessageElement({this.id, this.forward, children})
      : super('message',
            attributes: {id: id, forward: forward}, children: children);
}
