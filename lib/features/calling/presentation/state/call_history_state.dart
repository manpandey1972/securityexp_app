import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable state for CallHistoryPage
///
/// Tracks selection mode, selected items, and loading states.
class CallHistoryState {
  /// Whether selection mode is active
  final bool isSelectionMode;

  /// Set of selected call history document IDs
  final Set<String> selectedIds;

  /// Whether a delete operation is in progress
  final bool isDeleting;

  /// Whether initial data is loading
  final bool loading;

  /// Error message if any operation failed
  final String? error;

  /// Total count of call history entries (for "select all" feature)
  final int totalCount;

  const CallHistoryState({
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.isDeleting = false,
    this.loading = false,
    this.error,
    this.totalCount = 0,
  });

  /// Number of selected items
  int get selectedCount => selectedIds.length;

  /// Whether all items are selected
  bool get allSelected => totalCount > 0 && selectedCount == totalCount;

  /// Whether at least one item is selected
  bool get hasSelection => selectedIds.isNotEmpty;

  /// Creates a copy with updated fields
  CallHistoryState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedIds,
    bool? isDeleting,
    bool? loading,
    String? error,
    bool clearError = false,
    int? totalCount,
  }) {
    return CallHistoryState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
      isDeleting: isDeleting ?? this.isDeleting,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      totalCount: totalCount ?? this.totalCount,
    );
  }

  /// Clears selection and exits selection mode
  CallHistoryState clearSelection() {
    return copyWith(isSelectionMode: false, selectedIds: {});
  }
}

/// Extension for extracting call history data from Firestore documents
extension CallHistoryDocumentExtensions on QueryDocumentSnapshot {
  /// Extracts the call history ID from a document
  String get callHistoryId => id;

  /// Extracts the other user's ID based on call direction
  String getOtherUserId(String currentUserId) {
    final data = this.data() as Map<String, dynamic>;
    final direction = data['direction'] as String? ?? 'unknown';
    final callerId = data['caller_id'] as String? ?? '';
    final calleeId = data['callee_id'] as String? ?? '';
    return direction == 'outgoing' ? calleeId : callerId;
  }
}
