## 0.1.27

 - **FEAT**: `NitoriBot` now holds a `SatoriApiClient api` and issues its requests through it; the HTTP helpers (`request`, `requestFullPathBytes`, `forwardFullPathBytes`, `download`, `downloadStream`) live on the bot.
 - **DEPRECATED**: `NitoriBot.client` is a deprecated getter returning the `NitoriClient` the bot was built from; construct bots with the api client instead.

## 0.1.26

 - **FEAT**: `SatoriGatewayClient` owns the WebSocket gateway lifecycle (connect, IDENTIFY, heartbeat, reconnect, event decode); `SatoriGatewayEvent` and `SatoriGatewayException` are the renamed `GatewayEvent` / `GatewayException`.
 - **DEPRECATED**: `Gateway`, `GatewayEvent` and `GatewayException` remain as deprecated typedef aliases of their `Satori*` counterparts.

## 0.1.25

 - **FEAT**: `SatoriApiClient` owns the HTTP API surface (requests, multipart upload, media download, proxy resolution and `SatoriApiException`), separate from the WebSocket gateway.
 - **FEAT**: `SatoriApiIdentity` carries the `satori-platform` / `satori-user-id` pair a request is made on behalf of.
 - **FEAT**: `NitoriClient.api` exposes the underlying `SatoriApiClient`; existing `NitoriClient` methods delegate to it and behave unchanged.
 - **REFACTOR**: the bot API methods now run through `SatoriApiClient` instead of `NitoriClient` internals.

## 0.1.24

 - **FEAT**: `NitoriBot.onButton` and `offButton` register handlers by `button.id`; incoming `interaction/button` events are dispatched to the owning bot.
 - **FEAT**: `NitoriClient.onButtonError` receives errors thrown by button handlers.
 - **TEST**: `interaction_test.dart` covers dispatch, unregistered ids, removal and non-interaction events.

## 0.1.23

 - **FEAT**: `NitoriClient.proxyUrl` and `proxyUrlOr` route media URLs through the server proxy when they match an advertised `proxyUrls` prefix.
 - **FEAT**: upload methods accept `JsonBlob`, forwarding its filename and content type in the multipart part.
 - **FEAT**: `NitoriClient.downloadStream` and `download` fetch media bytes, optionally through the proxy.
 - **REFACTOR**: multipart request building is shared by the bot API and the generic `request`.
 - **TEST**: `media_test.dart` covers proxy resolution, `JsonBlob` uploads and downloads.

## 0.1.22

 - **FEAT**: `GatewayEvent.event` decodes a gateway frame into the protocol `Event` model.
 - **FEAT**: `NitoriClient.eventStream` streams typed events, excluding `login-*` frames.
 - **TEST**: `events_test.dart` covers decoding and login-frame filtering.

## 0.1.21

 - **FEAT**: `createMessage`, `sendMessage`, `editMessage` and `sendPrivateMessage` accept a `String`, a `Node` or an `Iterable<Node>` as content; typed nodes are rendered to element markup before sending.
 - **FEAT**: added a dependency on `nitori_message` for the element DSL.
 - **CLEANUP**: removed the `linkPreview` parameter from `sendMessage` and `sendPrivateMessage`; it was never sent on the wire.
 - **TEST**: typed-content cases in `http_test.dart`.

## 0.1.20

 - **FEAT**: `NitoriClient`/`Gateway` accept `platform`/`userId` for `IDENTIFY.body.satori-platform` / `satori-user-id`.
 - **FEAT**: `lastReceivedSn` getter and `resumeFrom(int)` for application-layer resume idempotency.
 - **FEAT**: multi-login management — `getBot()`, `addBot()`, `removeBot()`, `botsByPlatform()`.
 - **CLEANUP**: removed dead `payload` code in `request()`, deduplicated body building via `_internalBody()`.
 - **TEST**: added `identity_test.dart`, `multi_login_test.dart`, `resume_test.dart`.

## 0.1.19

 - **FEAT**(server): forward global internal routes across the protocol bridge. ([a21dfff1](https://github.com/kawashiro-juukou/nitori/commit/a21dfff134981cbe5a7ebe0991cf6f5036913032))

## 0.1.18

 - **FEAT**: add public `request()`/`requestFullPath()` for arbitrary protocol paths with custom headers, iterator methods, `updateCommands`, and external READY/META callbacks.

## 0.1.17

 - **FEAT**(server): merge P0 routes (meta, webhook, proxy, admin, internal). ([f622fe80](https://github.com/kawashiro-juukou/nitori/commit/f622fe80fc3ef2fbbe0d4044a016ef29daea9252))
 - **FEAT**: implement P0 server routes (meta, webhook, proxy, admin, internal). ([33dc57bb](https://github.com/kawashiro-juukou/nitori/commit/33dc57bb3a2f33032ab5077eb03267ee69e64a31))

## 0.1.16

 - **FEAT**(server): merge P0 routes (meta, webhook, proxy, admin, internal). ([f622fe80](https://github.com/kawashiro-juukou/nitori/commit/f622fe80fc3ef2fbbe0d4044a016ef29daea9252))
 - **FEAT**: implement P0 server routes (meta, webhook, proxy, admin, internal). ([33dc57bb](https://github.com/kawashiro-juukou/nitori/commit/33dc57bb3a2f33032ab5077eb03267ee69e64a31))

## 0.1.15

 - **REFACTOR**: migrate to melos 8 and pub workspaces. ([da3748fd](https://github.com/kawashiro-juukou/nitori/commit/da3748fd1e34875a81cfcc38bb14ea637bfb77f8))

# Changelog

All notable changes to this project will be documented in this file.

## [0.1.15] - 2026-11-13

### Changed
- Unified version bump across the monorepo

## [0.1.14] - 2026-11-13

### Changed
- Unified version bump across the monorepo

## [0.1.13] - 2026-11-12

### Changed
- Unified version bump across the monorepo

## [0.1.12] - 2026-11-11

### Fixed
- Remove `dependency_overrides` from published package (local dev only)
- Update nitori_core dependency to ^0.1.11

## [0.1.11] - 2026-11-11

### Added
- `NitoriBot.sendPrivateMessage()` convenience method for sending DMs
- `NitoriBot.sendMessage()` returning message IDs

### Fixed
- Use `Event.deepCopy()` in server `_publish` to prevent adapter mutations from affecting replay buffer

## [0.1.10] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.9] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.8] - 2026-11-11

### Changed
- SDK constraint upgraded to ^3.5.0 across monorepo

## [0.1.7] - 2026-11-11

### Changed
- Unified version bump across the monorepo
- SDK constraint upgraded to ^3.2.0

## [0.1.6] - 2026-11-11

### Added
- Satori HTTP API client and WebSocket gateway

### Fixed
- Body size limit (32 MiB) on HTTP uploads
- Multipart parser error handling returns 400
- Constant-time token comparison

## [0.1.5] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.4] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.3] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.2] - 2026-11-11

### Added
- Satori HTTP API client and WebSocket gateway (nitori_client)

### Fixed
- Use `@v1.8.1` reusable publish workflow; publish all packages

## [0.1.1] - 2026-11-10

### Fixed
- Package metadata: expanded descriptions to meet pub.dev requirements
- Corrected satori protocol documentation URLs to satori.chat
- Added missing platform declarations
- Fixed missing type annotations for lints_core compatibility

## [0.1.0] - 2026-11-09

### Added
- Initial release of nitori_client
- Satori HTTP API client and WebSocket gateway
