import 'package:nitori_message/nitori_message.dart';

void main() {
  var message = Message(
    children: [
      At(id: '001', name: 'alice'),
      Text('Hello, '),
      Bold('world'),
      Image(src: 'https://example.com/image.png'),
    ],
  );
  print(message);

  var nodes = parse('<at id="002" name="bob" />Welcome to Nitori!');
  print(nodes);
}
