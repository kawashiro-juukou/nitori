# Protocol Bridge

`RemoteSatoriAdapter` turns nitori into a **Satori protocol bridge**: a local
`SatoriServer` that mirrors a remote Satori server's logins and events, so
local Satori clients can work with platforms (Telegram, Discord, ...) that only
have a Node-side adapter.

## Architecture

```
[Telegram] [Discord] ...          upstream @satorijs/adapter-* (Node packages)
     |                                  |
     +-----------------+----------------+
                       v
        remote Satori server           e.g. Koishi with @koishijs/plugin-server-satori,
        (standard Satori API)          or any @satorijs/plugin-server deployment
                       |
                       |  network: HTTP POST /v1/*  +  WebSocket /v1/events
                       v
        nitori_client (NitoriClient / Gateway)
                       |
        RemoteSatoriAdapter            pkgs/nitori_server/lib/src/remote_adapter.dart
                       |               mirrors bots + events locally
        SatoriServer (local)           re-numbers `sn`, buffers for replay,
                       |               broadcasts to local clients
                       v
        local Satori clients           nitori_client, or any Satori client
```

- Upstream, the remote server runs `@satorijs/plugin-server` (the `@satorijs/satori`
  monorepo's server package), which serves the standard Satori HTTP API
  (`/v1/<method>`) and WebSocket gateway (`/v1/events`). Upstream platform
  adapters such as `@satorijs/adapter-telegram` plug into that server and turn
  platform webhooks/polling into Satori events.
- Downstream, `RemoteSatoriAdapter` is just a Satori client: it connects to
  `/v1/events`, performs IDENTIFY with the token, receives
  READY/META/EVENT/PING/PONG, and mirrors each remote login as a local
  `RemoteSatoriBot`. A local `SatoriServer` wraps the adapter, so everything
  behind it looks like an ordinary Satori server.
- Event sequence numbers (`sn`) are **not** forwarded: the local server assigns
  fresh `sn` values on publish, and buffers events locally for session-resume
  replay. Login lifecycle events (`login-added` / `login-updated` /
  `login-removed`) keep the local bot list in sync.

## Why not run JS in the Dart VM?

The upstream adapters (`@satorijs/adapter-telegram` etc.) are Node.js packages;
running them inside a Dart process would mean embedding a JS runtime, which is
heavy and fragile. But we don't need to: the Satori protocol between a server
and its clients is language-neutral HTTP + WebSocket. Bridging at the protocol
level — a Dart client in front of a Node Satori server — gets the upstream
adapter ecosystem without a JS runtime, and keeps the bridge a thin, dumb
relay.

## Node side (upstream)

To expose a platform adapter over the Satori protocol you need a Node
application that loads the adapter and a Satori server plugin. In a Koishi
setup this is simply: enable `@koishijs/plugin-server-satori` and add the
platform adapter; the plugin serves the standard `/v1/*` API and `/v1/events`
gateway (default path `/satori`, so the base URL for the bridge would be
`http://host:5140/satori`). In a plain cordis/satorijs application, the same is
achieved by loading a router (`@cordisjs/plugin-server`) and the Satori server
plugin (`@satorijs/plugin-server`, which registers itself as `ctx.satori.server`)
alongside the adapter — see the `@satorijs/satori` README's basic usage for the
`ctx.plugin(...)` pattern. We do not duplicate a full Node snippet here because
the exact wiring differs between Koishi and bare cordis apps; the important
contract is just: **a reachable Satori server endpoint (base URL + optional
token)**.

## Dart side (downstream)

```dart
import 'package:nitori_server/nitori_server.dart';

final adapter = RemoteSatoriAdapter(
  baseUrl: 'http://127.0.0.1:5140',   // remote Satori server
  token: 'remote-token',              // optional, used for IDENTIFY
);

// Bots mirror the remote logins once READY arrives.
await adapter.start();

final server = SatoriServer(adapter: adapter);
await server.bind(port: 5141);        // serve local clients
```

Local clients then talk to `http://localhost:5141` as if it were any Satori
server. A runnable version of this lives in
[`example/remote_bridge_example.dart`](example/remote_bridge_example.dart).

## Internal routing across the bridge

The Satori internal surface also bridges end to end:

- `bot.internal.foo(...)` on a local `RemoteSatoriBot` encodes the arguments as
  a `JsonForm` body and POSTs to the remote server's
  `/v1/internal/<platform>/<selfId>/_api/foo` endpoint, decoding the JsonForm
  response. The remote side resolves `foo` against its own bot's internal
  methods (dot notation, e.g. `internal/someMethod`).
- Requests arriving at the **local** server under
  `/v1/internal/<platform>/<selfId>/...` behave like on any nitori server:
  `/_tmp/:id` (GET, 10-minute TTL temp uploads) and `/_api/:name` (POST,
  JsonForm) are served globally, and any remaining path falls through to
  bot-level routes registered with `bot.defineInternalRoute(...)`. On a
  `RemoteSatoriBot`, unmatched paths are proxied to the remote server's
  corresponding internal endpoint, so bot-level internal routes defined
  upstream remain callable through the bridge.

## features and proxyUrls

- `features`: the remote login's `features` set (the method keys the upstream
  bot actually implements) is mirrored verbatim; `RemoteSatoriBot.features` and
  `RemoteSatoriBot.supportedMethods` both return it. Local READY/META frames
  therefore advertise exactly what the upstream bot supports, instead of the
  conservative "all 37 methods" default.
- `proxyUrls`: URLs received in the remote READY/META frames are exposed via
  `adapter.proxyUrls` and included in the local server's READY/META and
  `/v1/proxy/*` allowlist, so media proxying keeps working through the bridge.

## What is still not aligned

- `sn` renumbering means the local and remote sequence spaces differ; a resume
  against the local server replays locally-buffered events only.
- Only bot-level internal routes are proxied upstream; global internal routes
  (`/_tmp`, `/_api`) are handled locally and are not forwarded.
- Event alias normalization happens on the local server; events are forwarded
  as received remotely, without consulting upstream dispatch middleware.
- Webhooks registered on the local server fire on locally-published events
  only; the remote server's webhooks are not managed through the bridge.
- No support yet for forwarding `satori-pagination` semantics on proxied
  internal calls.
