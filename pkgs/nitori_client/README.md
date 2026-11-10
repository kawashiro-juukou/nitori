# nitori_client

A Dart client for the [Satori Protocol](https://satori.chat): a WebSocket
gateway plus the full HTTP API surface.

## Usage

```dart
import 'package:nitori_client/nitori_client.dart';

Future<void> main() async {
  final client = NitoriClient(
    baseUrl: 'http://localhost:5140',
    token: 'your-token',
  );

  client.events.listen((event) {
    print('[${event.type}] ${event.data}');
  });

  await client.start();

  for (final bot in client.bots) {
    await bot.createMessage('channel-id', 'hello');
  }

  await client.stop();
  client.close();
}
```

### API calls

`NitoriClient` resolves the bot list from the gateway READY payload and keeps
it in sync with `login-added` / `login-updated` / `login-removed` events. Every
`NitoriBot` carries the identity headers (`satori-platform`,
`satori-user-id`) and exposes the protocol methods:

```dart
final message = await bot.getMessage(channelId, messageId);
final page = await bot.getMessageList(channelId, limit: 50);
final channel = await bot.createDirectChannel(userId);
```

HTTP-only usage is supported too: build a `NitoriBot` directly with an explicit
platform and user id, and never call `start()`.

### Reconnection

The gateway reconnects automatically. The next IDENTIFY after a drop carries
the last received event sequence, so the server replays missed events.

## Example

See `example/nitori_client_example.dart` for a runnable demo. Point
`SATORI_BASE_URL` and `SATORI_TOKEN` at your endpoint, then:

```sh
dart run example/nitori_client_example.dart
```

## Supported methods

All 37 protocol methods are implemented, including the multipart
`upload.create`. Responses are deserialized into the `nitori_core` models
(`Channel`, `Message`, `Guild`, `Login`, ...) with `Pagination` / `BidiList`
for list payloads.