import '../base.dart';

class StrongElement extends BaseElement {
  StrongElement(String text) : super('strong', children: [Text(text)]);
}

class EmElement extends BaseElement {
  EmElement(String text) : super('em', children: [Text(text)]);
}

class InsElement extends BaseElement {
  InsElement(String text) : super('ins', children: [Text(text)]);
}

class DelElement extends BaseElement {
  DelElement(String text) : super('del', children: [Text(text)]);
}

class SplElement extends BaseElement {
  SplElement(String text) : super('spl', children: [Text(text)]);
}

class CodeElement extends BaseElement {
  CodeElement(String text) : super('code', children: [Text(text)]);
}

class SupElement extends BaseElement {
  SupElement(String text) : super('sup', children: [Text(text)]);
}

class SubElement extends BaseElement {
  SubElement(String text) : super('sub', children: [Text(text)]);
}
