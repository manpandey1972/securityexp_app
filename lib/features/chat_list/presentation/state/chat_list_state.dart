import 'package:securityexperts_app/data/models/models.dart' as models;

/// Immutable state for ChatPage
class ChatListState {
  final bool loading;
  final String? error;
  final List<models.Room> rooms;

  const ChatListState({
    this.loading = false,
    this.error,
    this.rooms = const [],
  });

  /// Create a copy with optional parameter updates
  ChatListState copyWith({
    bool? loading,
    String? error,
    List<models.Room>? rooms,
    bool clearError = false,
  }) {
    return ChatListState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      rooms: rooms ?? this.rooms,
    );
  }
}
