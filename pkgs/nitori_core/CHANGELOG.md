# Changelog

All notable changes to this project will be documented in this file.

## [0.1.2] - 2026-11-11

### Added
- Event, Meta, Command, Argv, Resource codec and eventAliases (nitori_core)
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
- Initial release of nitori_core
- Core protocol models and wire format (nitori_core)
- Message element builder and parser (nitori_message)
- Satori HTTP API client and WebSocket gateway (nitori_client)
- Satori HTTP API server and WebSocket gateway (nitori_server)
- Umbrella package re-exporting all sub-packages (nitori)

## 0.1.0

- Aligned with the unified monorepo version.

## 0.0.2

- Break: fix `ChannelType` wire values (TEXT=0, DIRECT=1, CATEGORY=2, VOICE=3)
- Break: fix `Status` wire values (serialize as integers instead of names)
- Break: fix `Message.createdAt`/`updatedAt` and `GuildMember.joinedAt` to milliseconds
- Break: fix `Message.toJson` to serialize nested resources as maps
- Add `sn`, `adapter`, `features` and `hidden` to `Login`
- Add `timestamp`, `quote` and `elements` to `Message`
- Add `name`, `title` and `roles` to `GuildMember`
- Add `color`, `position`, `permissions`, `hoist` and `mentionable` to `GuildRole`
- Add `BidiList`, `Direction`, `Order`, `Opcode`, `Friend`, `Button` and `Emoji`
- Add `transformKey` and the `Methods` registry
- Add JSON round-trip, wire format and Methods coverage tests

## 0.0.1

- Initial version, add basic classes for Satori Protocol.
