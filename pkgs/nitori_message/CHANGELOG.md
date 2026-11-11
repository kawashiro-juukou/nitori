# Changelog

All notable changes to this project will be documented in this file.

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

### Added
- `Button` element (`<button>`) with text and children constructors, plus parser support

### Fixed
- Parser closing-tag validation for container elements that carry attributes

## [0.1.5] - 2026-11-11

### Added
- `Button` element (`<button>`) with text and children constructors, plus parser support

### Fixed
- Parser closing-tag validation for container elements that carry attributes

## [0.1.4] - 2026-11-11

### Added
- Runnable `example/nitori_message_example.dart`

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
- Initial release of nitori_message
- Core protocol models and wire format (nitori_core)
- Message element builder and parser (nitori_message)
- Satori HTTP API client and WebSocket gateway (nitori_client)
- Satori HTTP API server and WebSocket gateway (nitori_server)
- Umbrella package re-exporting all sub-packages (nitori)

## 0.1.0

- Aligned with the unified monorepo version.

## 0.0.1+2

- Added comments and documents for every exposed class and function. ([#14](https://github.com/kawashiro-juukou/nitori/pull/14))

## 0.0.1+1

- Added `topics` and `platforms` to `pubspec.yaml`. ([39ba89](https://github.com/kawashiro-juukou/nitori/commit/39ba89eb55e66698b9ab11e8d3c5c93ddaecb249))

## 0.0.1

- Initial support for basic message building and parsing.
