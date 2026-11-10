import 'package:nitori/nitori.dart';

void main() {
  var channel = Channel(id: '001', type: ChannelType.text, name: 'general');
  print('channel: ${channel.name}');

  var nodes = parse('<at id="001" name="alice" />Hello, world!');
  var at = nodes.first as At;
  print('mention: ${at.name}');
  print('elements: $nodes');
}
