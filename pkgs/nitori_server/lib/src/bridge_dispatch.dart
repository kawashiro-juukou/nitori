/// BridgeEventDispatcher: Observes bridge dispatches without re-publishing
/// into the server pipeline.
///
/// Implements upstream `bot.dispatch(session)` semantics exactly:
/// 1. Find the alias group containing `session.event.type` in `eventAliases`
///    (from nitori_core; `expandEventAliases(type)` returns the group).
/// 2. If found, replace `session.event.type` with the canonical (first) name
///    of the group.
/// 3. Emit `internal/session` FIRST (on `internalSessions` stream).
/// 4. Then emit each alias member (including the canonical) as a separate
///    event (on `events` stream).
///
/// This class is standalone and does NOT touch SatoriServer's publish path,
/// so no event duplication occurs.
library;

import 'dart:async';

import 'package:nitori_core/nitori_core.dart';
import 'package:nitori_server/nitori_server.dart';

/// BridgeEventDispatcher implements the upstream dispatch semantics for the bridge.
///
/// It emits two streams:
/// - [internalSessions]: receives the `internal/session` event first
/// - [events]: receives each alias member as a separate event
///
/// The [bot] parameter must have `platform`, `userId`, and `login` getters
/// (as [SatoriBot] does). Any object satisfying this interface works.
///
/// Usage:
/// ```dart
/// final dispatcher = BridgeEventDispatcher(bot);
/// dispatcher.internalSessions.listen((session) => ...);
/// dispatcher.events.listen((event) => ...);
/// dispatcher.dispatch(session);
/// ```
class BridgeEventDispatcher {
  /// Creates a dispatcher for [bot].
  ///
  /// [bot] must have `platform` (String), `userId` (String), and `login` (Login)
  /// getters. [SatoriBot] and [RemoteSatoriBot] satisfy this.
  BridgeEventDispatcher(SatoriBot bot) {
    _internalSessionsController = StreamController<Session>.broadcast();
    _eventsController = StreamController<Event>.broadcast();
  }

  late final StreamController<Session> _internalSessionsController;
  late final StreamController<Event> _eventsController;

  /// Stream of `internal/session` events, emitted BEFORE alias-group events.
  Stream<Session> get internalSessions => _internalSessionsController.stream;

  /// Stream of regular events, one per alias member (including canonical).
  Stream<Event> get events => _eventsController.stream;

  /// Dispatches [session] through the bridge event pipeline.
  ///
  /// Implements upstream semantics:
  /// 1. Finds alias group via `expandEventAliases(session.event.type)`.
  /// 2. Replaces event type with canonical (first) name.
  /// 3. Emits `internal/session` first on [internalSessions].
  /// 4. Emits each alias member as a separate event on [events].
  void dispatch(Session session) {
    final event = session.event;
    final aliases = expandEventAliases(event.type);

    // Canonical name replaces the emitted type (step 2).
    // We work on a copy to not mutate the original session.
    final canonicalEvent = event.deepCopy()..type = aliases.first;
    final canonicalSession = Session(canonicalEvent, host: session.host)
      ..sn = session.sn;

    // Step 3: Emit internal/session FIRST.
    _internalSessionsController.add(canonicalSession);

    // Step 4: Emit each alias member (including canonical) as separate event.
    for (final alias in aliases) {
      final aliasEvent = event.deepCopy()..type = alias;
      // Copy over the sn from the original event if present
      aliasEvent.sn = event.sn;
      _eventsController.add(aliasEvent);
    }
  }

  /// Closes both streams and releases resources.
  Future<void> close() async {
    await _internalSessionsController.close();
    await _eventsController.close();
  }
}
