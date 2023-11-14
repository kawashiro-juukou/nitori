import 'package:nitori_message/nitori_message.dart' as n;

void main() {
  print(n.At(id: '001', name: 'Kawashiro Nitori'));
  print(n.At(type: 'all'));
  print(n.At(role: 'admin'));

  print(n.Sharp(id: '001', name: 'Kawashiro Channel'));

  print(n.A(href: 'https://example.com/link'));
}
