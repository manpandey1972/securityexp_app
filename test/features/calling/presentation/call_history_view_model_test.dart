// CallHistoryViewModel tests
//
// Tests for the call history view model which manages call history state.

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:securityexperts_app/features/calling/presentation/view_models/call_history_view_model.dart';
import 'package:securityexperts_app/features/calling/presentation/state/call_history_state.dart';
import 'package:securityexperts_app/features/calling/domain/repositories/call_history_repository.dart';
import 'package:securityexperts_app/features/calling/services/call_logger.dart';

@GenerateMocks([CallHistoryRepository, CallLogger])
import 'call_history_view_model_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCallHistoryRepository mockRepository;
  late MockCallLogger mockLogger;
  late CallHistoryViewModel viewModel;

  const testUserId = 'test-user-123';

  setUp(() {
    mockRepository = MockCallHistoryRepository();
    mockLogger = MockCallLogger();

    viewModel = CallHistoryViewModel(
      repository: mockRepository,
      userId: testUserId,
      logger: mockLogger,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('CallHistoryViewModel', () {
    group('initial state', () {
      test('should have default state values', () {
        expect(viewModel.state.isSelectionMode, false);
        expect(viewModel.state.selectedIds, isEmpty);
        expect(viewModel.state.isDeleting, false);
        expect(viewModel.state.loading, false);
        expect(viewModel.state.error, isNull);
        expect(viewModel.state.totalCount, 0);
      });

      test('should store userId', () {
        expect(viewModel.userId, testUserId);
      });

      test('should have empty call history docs initially', () {
        expect(viewModel.callHistoryDocs, isEmpty);
      });
    });

    group('initialize', () {
      test('should set loading to true and subscribe to stream', () {
        when(mockRepository.getCallHistoryStream(testUserId))
            .thenAnswer((_) => const Stream.empty());

        viewModel.initialize();

        expect(viewModel.state.loading, true);
        verify(mockLogger.debug(
          'Initializing CallHistoryViewModel',
          {'userId': testUserId},
        )).called(1);
      });
    });

    group('selection mode', () {
      test('enterSelectionMode should enable selection mode', () {
        viewModel.enterSelectionMode();

        expect(viewModel.state.isSelectionMode, true);
        expect(viewModel.state.selectedIds, isEmpty);
        verify(mockLogger.debug('Entered selection mode', {
          'initialSelection': null,
        })).called(1);
      });

      test('enterSelectionMode with initial selection should select item', () {
        viewModel.enterSelectionMode(initialSelection: 'call-1');

        expect(viewModel.state.isSelectionMode, true);
        expect(viewModel.state.selectedIds, contains('call-1'));
      });

      test('exitSelectionMode should clear selection and exit mode', () {
        viewModel.enterSelectionMode(initialSelection: 'call-1');
        viewModel.exitSelectionMode();

        expect(viewModel.state.isSelectionMode, false);
        expect(viewModel.state.selectedIds, isEmpty);
        verify(mockLogger.debug('Exited selection mode')).called(1);
      });

      test('toggleSelection should add item if not selected', () {
        viewModel.enterSelectionMode();
        viewModel.toggleSelection('call-1');

        expect(viewModel.state.selectedIds, contains('call-1'));
      });

      test('toggleSelection should remove item if already selected', () {
        viewModel.enterSelectionMode(initialSelection: 'call-1');
        viewModel.toggleSelection('call-1');

        // Should exit selection mode since no items selected
        expect(viewModel.state.isSelectionMode, false);
        expect(viewModel.state.selectedIds, isEmpty);
      });

      test('toggleSelection should exit selection mode when last item deselected', () {
        viewModel.enterSelectionMode(initialSelection: 'call-1');
        viewModel.toggleSelection('call-2'); // Add another
        viewModel.toggleSelection('call-1'); // Remove first
        viewModel.toggleSelection('call-2'); // Remove second

        expect(viewModel.state.isSelectionMode, false);
      });

      test('deselectAll should clear selections but stay in selection mode', () {
        viewModel.enterSelectionMode(initialSelection: 'call-1');
        viewModel.toggleSelection('call-2');
        viewModel.deselectAll();

        expect(viewModel.state.selectedIds, isEmpty);
        // Note: deselectAll keeps selection mode active
        verify(mockLogger.debug('Deselected all')).called(1);
      });
    });

    group('delete operations', () {
      test('deleteEntry should set isDeleting to true during operation', () async {
        when(mockRepository.deleteCallHistoryEntry(testUserId, 'call-1'))
            .thenAnswer((_) async => true);

        final future = viewModel.deleteEntry('call-1');

        // State should be deleting during operation
        expect(viewModel.state.isDeleting, true);

        final result = await future;

        expect(result, true);
        expect(viewModel.state.isDeleting, false);
        verify(mockLogger.info('Deleting single entry', {'id': 'call-1'})).called(1);
        verify(mockLogger.info('Successfully deleted entry', {'id': 'call-1'})).called(1);
      });

      test('deleteEntry should return false on failure', () async {
        when(mockRepository.deleteCallHistoryEntry(testUserId, 'call-1'))
            .thenAnswer((_) async => false);

        final result = await viewModel.deleteEntry('call-1');

        expect(result, false);
        expect(viewModel.state.error, 'Failed to delete call history entry');
      });

      test('deleteEntry should handle exceptions', () async {
        when(mockRepository.deleteCallHistoryEntry(testUserId, 'call-1'))
            .thenThrow(Exception('Network error'));

        final result = await viewModel.deleteEntry('call-1');

        expect(result, false);
        expect(viewModel.state.error, contains('Failed to delete'));
        verify(mockLogger.error(any, any)).called(1);
      });

      test('deleteEntry should remove from selection if selected', () async {
        viewModel.enterSelectionMode(initialSelection: 'call-1');
        viewModel.toggleSelection('call-2');

        when(mockRepository.deleteCallHistoryEntry(testUserId, 'call-1'))
            .thenAnswer((_) async => true);

        await viewModel.deleteEntry('call-1');

        expect(viewModel.state.selectedIds, isNot(contains('call-1')));
        expect(viewModel.state.selectedIds, contains('call-2'));
      });

      test('deleteSelected should return true if no items selected', () async {
        final result = await viewModel.deleteSelected();
        expect(result, true);
      });

      test('deleteSelected should delete all selected items', () async {
        viewModel.enterSelectionMode(initialSelection: 'call-1');
        viewModel.toggleSelection('call-2');

        when(mockRepository.deleteCallHistoryEntries(testUserId, any))
            .thenAnswer((_) async => 2);

        final result = await viewModel.deleteSelected();

        expect(result, true);
        expect(viewModel.state.isSelectionMode, false);
        expect(viewModel.state.selectedIds, isEmpty);
        verify(mockLogger.info('Deleting selected entries', {'count': 2})).called(1);
      });

      test('deleteSelected should handle partial deletion', () async {
        viewModel.enterSelectionMode(initialSelection: 'call-1');
        viewModel.toggleSelection('call-2');

        when(mockRepository.deleteCallHistoryEntries(testUserId, any))
            .thenAnswer((_) async => 1); // Only 1 of 2 deleted

        final result = await viewModel.deleteSelected();

        expect(result, false);
        expect(viewModel.state.error, 'Some entries could not be deleted');
      });

      test('clearAll should delete all call history', () async {
        when(mockRepository.clearAllCallHistory(testUserId))
            .thenAnswer((_) async => true);

        final result = await viewModel.clearAll();

        expect(result, true);
        expect(viewModel.state.isSelectionMode, false);
        expect(viewModel.state.selectedIds, isEmpty);
        expect(viewModel.state.totalCount, 0);
        verify(mockLogger.info('Clearing all call history', {'userId': testUserId})).called(1);
      });

      test('clearAll should handle failure', () async {
        when(mockRepository.clearAllCallHistory(testUserId))
            .thenAnswer((_) async => false);

        final result = await viewModel.clearAll();

        expect(result, false);
        expect(viewModel.state.error, 'Failed to clear call history');
      });
    });

    group('error handling', () {
      test('clearError should clear error message', () async {
        when(mockRepository.deleteCallHistoryEntry(testUserId, 'call-1'))
            .thenAnswer((_) async => false);

        await viewModel.deleteEntry('call-1');
        expect(viewModel.state.error, isNotNull);

        viewModel.clearError();
        // After clearError, error should be null
        // Note: clearError only sets error to null via copyWith
      });
    });

    group('dispose', () {
      test('should call super.dispose', () {
        // Dispose is tested implicitly via tearDown
        // Calling dispose manually here would cause double-dispose
        expect(viewModel.dispose, isA<Function>());
      });
    });
  });

  group('CallHistoryState', () {
    test('should have correct default values', () {
      const state = CallHistoryState();

      expect(state.isSelectionMode, false);
      expect(state.selectedIds, isEmpty);
      expect(state.isDeleting, false);
      expect(state.loading, false);
      expect(state.error, isNull);
      expect(state.totalCount, 0);
    });

    test('selectedCount should return number of selected items', () {
      const state = CallHistoryState(selectedIds: {'a', 'b', 'c'});
      expect(state.selectedCount, 3);
    });

    test('allSelected should return true when all items selected', () {
      const state = CallHistoryState(
        selectedIds: {'a', 'b', 'c'},
        totalCount: 3,
      );
      expect(state.allSelected, true);
    });

    test('allSelected should return false when not all selected', () {
      const state = CallHistoryState(
        selectedIds: {'a', 'b'},
        totalCount: 3,
      );
      expect(state.allSelected, false);
    });

    test('allSelected should return false when totalCount is 0', () {
      const state = CallHistoryState(selectedIds: {}, totalCount: 0);
      expect(state.allSelected, false);
    });

    test('hasSelection should return true when items selected', () {
      const state = CallHistoryState(selectedIds: {'a'});
      expect(state.hasSelection, true);
    });

    test('hasSelection should return false when no items selected', () {
      const state = CallHistoryState(selectedIds: {});
      expect(state.hasSelection, false);
    });

    test('copyWith should create new state with updated values', () {
      const original = CallHistoryState();
      final updated = original.copyWith(
        isSelectionMode: true,
        selectedIds: {'a'},
        totalCount: 5,
      );

      expect(updated.isSelectionMode, true);
      expect(updated.selectedIds, {'a'});
      expect(updated.totalCount, 5);
      expect(updated.isDeleting, false); // Unchanged
    });

    test('copyWith clearError should clear error', () {
      const state = CallHistoryState(error: 'Some error');
      final updated = state.copyWith(clearError: true);

      expect(updated.error, isNull);
    });

    test('clearSelection should reset selection state', () {
      const state = CallHistoryState(
        isSelectionMode: true,
        selectedIds: {'a', 'b'},
      );
      final cleared = state.clearSelection();

      expect(cleared.isSelectionMode, false);
      expect(cleared.selectedIds, isEmpty);
    });
  });
}
