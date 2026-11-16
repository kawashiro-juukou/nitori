/// Adapter surface implemented by platform integrations.
///
/// The canonical definitions live in `nitori_core` (`src/server_adapter.dart`),
/// which also exports them, so this file only re-exports them here. A
/// `SatoriBot` is one login: it carries the identity headers and the full
/// method surface of the protocol. A `SatoriAdapter` owns the bots and emits
/// the events the server broadcasts over the gateway.
///
/// Keeping the definitions in core lets a pure client SDK (e.g. a Flutter app
/// on Android) implement this same surface without depending on
/// [nitori_server] — which would create a circular dependency, since the
/// protocol bridge here already depends on the client.
library;

export 'package:nitori_core/nitori_core.dart' show SatoriAdapter, SatoriBot;
