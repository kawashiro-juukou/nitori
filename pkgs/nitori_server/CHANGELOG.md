## 0.1.23

 - **FEAT**(bridge): local<->remote sequence number mapping (`translateLocalToRemoteSn`, `translateRemoteToLocalSn`).
 - **FEAT**(bridge): local client resume with local sn translates to remote sn and forces remote gateway reconnect (`onClientResume` callback).
 - **FEAT**(bridge): remote connection drop/reconnect uses last known remote sn.
 - **FIX**(bridge): prevent duplicate events when local resume translates to older remote sn (sn only moves forward).
 - **FEAT**(bridge): `satori-pagination` header bidirectional transparency across the bridge. Request header forwarded to remote internal method; response header mirrored back to local client. Fixed `_callBotInternal` to forward request headers and mirror response headers.
 - **FEAT**(bridge): webhook mirror mode verified — remote events automatically trigger local webhooks via `SatoriServer._publish` → `_dispatchWebhooks`.
 - **FEAT**(bridge): `BridgeEventDispatcher` standalone class implementing upstream `bot.dispatch` semantics (alias normalisation, `internal/session` first, then alias group). No duplication with `SatoriServer._publish`.
 - **TEST**: added pagination tests, resume transparency tests (including no-duplicate regression), webhook bridge tests, bridge dispatch tests.

## 0.1.22

 - **FIX**(bridge): identity headers (`satori-platform`/`satori-user-id`) no longer overrideable via `extraHeaders` in `RemoteSatoriBot.forwardInternal`.
 - **FEAT**(bridge): `RemoteSatoriAdapter` now accepts `platform`/`userId` for correct IDENTIFY in multi-platform bridging.
 - **PERF**(bridge): `_pendingRemoteSns` uses `Queue<int>` for O(1) dequeue.
 - **FIX**(core): `InMemoryBot.internal` proxy now correctly extracts method names from `Symbol`.
 - **CLEANUP**: deduplicate `SatoriBot`/`SatoriAdapter` definitions — server now re-exports from `nitori_core`.

## 0.1.21

 - **FEAT**(server): forward global internal routes across the protocol bridge. ([a21dfff1](https://github.com/kawashiro-juukou/nitori/commit/a21dfff134981cbe5a7ebe0991cf6f5036913032))
 - **FEAT**(server): map local<->remote sequence numbers in RemoteSatoriAdapter. ([b04fea86](https://github.com/kawashiro-juukou/nitori/commit/b04fea8651a4cc66191420b774429d3751c166de))
 - **DOCS**(server): document protocol bridge and add example. ([e2b5757e](https://github.com/kawashiro-juukou/nitori/commit/e2b5757e552f06e4f5734a9cb568bab3a9cfdeaf))

## 0.1.20

 - **FEAT**: add `RemoteSatoriAdapter` protocol bridge — connects to a remote Satori server over HTTP + WebSocket and maps its logins/events into local `SatoriAdapter`/`SatoriBot` objects, including `internal` proxying via `JsonForm`.

## 0.1.19

 - **FEAT**: features auto-derivation (`SatoriBot.supportedMethods`/`features`), `session()`/`dispatch()` upstream semantics, full internal routing (`/_tmp`, `/_api`, bot-level router), `createUpload` returns `internal:/_tmp/<id>` URLs.

## 0.1.18

 - **FEAT**: P0 server routes (meta, webhook, proxy, admin, internal).

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

### Added
- `POST /v1/meta` endpoint returning server metadata (logins + proxy_urls)
- `POST /v1/meta/webhook.create` and `POST /v1/meta/webhook.delete` for webhook management
- `GET /v1/proxy/*url` media proxy with CORS and proxy URL allowlist
- `ALL /v1/admin/*path` redirects to `/v1/meta/*path`
- `ALL /v1/internal/*path` route (stub, returns 404)
- Configurable `path` prefix (upstream default `/satori`)
- Event delivery to registered webhooks with `Satori-Opcode` header

### Changed
- `SatoriServer` constructor adds `path`, `webhooks` parameters

## [0.1.14] - 2026-11-13

### Fixed
- Align gateway dispatch with upstream `eventAliases`: an adapter emitting any
  member of an alias group now rewrites the emitted type to the canonical
  (first) name before it is buffered and broadcast
- `InMemoryBot.getMessageIter` now walks newest first (upstream derives the
  iterator from `getMessageList` and reverses the page)

## [0.1.13] - 2026-11-12

### Added
- `InMemoryBot` implementations for all async iterator methods, `sendPrivateMessage`
  and `updateCommands`

### Changed
- Protocol compliance: `SatoriBot` now implements the full upstream method
  surface including iterators and `updateCommands`

## [0.1.12] - 2026-11-11

### Fixed
- Remove `dependency_overrides` from published package (local dev only)
- Update nitori_core dependency to ^0.1.11

## [0.1.11] - 2026-11-11

### Fixed
- Use `Event.deepCopy()` in `_publish` to prevent adapter mutations from affecting replay buffer

## [0.1.10] - 2026-11-11

### Added
- Configurable rate limiting (token bucket) for HTTP API and WebSocket gateway
  - Scopes: IP, identity (platform + user ID), token, global
  - HTTP rate limit returns 429 with Retry-After header
  - WebSocket connect/event rate limiting
  - Default disabled for backward compatibility

### Changed
- Unified version bump across the monorepo

## [0.1.9] - 2026-11-11

### Added
- Documentation comments for all public APIs

### Fixed
- Deep copy Event in `_publish` to prevent adapter mutation from affecting replay buffer
- Reject duplicate multipart part names in `upload.create`

### Changed
- Unified version bump across the monorepo

## [0.1.8] - 2026-11-11

### Changed
- SDK constraint upgraded to ^3.5.0 across monorepo

## [0.1.7] - 2026-11-11

### Changed
- SDK constraint unified to ^3.2.0 across monorepo

## [0.1.6] - 2026-11-11

### Added
- Satori HTTP API (`/v1/*`) and WebSocket gateway (`/v1/events`) implementation
- 37 standard methods with full request/response mapping
- In-memory adapter (`InMemoryAdapter`) for testing

### Fixed
- Request body size limit (32 MiB) with 413 response
- Multipart parsing errors return 400 instead of 500
- Event encoding done once per broadcast; serialization failures no longer drop clients
- Replay buffer uses server enqueue time (not adapter timestamp) with O(1) eviction
- Adapter stream errors logged via `onError` without crashing
- WebSocket dead connections closed with `pingInterval=30s`
- Unimplemented adapter methods return 404
- Resume (`sn > 0` only) and login event filtering per spec
- Events shallow-copied on publish; caller object never mutated
- Concurrent socket close in `close()`; server socket always closed
- Constant-time token comparison for auth

### Changed
- SDK constraint upgraded to `^3.2.0` for `mime` dependency compatibility

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

### Changed
- Unified version bump across the monorepo

## [0.1.1] - 2026-11-10

### Fixed
- Package metadata: expanded descriptions to meet pub.dev requirements
- Corrected satori protocol documentation URLs to satori.chat
- Added missing platform declarations
- Fixed missing type annotations for lints_core compatibility

## [0.1.0] - 2026-11-09

### Added
- Initial release of nitori_server
- Core protocol models and wire format (nitori_core)
- Message element builder and parser (nitori_message)
- Satori HTTP API client and WebSocket gateway (nitori_client)
- Satori HTTP API server and WebSocket gateway (nitori_server)
- Umbrella package re-exporting all sub-packages (nitori)

## 0.1.0

- Initial scaffold aligned with the unified monorepo version (previous 1.0.0 was premature).
