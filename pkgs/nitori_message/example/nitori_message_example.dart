import 'package:nitori_message/nitori_message.dart' as n;

void main() {
  var message = n.Message(children: [
    n.At(id: '001', name: 'Kawashiro Nitori'),
    n.Text('Hello, world!'),
    n.Image(src: 'https://example.com/image.png'),
    n.Br(),
    n.Strong('Welcome to Nitori: '),
    n.Sharp(id: '001', name: 'Kawashiro Channel'),
  ]);
  print(message);
}
