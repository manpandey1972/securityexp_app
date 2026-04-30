import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';

/// Manages per-user client-side hiding of reported messages (Apple 1.2).
///
/// When a user reports a message, that message is added to the reporter's
/// `hidden_message_ids` array on their own user document. The chat UI
/// filters these IDs out so the reporter no longer sees the offending
/// message — providing immediate removal from the reporter's view while
/// the support ticket is pending review.
///
/// This is a per-user (reporter-only) hide. Other participants still see
/// the message until/unless an admin removes it via moderation. This is
/// intentional: it prevents weaponized self-reporting from deleting
/// content for everyone.
class HiddenMessagesService {
  final UserRepository _userRepository;
  final AppLogger _log;
  static const _tag = 'HiddenMessagesService';
  static const _field = 'hidden_message_ids';

  HiddenMessagesService({
    required UserRepository userRepository,
    required AppLogger log,
  })  : _userRepository = userRepository,
        _log = log;

  /// Whether [messageId] is currently hidden for the current user.
  bool isHidden(String messageId) {
    if (messageId.isEmpty) return false;
    final profile = UserProfileService().userProfile;
    return profile?.hiddenMessageIds.contains(messageId) ?? false;
  }

  /// Hides [messageId] for the current user.
  ///
  /// Persists to Firestore (`users/{uid}.hidden_message_ids` arrayUnion)
  /// and updates the local profile cache so the chat UI rebuilds and
  /// removes the message instantly.
  Future<void> hideMessage(String messageId) async {
    if (messageId.isEmpty) return;

    final profile = UserProfileService().userProfile;
    if (profile != null && profile.hiddenMessageIds.contains(messageId)) {
      // Already hidden; no-op.
      return;
    }

    _log.info('Hiding message: $messageId', tag: _tag);

    await ErrorHandler.handle<void>(
      operation: () => _userRepository.updateField(
        _field,
        FieldValue.arrayUnion([messageId]),
      ),
      onError: (e) =>
          _log.error('Failed to hide message $messageId: $e', tag: _tag),
    );

    // Update local cache so the UI reflects the hide instantly.
    if (profile != null) {
      UserProfileService().updateUserProfile(
        profile.copyWith(
          hiddenMessageIds: [...profile.hiddenMessageIds, messageId],
        ),
      );
    }
  }
}
