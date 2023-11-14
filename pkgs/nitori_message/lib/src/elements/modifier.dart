import '../base.dart';

class Strong extends Base {
  Strong(String text) : super('strong', children: [Text(text)]);
}

class Em extends Base {
  Em(String text) : super('em', children: [Text(text)]);
}

class Ins extends Base {
  Ins(String text) : super('ins', children: [Text(text)]);
}

class Del extends Base {
  Del(String text) : super('del', children: [Text(text)]);
}

class Spl extends Base {
  Spl(String text) : super('spl', children: [Text(text)]);
}

class Code extends Base {
  Code(String text) : super('code', children: [Text(text)]);
}

class Sup extends Base {
  Sup(String text) : super('sup', children: [Text(text)]);
}

class Sub extends Base {
  Sub(String text) : super('sub', children: [Text(text)]);
}
