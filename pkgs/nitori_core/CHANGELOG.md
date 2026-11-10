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
