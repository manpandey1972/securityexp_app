import 'package:equatable/equatable.dart';

/// Base state classes for Provider state management

/// Enum for async operation states
enum AsyncState { initial, loading, success, error }

/// Base class for states with async operations
abstract class AppState extends Equatable {
  const AppState();

  @override
  List<Object?> get props => [];
}

/// State for successful data loading
class SuccessState<T> extends AppState {
  final T data;
  final String? message;

  const SuccessState(this.data, {this.message});

  @override
  List<Object?> get props => [data, message];
}

/// State for error scenarios
class ErrorState extends AppState {
  final String message;
  final Exception? exception;

  const ErrorState(this.message, {this.exception});

  @override
  List<Object?> get props => [message, exception];
}

/// State for loading scenarios
class LoadingState extends AppState {
  final String? message;

  const LoadingState({this.message});

  @override
  List<Object?> get props => [message];
}

/// State for initial/empty state
class InitialState extends AppState {
  const InitialState();
}

/// Generic async result class for type-safe error handling
class AsyncResult<T> extends Equatable {
  final T? data;
  final String? error;
  final bool isLoading;

  const AsyncResult({this.data, this.error, this.isLoading = false});

  bool get hasError => error != null;
  bool get hasData => data != null && !hasError;

  @override
  List<Object?> get props => [data, error, isLoading];
}
