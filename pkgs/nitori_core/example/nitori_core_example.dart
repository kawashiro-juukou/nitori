import 'package:nitori_core/nitori_core.dart';

void main() {
  final channel = Channel(id: '123', type: ChannelType.text, name: 'test');

  print(channel.toJson());
}
