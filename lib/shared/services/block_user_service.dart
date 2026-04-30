import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/features/support/data/models/support_enums.dart';
import 'package:securityexperts_app/features/support/services/support_service.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';

/// Manages user blocking: persists to Firestore and updates the local profile cache.
///
/// Register as a lazy singleton in the service locator. Services that need to
/// check if a user is blocked call [isBlocked].
class BlockUserService {
  final UserRepository _userRepository;
  final SupportService _supportService;
  final AppLogger _log;
  static const _tag = 'BlockUserService';

  BlockUserService({
    required UserRepository userRepository,
    required SupportService supportService,
    required AppLogger log,
  })  : _userRepository = userRepository,
        _supportService = supportService,
        _log = log;

  /// Whether the given [userId] is currently blocked by the current user.
  bool isBlocked(String userId) {
    final profile = UserProfileService().userProfile;
    return profile?.blockedUserIds.contains(userId) ?? false;
  }

  /// Returns the current list of blocked user IDs.
  List<String> get blockedUserIds =>
      UserProfileService().userProfile?.blockedUserIds ?? [];

  /// Blocks [blockedUserId] for the current user.
  /// Persists to Firestore, updates the local profile cache, and creates a
  /// safety support ticket so the developer is notified of the block
  /// (required by Apple App Store Guideline 1.2).
  Future<void> blockUser(
    String blockedUserId, {
    String? blockedUserName,
  }) async {
    if (blockedUserId.isEmpty) return;
    _log.info('Blocking user: $blockedUserId', tag: _tag);

    await ErrorHandler.handle<void>(
      operation: () => _userRepository.updateField(
        'blocked_user_ids',
        FieldValue.arrayUnion([blockedUserId]),
      ),
      onError: (e) =>
          _log.error('Failed to block user $blockedUserId: $e', tag: _tag),
    );

    // Update local cache so the UI reflects the block instantly.
    final profile = UserProfileService().userProfile;
    if (profile != null && !profile.blockedUserIds.contains(blockedUserId)) {
      UserProfileService().updateUserProfile(
        profile.copyWith(
          blockedUserIds: [...profile.blockedUserIds, blockedUserId],
        ),
      );
    }

    // Notify developer via a safety support ticket. Required by Apple 1.2.
    final targetName = blockedUserName ?? 'Unknown user';
    await ErrorHandler.handle<void>(
      operation: () async {
        await _supportService.createTicket(
          type: TicketType.reportUser,
          category: TicketCategory.safety,
          subject: 'User blocked: $targetName',
          description:
              'User blocked another user.\n'
              'Blocked user ID: $blockedUserId\n'
              'Blocked user name: $targetName',
        );
      },
      onError: (e) => _log.warning(
        'Failed to create block notification ticket: $e',
        tag: _tag,
      ),
    );
  }

  /// Unblocks [blockedUserId] for the current user.
  Future<void> unblockUser(String blockedUserId) async {
    if (blockedUserId.isEmpty) return;
    _log.info('Unblocking user: $blockedUserId', tag: _tag);

    await ErrorHandler.handle<void>(
      operation: () => _userRepository.updateField(
        'blocked_user_ids',
        FieldValue.arrayRemove([blockedUserId]),
      ),
      onError: (e) =>
          _log.error('Failed to unblock user $blockedUserId: $e', tag: _tag),
    );

    // Update local cache
    final profile = UserProfileService().userProfile;
    if (profile != null) {
      UserProfileService().updateUserProfile(
        profile.copyWith(
          blockedUserIds: profile.blockedUserIds
              .where((id) => id != blockedUserId)
              .toList(),
        ),
      );
    }
  }

  /// Shows a confirmation dialog then blocks or unblocks the user.
  ///
  /// Returns `true` if the action was confirmed and executed.
  Future<bool> confirmAndToggleBlock(
    BuildContext context, {
    required String userId,
    required String userName,
  }) async {
    final alreadyBlocked = isBlocked(userId);
    final action = alreadyBlocked ? 'Unblock' : 'Block';
    final message = alreadyBlocked
        ? 'Unblock $userName? They will be able to contact you again.'
        : 'Block $userName? They will no longer be able to send you messages or contact you.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '$action User',
          style: AppTypography.bodyEmphasis.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: AppTypography.bodyEmphasis.copyWith(
                color: alreadyBlocked ? AppColors.primary : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    if (alreadyBlocked) {
      await unblockUser(userId);
    } else {
      await blockUser(userId, blockedUserName: userName);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyBlocked
                ? '$userName has been unblocked.'
                : '$userName has been blocked.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return true;
  }
}
