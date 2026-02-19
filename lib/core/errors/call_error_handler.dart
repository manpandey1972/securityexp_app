import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/features/calling/services/call_logger.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'call_errors.dart';

/// Handles call errors with appropriate recovery strategies
///
/// This class centralizes error handling logic and provides
/// consistent user feedback and recovery mechanisms.
class CallErrorHandler {
  final CallLogger logger;

  CallErrorHandler(this.logger);

  /// Handles a call error with appropriate recovery strategy
  ///
  /// Logs the error, shows user feedback, and may trigger recovery actions.
  ///
  /// Returns true if error was handled and recovery initiated,
  /// false if error is fatal and call should be terminated.
  bool handleError(CallError error, {Function? onRetry}) {
    // Suppress errors that indicate intentional call termination
    final errorMsg = error.userMessage.toLowerCase();
    if (errorMsg.contains('call may have ended') ||
        errorMsg.contains('unable to connect') ||
        errorMsg.contains('terminated by user')) {
      logger.info('Ignoring call termination error in handler');
      return false;
    }

    // Use standard error handler for logging and user feedback
    final appError = AppError(
      message: error.userMessage,
      exception: error,
      severity: error.isRecoverable ? ErrorSeverity.warning : ErrorSeverity.error,
      context: 'CallErrorHandler',
    );
    appError.log();

    // Show user-friendly message
    SnackbarService.show(error.userMessage);

    // Determine handling strategy based on error type
    if (error.isRecoverable) {
      return _handleRecoverableError(error, onRetry: onRetry);
    } else {
      _handleFatalError(error);
      return false;
    }
  }

  /// Handles recoverable errors that may be retried
  bool _handleRecoverableError(CallError error, {Function? onRetry}) {
    if (error is CallNetworkError) {
      logger.info('Network error detected, recovery may be possible');

      // Trigger retry if callback provided
      if (onRetry != null) {
        onRetry();
      }
      return true;
    } else if (error is CallTimeoutError) {
      logger.info('Call timeout, ending call gracefully');
      return false; // Timeout ends the call
    }

    return false;
  }

  /// Handles fatal errors that cannot be recovered
  void _handleFatalError(CallError error) {
    // Log the fatal error
    logger.error('Fatal call error', error, null);

    // Additional handling based on error type
    if (error is CallPermissionError) {
      _handlePermissionError(error);
    } else if (error is CallConfigurationError) {
      _handleConfigurationError(error);
    }
  }

  /// Handles permission errors with guidance for user
  void _handlePermissionError(CallPermissionError error) {
    logger.warning('Permission denied: ${error.permission}');

    // Could show a dialog with instructions to enable permissions
    // For now, just show the snackbar message
  }

  /// Handles configuration errors
  void _handleConfigurationError(CallConfigurationError error) {
    logger.error('Configuration error', error, null);

    // In production, might want to send an alert to monitoring
    // or show a "contact support" message
  }

  /// Creates appropriate CallError from generic exception
  ///
  /// Attempts to classify generic exceptions into specific CallError types.
  static CallError fromException(dynamic exception, {StackTrace? stackTrace}) {
    if (exception is CallError) {
      return exception;
    }

    final errorMessage = exception.toString().toLowerCase();
    // Check if this is a call termination exception - return a special "ignore" error
    if (errorMessage.contains('call may have ended') ||
        errorMessage.contains('unable to connect to call')) {
      // Return a CallError with a special message that will be suppressed
      return CallUnknownError(
        'Call terminated by user',
        originalError: exception,
      );
    }
    // Try to classify based on error message
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('internet')) {
      return CallNetworkError(exception.toString(), originalError: exception);
    }

    if (errorMessage.contains('permission') ||
        errorMessage.contains('denied') ||
        errorMessage.contains('access')) {
      return CallMediaError(exception.toString(), originalError: exception);
    }

    if (errorMessage.contains('timeout')) {
      return CallTimeoutError(const Duration(seconds: 30));
    }

    if (errorMessage.contains('signaling') ||
        errorMessage.contains('room') ||
        errorMessage.contains('session')) {
      return CallSignalingError(exception.toString(), originalError: exception);
    }

    // Default to unknown error
    return CallUnknownError(exception.toString(), originalError: exception);
  }
}
