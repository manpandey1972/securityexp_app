import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/chat/presentation/state/chat_conversation_state.dart';

/// Unit tests for E2EE state fields in ChatConversationState.
void main() {
  group('ChatConversationState E2EE Fields', () {
    test('should default isE2eeEnabled to false', () {
      const state = ChatConversationState();

      expect(state.isE2eeEnabled, isFalse);
      expect(state.e2eeError, isNull);
    });

    test('should set isE2eeEnabled via copyWith', () {
      const state = ChatConversationState();
      final updated = state.copyWith(isE2eeEnabled: true);

      expect(updated.isE2eeEnabled, isTrue);
      expect(state.isE2eeEnabled, isFalse); // Original unchanged
    });

    test('should set e2eeError via copyWith', () {
      const state = ChatConversationState();
      final updated = state.copyWith(
        e2eeError: 'Key exchange failed',
      );

      expect(updated.e2eeError, equals('Key exchange failed'));
    });

    test('should clear e2eeError via copyWith', () {
      const state = ChatConversationState();
      final withError = state.copyWith(
        e2eeError: 'Some error',
      );
      final cleared = withError.copyWith(clearE2eeError: true);

      expect(withError.e2eeError, equals('Some error'));
      expect(cleared.e2eeError, isNull);
    });

    test('should preserve E2EE fields when updating other fields', () {
      const state = ChatConversationState();
      final e2eeState = state.copyWith(
        isE2eeEnabled: true,
        e2eeError: 'Warning',
      );
      final updated = e2eeState.copyWith(loading: true);

      expect(updated.isE2eeEnabled, isTrue);
      expect(updated.e2eeError, equals('Warning'));
      expect(updated.loading, isTrue);
    });

    test('should set both E2EE fields simultaneously', () {
      const state = ChatConversationState();
      final updated = state.copyWith(
        isE2eeEnabled: true,
        e2eeError: 'Identity key changed',
      );

      expect(updated.isE2eeEnabled, isTrue);
      expect(updated.e2eeError, equals('Identity key changed'));
    });
  });
}
