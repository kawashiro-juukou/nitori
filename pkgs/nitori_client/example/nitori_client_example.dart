import 'dart:convert';
import 'dart:io';

import 'package:nitori_client/nitori_client.dart';
import 'package:nitori_core/nitori_core.dart';

/// Connects to a Satori server, prints incoming events and sends one message.
///
/// Set `SATORI_BASE_URL` and `SATORI_TOKEN` to point at your endpoint.
Future<void> main() async {
  final baseUrl =
      Platform.environment['SATORI_BASE_URL'] ?? 'http://localhost:5140';
  final token = Platform.environment['SATORI_TOKEN'] ?? '';

  final client = NitoriClient(baseUrl: baseUrl, token: token);
  client.events.listen((event) {
    print('[${event.type}] ${jsonEncode(event.data)}');
  });
  client.onStatusChanged = (status) => print('status: $status');

  await client.start();
  print('connected, ${client.bots.length} bot(s):');
  for (final bot in client.bots) {
    print('  - ${bot.platform} / ${bot.userId}');
    // The method table is part of the protocol; check before dispatching.
    if (!methods.containsKey('message.create')) continue;
    final channelId = Platform.environment['SATORI_CHANNEL_ID'] ?? '123456789';
    try {
      final messages = await bot.createMessage(
        channelId,
        'hello from nitori_client',
      );
      print('  sent message: ${messages.map((m) => m.id)}');
    } catch (error) {
      print('  failed to send message: $error');
    }
  }

  // Keep the process alive so events keep flowing; Ctrl+C to exit.
  await ProcessSignal.sigint.watch().first;
  await client.stop();
  client.close();
}
