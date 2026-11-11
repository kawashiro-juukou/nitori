# Changelog

All notable changes to this project will be documented in this file.

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
