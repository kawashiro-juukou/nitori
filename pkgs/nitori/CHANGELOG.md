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
- Update dependencies to ^0.1.11

## [0.1.11] - 2026-11-11

### Changed
- Unified version bump across the monorepo

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

## [0.1.6] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.5] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.4] - 2026-11-11

### Added
- Umbrella package now depends on and re-exports core, message, client and server

### Removed
- Placeholder `Awesome` class

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
- Initial release of nitori
- Core protocol models and wire format (nitori_core)
- Message element builder and parser (nitori_message)
- Satori HTTP API client and WebSocket gateway (nitori_client)
- Satori HTTP API server and WebSocket gateway (nitori_server)
- Umbrella package re-exporting all sub-packages (nitori)

## 0.1.0

- Aligned with the unified monorepo version; umbrella exports stay minimal until sub-packages are complete.
