import 'dart:async';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Circuit breaker states
enum CircuitState {
  closed, // Normal operation, requests pass through
  open, // Failures detected, requests fail fast
  halfOpen, // Testing if service recovered
}

/// Configuration for circuit breaker
class CircuitBreakerConfig {
  final int failureThreshold;
  final Duration timeout;
  final Duration halfOpenTimeout;
  final int successThreshold; // Successes needed in half-open to close

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 30),
    this.halfOpenTimeout = const Duration(seconds: 5),
    this.successThreshold = 2,
  });
}

/// Exception thrown when circuit is open
class CircuitBreakerOpenException implements Exception {
  final String message;
  final DateTime openedAt;
  final Duration timeRemaining;

  CircuitBreakerOpenException({
    required this.message,
    required this.openedAt,
    required this.timeRemaining,
  });

  @override
  String toString() =>
      'CircuitBreakerOpenException: $message '
      '(opened at: $openedAt, time remaining: ${timeRemaining.inSeconds}s)';
}

/// Circuit breaker pattern implementation
///
/// Prevents cascading failures by failing fast when a service is unavailable.
/// Automatically recovers and tests the service periodically.
class CircuitBreaker {
  final String name;
  final CircuitBreakerConfig config;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _stateChangedAt;
  Timer? _resetTimer;

  CircuitBreaker({required this.name, CircuitBreakerConfig? config})
    : config = config ?? const CircuitBreakerConfig();

  /// Current state of the circuit
  CircuitState get state => _state;

  /// Number of consecutive failures
  int get failureCount => _failureCount;

  /// Number of successes in half-open state
  int get successCount => _successCount;

  /// Is circuit allowing requests
  bool get isAllowingRequests => _state != CircuitState.open;

  /// Execute an operation through the circuit breaker
  Future<T> execute<T>(Future<T> Function() operation) async {
    // Check if we should allow the request
    if (_state == CircuitState.open) {
      _checkIfShouldTransitionToHalfOpen();

      if (_state == CircuitState.open) {
        final timeRemaining =
            config.timeout - DateTime.now().difference(_stateChangedAt!);

        throw CircuitBreakerOpenException(
          message: 'Circuit breaker "$name" is open',
          openedAt: _stateChangedAt!,
          timeRemaining: timeRemaining,
        );
      }
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (error) {
      _onFailure(error);
      rethrow;
    }
  }

  /// Record a success
  void _onSuccess() {
    _lastFailureTime = null;

    if (_state == CircuitState.halfOpen) {
      _successCount++;

      if (_successCount >= config.successThreshold) {
        _transitionTo(CircuitState.closed);
      }
    } else if (_state == CircuitState.closed) {
      _failureCount = 0;
    }
  }

  /// Record a failure
  void _onFailure(Object error) {
    _lastFailureTime = DateTime.now();
    _failureCount++;

    if (_state == CircuitState.halfOpen) {
      // Any failure in half-open immediately opens circuit
      _transitionTo(CircuitState.open);
    } else if (_state == CircuitState.closed) {
      if (_failureCount >= config.failureThreshold) {
        _transitionTo(CircuitState.open);
      }
    }

    sl<AppLogger>().debug(
      'Failure $failureCount (state: ${_state.name})',
      tag: 'CircuitBreaker[$name]',
    );
  }

  /// Transition to new state
  void _transitionTo(CircuitState newState) {
    final oldState = _state;
    _state = newState;
    _stateChangedAt = DateTime.now();

    switch (newState) {
      case CircuitState.closed:
        _failureCount = 0;
        _successCount = 0;
        _resetTimer?.cancel();
        break;

      case CircuitState.open:
        _successCount = 0;
        _scheduleReset();
        break;

      case CircuitState.halfOpen:
        _successCount = 0;
        _failureCount = 0;
        break;
    }

    sl<AppLogger>().debug(
      '${oldState.name} → ${newState.name}',
      tag: 'CircuitBreaker[$name]',
    );
  }

  /// Schedule automatic transition to half-open
  void _scheduleReset() {
    _resetTimer?.cancel();

    _resetTimer = Timer(config.timeout, () {
      if (_state == CircuitState.open) {
        _transitionTo(CircuitState.halfOpen);
      }
    });
  }

  /// Check if enough time has passed to try half-open
  void _checkIfShouldTransitionToHalfOpen() {
    if (_state != CircuitState.open || _stateChangedAt == null) {
      return;
    }

    final elapsed = DateTime.now().difference(_stateChangedAt!);
    if (elapsed >= config.timeout) {
      _transitionTo(CircuitState.halfOpen);
    }
  }

  /// Manually reset the circuit breaker
  void reset() {
    _transitionTo(CircuitState.closed);

    sl<AppLogger>().debug('Manually reset', tag: 'CircuitBreaker[$name]');
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'name': name,
      'state': _state.name,
      'failureCount': _failureCount,
      'successCount': _successCount,
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'stateChangedAt': _stateChangedAt?.toIso8601String(),
    };
  }

  void dispose() {
    _resetTimer?.cancel();
  }
}

/// Manages multiple circuit breakers
class CircuitBreakerManager {
  final Map<String, CircuitBreaker> _breakers = {};
  final CircuitBreakerConfig defaultConfig;

  CircuitBreakerManager({CircuitBreakerConfig? defaultConfig})
    : defaultConfig = defaultConfig ?? const CircuitBreakerConfig();

  /// Get or create a circuit breaker
  CircuitBreaker getBreaker(String name, {CircuitBreakerConfig? config}) {
    return _breakers.putIfAbsent(
      name,
      () => CircuitBreaker(name: name, config: config ?? defaultConfig),
    );
  }

  /// Execute operation through named circuit breaker
  Future<T> execute<T>(
    String breakerName,
    Future<T> Function() operation, {
    CircuitBreakerConfig? config,
  }) {
    final breaker = getBreaker(breakerName, config: config);
    return breaker.execute(operation);
  }

  /// Reset a specific breaker
  void resetBreaker(String name) {
    _breakers[name]?.reset();
  }

  /// Reset all breakers
  void resetAll() {
    for (final breaker in _breakers.values) {
      breaker.reset();
    }
  }

  /// Get all breaker statistics
  Map<String, dynamic> getAllStats() {
    return {
      'breakers': _breakers.map(
        (name, breaker) => MapEntry(name, breaker.getStats()),
      ),
      'totalBreakers': _breakers.length,
    };
  }

  void dispose() {
    for (final breaker in _breakers.values) {
      breaker.dispose();
    }
    _breakers.clear();
  }
}
