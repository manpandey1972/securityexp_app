import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:securityexperts_app/features/calling/domain/repositories/call_history_repository.dart';
import 'package:securityexperts_app/features/calling/presentation/state/call_history_state.dart';
import 'package:securityexperts_app/features/calling/services/call_logger.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// ViewModel for CallHistoryPage
///
/// Manages call history state including selection mode for
/// deleting single, multiple, or all call history entries.
class CallHistoryViewModel extends ChangeNotifier {
  final CallHistoryRepository _repository;
  final CallLogger _logger;
  final String userId;

  CallHistoryState _state = const CallHistoryState();
  CallHistoryState get state => _state;

  StreamSubscription<QuerySnapshot>? _callHistorySubscription;
  List<QueryDocumentSnapshot> _callHistoryDocs = [];
  List<QueryDocumentSnapshot> get callHistoryDocs => _callHistoryDocs;

  CallHistoryViewModel({
    required CallHistoryRepository repository,
    required this.userId,
    CallLogger? logger,
  })  : _repository = repository,
        _logger = logger ?? DebugCallLogger();

  /// Initialize the view model and start listening to call history stream
  void initialize() {
    _logger.debug('Initializing CallHistoryViewModel', {'userId': userId});
    _state = _state.copyWith(loading: true);
    _subscribeToCallHistory();
  }

  void _updateState(CallHistoryState newState) {
    _state = newState;
    notifyListeners();
  }

  // =============== Stream Management ===============

  void _subscribeToCallHistory() {
    _callHistorySubscription?.cancel();
    _callHistorySubscription = _repository
        .getCallHistoryStream(userId)
        .listen(
          (snapshot) async {
            var docs = snapshot.docs;

            // Prefetch participant profiles BEFORE notifying the UI.
            // This ensures the cache is warm so names/avatars render instantly.
            // Also returns IDs of orphaned entries (deleted users) to filter out.
            final orphanedDocIds = await _prefetchParticipants(docs);

            // Filter out orphaned entries (those referencing deleted users)
            if (orphanedDocIds.isNotEmpty) {
              docs = docs.where((doc) => !orphanedDocIds.contains(doc.id)).toList();
            }

            _callHistoryDocs = docs;

            _updateState(
              _state.copyWith(
                loading: false,
                clearError: true,
                totalCount: _callHistoryDocs.length,
              ),
            );
          },
          onError: (error) {
            _logger.error('Call history stream error', {'error': error.toString()});
            _updateState(
              _state.copyWith(
                loading: false,
                error: error.toString(),
              ),
            );
          },
        );
  }

  /// Prefetch participant user profiles using a batch Firestore query.
  /// Awaited before notifying the UI so the cache is warm on first render.
  /// Also cleans up orphaned call history entries (where the other user was deleted).
  ///
  /// Returns the set of call history doc IDs that should be removed from display
  /// (entries referencing deleted users).
  Future<Set<String>> _prefetchParticipants(List<QueryDocumentSnapshot> callDocs) async {
    final userCache = sl<UserCacheService>();
    final participantIds = <String>[];
    // Map participant ID to list of call history doc IDs that reference them
    final participantToCallDocs = <String, List<String>>{};

    // Collect all unique participant IDs from call history
    for (final doc in callDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final callerId = data['caller_id'] as String?;
      final calleeId = data['callee_id'] as String?;

      // Determine who the "other" participant is (not current user)
      String? otherParticipantId;
      if (callerId != null && callerId.isNotEmpty && callerId != userId) {
        otherParticipantId = callerId;
      } else if (calleeId != null && calleeId.isNotEmpty && calleeId != userId) {
        otherParticipantId = calleeId;
      }

      if (otherParticipantId != null) {
        if (!participantIds.contains(otherParticipantId)) {
          participantIds.add(otherParticipantId);
        }
        // Track which call docs reference this participant
        participantToCallDocs.putIfAbsent(otherParticipantId, () => []).add(doc.id);
      }
    }

    if (participantIds.isEmpty) return {};

    final orphanedCallDocIds = <String>{};

    try {
      final fetched = await userCache.fetchMultiple(participantIds);

      // Identify participants whose user docs don't exist (deleted users)
      final deletedUserIds = participantIds.where((id) => !fetched.containsKey(id)).toSet();

      if (deletedUserIds.isNotEmpty) {
        // Collect all call history doc IDs that reference deleted users
        for (final deletedUserId in deletedUserIds) {
          final callDocIds = participantToCallDocs[deletedUserId] ?? [];
          orphanedCallDocIds.addAll(callDocIds);
        }

        // Delete orphaned call history entries from Firestore (fire and forget)
        if (orphanedCallDocIds.isNotEmpty) {
          _deleteOrphanedCallHistoryEntries(orphanedCallDocIds.toList());
        }
      }
    } catch (e) {
      _logger.error('Failed to prefetch participants', {'error': e.toString()});
    }

    return orphanedCallDocIds;
  }

  /// Deletes orphaned call history entries from Firestore.
  /// This is fire-and-forget - we don't await completion.
  void _deleteOrphanedCallHistoryEntries(List<String> callHistoryIds) {
    _repository.deleteCallHistoryEntries(userId, callHistoryIds).catchError((e) {
      _logger.error('Failed to delete orphaned call history entries', {'error': e.toString()});
      return 0;
    });
  }

  // =============== Selection Mode ===============

  /// Enters selection mode with an optional initial selection
  void enterSelectionMode({String? initialSelection}) {
    final selected = <String>{};
    if (initialSelection != null) {
      selected.add(initialSelection);
    }
    _updateState(_state.copyWith(isSelectionMode: true, selectedIds: selected));
    _logger.debug('Entered selection mode', {
      'initialSelection': initialSelection,
    });
  }

  /// Exits selection mode and clears all selections
  void exitSelectionMode() {
    _updateState(_state.clearSelection());
    _logger.debug('Exited selection mode');
  }

  /// Toggles selection of a single item
  void toggleSelection(String callHistoryId) {
    final newSelected = Set<String>.from(_state.selectedIds);
    if (newSelected.contains(callHistoryId)) {
      newSelected.remove(callHistoryId);
    } else {
      newSelected.add(callHistoryId);
    }

    // Exit selection mode if no items selected
    if (newSelected.isEmpty) {
      _updateState(_state.clearSelection());
    } else {
      _updateState(_state.copyWith(selectedIds: newSelected));
    }
  }

  /// Selects all items from the provided snapshot
  void selectAll(List<QueryDocumentSnapshot> allDocs) {
    final allIds = allDocs.map((doc) => doc.id).toSet();
    _updateState(
      _state.copyWith(selectedIds: allIds, totalCount: allIds.length),
    );
    _logger.debug('Selected all', {'count': allIds.length});
  }

  /// Deselects all items but stays in selection mode
  void deselectAll() {
    _updateState(_state.copyWith(selectedIds: {}));
    _logger.debug('Deselected all');
  }

  // =============== Delete Operations ===============

  /// Deletes a single call history entry
  ///
  /// Used for swipe-to-delete or context menu delete
  Future<bool> deleteEntry(String callHistoryId) async {
    _logger.info('Deleting single entry', {'id': callHistoryId});
    _updateState(_state.copyWith(isDeleting: true, error: null));

    try {
      final success = await _repository.deleteCallHistoryEntry(
        userId,
        callHistoryId,
      );

      if (success) {
        // Remove from selection if it was selected
        if (_state.selectedIds.contains(callHistoryId)) {
          final newSelected = Set<String>.from(_state.selectedIds)
            ..remove(callHistoryId);
          _updateState(
            _state.copyWith(isDeleting: false, selectedIds: newSelected),
          );
        } else {
          _updateState(_state.copyWith(isDeleting: false));
        }
        _logger.info('Successfully deleted entry', {'id': callHistoryId});
        return true;
      } else {
        _updateState(
          _state.copyWith(
            isDeleting: false,
            error: 'Failed to delete call history entry',
          ),
        );
        return false;
      }
    } catch (e) {
      _logger.error('Failed to delete entry', {
        'id': callHistoryId,
        'error': e.toString(),
      });
      _updateState(
        _state.copyWith(isDeleting: false, error: 'Failed to delete: $e'),
      );
      return false;
    }
  }

  /// Deletes all selected call history entries
  Future<bool> deleteSelected() async {
    if (_state.selectedIds.isEmpty) return true;

    final idsToDelete = List<String>.from(_state.selectedIds);
    _logger.info('Deleting selected entries', {'count': idsToDelete.length});
    _updateState(_state.copyWith(isDeleting: true, error: null));

    try {
      final deletedCount = await _repository.deleteCallHistoryEntries(
        userId,
        idsToDelete,
      );

      final success = deletedCount == idsToDelete.length;
      _updateState(
        _state.copyWith(
          isDeleting: false,
          isSelectionMode: false,
          selectedIds: {},
          error: success ? null : 'Some entries could not be deleted',
        ),
      );

      _logger.info('Deleted selected entries', {
        'requested': idsToDelete.length,
        'deleted': deletedCount,
      });
      return success;
    } catch (e) {
      _logger.error('Failed to delete selected', {'error': e.toString()});
      _updateState(
        _state.copyWith(isDeleting: false, error: 'Failed to delete: $e'),
      );
      return false;
    }
  }

  /// Deletes all call history entries for the user
  Future<bool> clearAll() async {
    _logger.info('Clearing all call history', {'userId': userId});
    _updateState(_state.copyWith(isDeleting: true, error: null));

    try {
      final success = await _repository.clearAllCallHistory(userId);

      _updateState(
        _state.copyWith(
          isDeleting: false,
          isSelectionMode: false,
          selectedIds: {},
          totalCount: 0,
          error: success ? null : 'Failed to clear call history',
        ),
      );

      _logger.info('Cleared all call history', {'success': success});
      return success;
    } catch (e) {
      _logger.error('Failed to clear all', {'error': e.toString()});
      _updateState(
        _state.copyWith(
          isDeleting: false,
          error: 'Failed to clear history: $e',
        ),
      );
      return false;
    }
  }

  /// Clears any error message
  void clearError() {
    _updateState(_state.copyWith(error: null));
  }

  @override
  void dispose() {
    _logger.debug('Disposing CallHistoryViewModel');
    _callHistorySubscription?.cancel();
    super.dispose();
  }
}
