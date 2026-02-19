/// Generic Result class for consistent error handling
/// Replaces try-catch with a more functional approach
///
/// Usage:
/// ```dart
/// Result<List<Message>> result = await fetchMessages();
/// result.when(
///   success: (messages) => print('Got ${messages.length} messages'),
///   failure: (error) => print('Error: $error'),
/// );
/// ```
class Result<T> {
  final T? _data;
  final Exception? _error;

  // Private constructor
  const Result._({T? data, Exception? error}) : _data = data, _error = error;

  /// Create a success result
  factory Result.success(T data) {
    return Result._(data: data);
  }

  /// Create a failure result
  factory Result.failure(Exception error) {
    return Result._(error: error);
  }

  /// Create a failure result from a string message
  factory Result.error(String message) {
    return Result._(error: Exception(message));
  }

  /// Whether the result is a success
  bool get isSuccess => _error == null;

  /// Whether the result is a failure
  bool get isFailure => _error != null;

  /// Get the success data, returns null if failure
  T? get data => _data;

  /// Get the error, returns null if success
  Exception? get error => _error;

  /// Get the error message, returns null if success
  String? get errorMessage => _error?.toString();

  /// Extract data or throw error
  T getOrThrow() {
    if (_error != null) throw _error;
    return _data as T;
  }

  /// Extract data or return default value
  T getOrDefault(T defaultValue) {
    return _data ?? defaultValue;
  }

  /// Execute callback based on success/failure
  R when<R>({
    required R Function(T data) success,
    required R Function(Exception error) failure,
  }) {
    if (_error != null) {
      return failure(_error);
    }
    return success(_data as T);
  }

  /// Execute async callback based on success/failure
  Future<R> whenAsync<R>({
    required Future<R> Function(T data) success,
    required Future<R> Function(Exception error) failure,
  }) async {
    if (_error != null) {
      return failure(_error);
    }
    return success(_data as T);
  }

  /// Transform success data, keeps failure intact
  Result<U> map<U>(U Function(T data) transform) {
    if (_error != null) {
      return Result.failure(_error);
    }
    try {
      return Result.success(transform(_data as T));
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  /// Chain results - transform success data to another Result
  Result<U> flatMap<U>(Result<U> Function(T data) transform) {
    if (_error != null) {
      return Result.failure(_error);
    }
    try {
      return transform(_data as T);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  /// Handle error and optionally recover
  Result<T> mapError(Exception Function(Exception error) transform) {
    if (_error != null) {
      return Result.failure(transform(_error));
    }
    return this;
  }

  /// Recover from error with a fallback value
  Result<T> recover(T Function(Exception error) fallback) {
    if (_error != null) {
      try {
        return Result.success(fallback(_error));
      } catch (e) {
        return Result.error(e.toString());
      }
    }
    return this;
  }

  /// Execute side effect on success
  Result<T> onSuccess(void Function(T data) callback) {
    if (_error == null) {
      callback(_data as T);
    }
    return this;
  }

  /// Execute side effect on failure
  Result<T> onFailure(void Function(Exception error) callback) {
    if (_error != null) {
      callback(_error);
    }
    return this;
  }

  /// Execute side effect regardless of result
  Result<T> onComplete(void Function() callback) {
    callback();
    return this;
  }

  /// Convert to Future
  Future<T> toFuture() async {
    if (_error != null) throw _error;
    return _data as T;
  }

  @override
  String toString() {
    if (_error != null) {
      return 'Result<$T>.failure($_error)';
    }
    return 'Result<$T>.success($_data)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Result<T> && other._data == _data && other._error == _error;
  }

  @override
  int get hashCode => Object.hash(_data, _error);
}
