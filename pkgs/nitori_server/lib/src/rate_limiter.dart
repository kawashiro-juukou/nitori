/// Rate limiting using a token bucket algorithm.
library;

import 'dart:io';

/// Configuration for a rate limiter.
class RateLimiterConfig {
  const RateLimiterConfig({
    this.maxRequests = 100,
    this.window = const Duration(minutes: 1),
    this.scope = RateLimitScope.ip,
    this.enabled = false,
  });

  /// Maximum number of requests allowed in the time window.
  final int maxRequests;

  /// Time window for the rate limit.
  final Duration window;

  /// Scope of the rate limit (IP, identity, token, or global).
  final RateLimitScope scope;

  /// Whether the rate limiter is enabled.
  final bool enabled;
}

/// Scope of rate limiting.
enum RateLimitScope { ip, identity, token, global }

/// Thread-safe token bucket implementation.
class _TokenBucket {
  _TokenBucket(this.capacity, this.refillRatePerSecond) {
    _tokens = capacity.toDouble();
    _lastRefillMs = DateTime.now().millisecondsSinceEpoch;
  }

  final int capacity;
  final double refillRatePerSecond;

  double _tokens = 0;
  int _lastRefillMs = 0;

  /// Tries to consume [tokens] from the bucket.
  /// Returns true if successful, false if not enough tokens.
  bool tryConsume(int tokens) {
    _refill();
    if (_tokens >= tokens) {
      _tokens -= tokens;
      return true;
    }
    return false;
  }

  /// Returns the number of tokens currently available (after refill).
  int availableTokens() {
    _refill();
    return _tokens.floor();
  }

  /// Returns the time in milliseconds until [tokens] would be available.
  int retryAfterMs(int tokens) {
    _refill();
    if (_tokens >= tokens) return 0;
    final needed = tokens - _tokens;
    if (refillRatePerSecond <= 0) return 1000; // Avoid division by zero
    return (needed / refillRatePerSecond * 1000).ceil();
  }

  void _refill() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = (now - _lastRefillMs) / 1000.0;
    _tokens = (_tokens + elapsedSeconds * refillRatePerSecond).clamp(
      0.0,
      capacity.toDouble(),
    );
    _lastRefillMs = now;
  }
}

/// A rate limiter that uses token buckets per scope key.
class RateLimiter {
  RateLimiter(this.config);

  final RateLimiterConfig config;

  final Map<String, _TokenBucket> _buckets = <String, _TokenBucket>{};
  late final _TokenBucket _globalBucket = _TokenBucket(
    config.maxRequests,
    config.maxRequests / (config.window.inMilliseconds / 1000.0),
  );

  _TokenBucket _getBucket(String key) {
    return _buckets.putIfAbsent(
      key,
      () => _TokenBucket(
        config.maxRequests,
        config.maxRequests / (config.window.inMilliseconds / 1000.0),
      ),
    );
  }

  /// Extracts the rate limit key from an HTTP request.
  String? _httpKey(HttpRequest request) {
    switch (config.scope) {
      case RateLimitScope.ip:
        return request.connectionInfo?.remoteAddress.address;
      case RateLimitScope.identity:
        {
          final platform = request.headers.value('satori-platform');
          final userId = request.headers.value('satori-user-id');
          if (platform != null && userId != null) {
            return '$platform:$userId';
          }
          return request.connectionInfo?.remoteAddress.address;
        }
      case RateLimitScope.token:
        {
          final auth = request.headers.value('authorization');
          if (auth != null && auth.startsWith('Bearer ')) {
            return auth.substring('Bearer '.length);
          }
          return request.connectionInfo?.remoteAddress.address;
        }
      case RateLimitScope.global:
        return 'global';
    }
  }

  /// Extracts the rate limit key from a WebSocket IDENTIFY payload.
  String? _wsIdentifyKey(Map<String, dynamic> identify) {
    switch (config.scope) {
      case RateLimitScope.ip:
        // IP not available at identify time, fallback to token/identity
        return _wsIdentifyKeyFallback(identify);
      case RateLimitScope.identity:
        {
          final platform = identify['platform'] as String?;
          final userId = identify['user_id'] as String?;
          if (platform != null && userId != null) {
            return '$platform:$userId';
          }
          return _wsIdentifyKeyFallback(identify);
        }
      case RateLimitScope.token:
        {
          final token = identify['token'] as String?;
          if (token != null) return token;
          return _wsIdentifyKeyFallback(identify);
        }
      case RateLimitScope.global:
        return 'global';
    }
  }

  String? _wsIdentifyKeyFallback(Map<String, dynamic> identify) {
    final token = identify['token'] as String?;
    if (token != null) return token;
    final platform = identify['platform'] as String?;
    final userId = identify['user_id'] as String?;
    if (platform != null && userId != null) {
      return '$platform:$userId';
    }
    return null;
  }

  /// Checks if an HTTP request should be rate limited.
  /// Returns null if allowed, or retry-after milliseconds if rate limited.
  int? checkHttp(HttpRequest request) {
    if (!config.enabled) return null;
    final key = _httpKey(request);
    if (key == null) return null;
    final bucket = config.scope == RateLimitScope.global
        ? _globalBucket
        : _getBucket(key);
    if (!bucket.tryConsume(1)) {
      return bucket.retryAfterMs(1);
    }
    return null;
  }

  /// Checks if a WebSocket connection should be rate limited.
  /// Returns null if allowed, or retry-after milliseconds if rate limited.
  int? checkWsConnect(Map<String, dynamic> identify) {
    if (!config.enabled) return null;
    final key = _wsIdentifyKey(identify);
    if (key == null) return null;
    final bucket = config.scope == RateLimitScope.global
        ? _globalBucket
        : _getBucket(key);
    if (!bucket.tryConsume(1)) {
      return bucket.retryAfterMs(1);
    }
    return null;
  }

  /// Checks if a WebSocket event should be rate limited.
  /// Returns null if allowed, or retry-after milliseconds if rate limited.
  int? checkWsEvent(String key) {
    if (!config.enabled) return null;
    final bucket = config.scope == RateLimitScope.global
        ? _globalBucket
        : _getBucket(key);
    if (!bucket.tryConsume(1)) {
      return bucket.retryAfterMs(1);
    }
    return null;
  }

  /// Resets all buckets (useful for testing or config changes).
  void reset() {
    for (final bucket in _buckets.values) {
      bucket._tokens = bucket.capacity.toDouble();
      bucket._lastRefillMs = DateTime.now().millisecondsSinceEpoch;
    }
    _globalBucket._tokens = _globalBucket.capacity.toDouble();
    _globalBucket._lastRefillMs = DateTime.now().millisecondsSinceEpoch;
  }
}
