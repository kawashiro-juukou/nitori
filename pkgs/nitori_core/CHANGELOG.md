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

### Added
- Async iterator methods to protocol interfaces: `getMessageIter`,
  `getReactionIter`, `getChannelIter`, `getGuildIter`, `getGuildMemberIter`,
  `getGuildRoleIter`, `getFriendIter`
- `sendPrivateMessage` to `MessageInterface`
- `CommandInterface` with `updateCommands`

### Changed
- Protocol interfaces changed from `abstract interface class` to
  `abstract class` so they can be `implements` targets

## [0.1.12] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.11] - 2026-11-11

### Fixed
- Use `Event.deepCopy()` in server `_publish` to prevent adapter mutations from affecting replay buffer

### Added
- `NitoriBot.sendPrivateMessage()` convenience method (nitori_client)
- `NitoriBot.sendMessage()` returning message IDs (nitori_client)

## [0.1.10] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.9] - 2026-11-11

### Added
- `Event.deepCopy()` and `Message.deepCopy()` for deep isolation of nested objects

### Changed
- Unified version bump across the monorepo

## [0.1.8] - 2026-11-11

### Changed
- SDK constraint upgraded to ^3.5.0 across monorepo

## [0.1.7] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.6] - 2026-11-11

### Fixed
- Type `Message.elements` as `List<Map<String, Object?>>` instead of `List<dynamic>`

## [0.1.5] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.4] - 2026-11-11

### Changed
- Unified version bump across the monorepo

## [0.1.3] - 2026-11-11

### Fixed
- Export event, command, resource and escaping libraries publicly
- Remove unused placeholder `Event<T>` / `EventType` from base.dart

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
