/// Exception types for the call system
///
/// Provides a structured error hierarchy for better error handling
/// and user messaging.
library;

/// Base class for all call-related errors
///
/// All call errors extend this class to provide consistent error handling.
abstract class CallError implements Exception {
  /// Human-readable error message for debugging
  final String message;

  /// Optional error code for categorization
  final String? code;

  /// The original error that caused this, if any
  final dynamic originalError;

  CallError(this.message, {this.code, this.originalError});

  /// Whether this error can be recovered from automatically
  ///
  /// Recoverable errors may trigger retry or reconnection logic.
  bool get isRecoverable => false;

  /// User-friendly error message to display
  ///
  /// Should be clear and actionable for end users.
  String get userMessage => message;

  @override
  String toString() => 'CallError: $message${code != null ? " ($code)" : ""}';
}

/// Network-related errors (connection loss, timeout, etc.)
///
/// These are typically recoverable with retry logic.
class CallNetworkError extends CallError {
  CallNetworkError(super.message, {super.code, super.originalError});

  @override
  bool get isRecoverable => true;

  @override
  String get userMessage =>
      'Network connection issue. Please check your internet connection.';
}

/// Permission-related errors (camera, microphone access)
///
/// These require user action to grant permissions.
class CallPermissionError extends CallError {
  /// The permission that was denied
  final String permission;

  CallPermissionError(this.permission, String message) : super(message);

  @override
  String get userMessage =>
      'Please grant $permission permission to continue the call.';
}

/// Call timeout errors (no answer, connection timeout)
///
/// These occur when operations take too long.
class CallTimeoutError extends CallError {
  /// How long we waited before timing out
  final Duration timeout;

  CallTimeoutError(this.timeout)
    : super('Operation timed out after ${timeout.inSeconds} seconds');

  @override
  bool get isRecoverable => true;

  @override
  String get userMessage =>
      'The call timed out. The other person may not be available.';
}

/// Signaling errors (failed to create/join room, etc.)
///
/// These occur during call setup and signaling.
class CallSignalingError extends CallError {
  CallSignalingError(super.message, {super.code, super.originalError});

  @override
  String get userMessage =>
      'Failed to connect to call server. Please try again.';
}

/// Media errors (failed to access camera/microphone, encoding issues)
///
/// These occur during media setup or streaming.
class CallMediaError extends CallError {
  CallMediaError(super.message, {super.code, super.originalError});

  @override
  String get userMessage =>
      'Failed to setup audio/video. Please check your device settings.';
}

/// Configuration errors (invalid settings, missing credentials)
///
/// These indicate setup or configuration problems.
class CallConfigurationError extends CallError {
  CallConfigurationError(super.message, {super.code, super.originalError});

  @override
  String get userMessage =>
      'Call system is not properly configured. Please contact support.';
}

/// State errors (invalid state transition, operation not allowed)
///
/// These occur when operations are called in wrong states.
class CallStateError extends CallError {
  /// The current state when the error occurred
  final String currentState;

  /// The operation that was attempted
  final String attemptedOperation;

  CallStateError(this.currentState, this.attemptedOperation)
    : super('Cannot $attemptedOperation in state: $currentState');

  @override
  String get userMessage => 'This action is not available right now.';
}

/// Browser WebRTC degradation error (Chrome-specific)
///
/// Occurs when Chrome's WebRTC PeerConnection stack degrades after
/// multiple call create/destroy cycles, causing all ICE attempts to fail.
/// The only recovery is refreshing the page.
class CallBrowserDegradedError extends CallError {
  CallBrowserDegradedError({super.originalError})
    : super('WebRTC connection degraded');

  @override
  bool get isRecoverable => false;

  @override
  String get userMessage =>
      'Connection unstable. Please refresh the page and try again.';
}

/// Unknown or unexpected errors
///
/// Catch-all for errors that don't fit other categories.
class CallUnknownError extends CallError {
  CallUnknownError(super.message, {super.originalError});

  @override
  String get userMessage => 'An unexpected error occurred. Please try again.';
}
