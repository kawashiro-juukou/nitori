/// Dart server implementation of the Satori protocol.
///
/// Exposes the HTTP API (`/v1/<method>`) and the WebSocket gateway
/// (`/v1/events`) for a [SatoriAdapter] integration.
library;

export 'src/adapter.dart' show SatoriAdapter, SatoriBot;
export 'src/in_memory_adapter.dart' show InMemoryAdapter, InMemoryBot;
export 'src/rate_limiter.dart'
    show RateLimitScope, RateLimiterConfig, RateLimiter;
export 'src/server.dart' show SatoriServer;
