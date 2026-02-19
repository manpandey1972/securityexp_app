import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/calling/infrastructure/repositories/voip_token_repository.dart';
import 'package:greenhive_app/features/chat/services/user_presence_service.dart';
import 'package:greenhive_app/features/photo_backup/services/photo_backup_service.dart';
import 'package:greenhive_app/shared/services/firebase_messaging_service.dart';
import 'package:greenhive_app/shared/services/user_cache_service.dart';
import 'package:greenhive_app/shared/services/user_profile_service.dart';

/// Centralized cleanup for sign-out and account deletion.
///
/// Eliminates duplicated teardown logic between [AuthState] and
/// [UserRepository]. Both callers share the exact same cleanup
/// sequence, ordered so that Firestore listeners stop before
/// auth-dependent server calls execute.
class AccountCleanupService {
  final AppLogger _log;
  static const String _tag = 'AccountCleanup';

  bool _isCleaningUp = false;

  AccountCleanupService(this._log);

  /// Perform all client-side cleanup before sign-out or account deletion.
  ///
  /// [userId] – UID of the user being signed out (captured before auth
  /// state changes). Must be called **before** `FirebaseAuth.signOut()`
  /// to retain Firestore permissions for server-side token removal.
  ///
  /// Safe to call multiple times – subsequent calls while a cleanup is
  /// in progress are no-ops.
  Future<void> performCleanup(String userId) async {
    if (_isCleaningUp) {
      _log.info('Cleanup already in progress, skipping', tag: _tag);
      return;
    }

    _isCleaningUp = true;
    try {
      // 1. Stop Firestore listeners first (prevents permission-denied
      //    cascades when auth is revoked later)
      await _safeRun(
        () => sl<UserCacheService>().dispose(),
        'UserCacheService.dispose',
      );

      // 2. Clear server-side presence (requires auth)
      await _safeRunAsync(
        () => sl<UserPresenceService>().clearPresence(),
        'clearPresence',
      );
      await _safeRunAsync(
        () => sl<UserPresenceService>().dispose(),
        'presenceDispose',
      );

      // 3. Remove push-notification token (requires auth)
      await _safeRunAsync(
        () => sl<FirebaseMessagingService>().removeTokenOnLogout(),
        'FCM removeToken',
      );

      // 4. Clear VoIP token (requires auth for Firestore write)
      await _safeRunAsync(
        () => sl<VoIPTokenRepository>().clearToken(userId: userId),
        'VoIP clearToken',
      );
      await _safeRun(
        () => sl<VoIPTokenRepository>().dispose(),
        'VoIP dispose',
      );

      // 5. Stop photo-backup listener
      await _safeRunAsync(
        () => sl<PhotoBackupService>().dispose(),
        'PhotoBackup dispose',
      );

      // 6. Clear in-memory profile cache
      await _safeRun(
        () => UserProfileService().clearUserProfile(),
        'clearUserProfile',
      );

      _log.info('Cleanup completed for user $userId', tag: _tag);
    } finally {
      _isCleaningUp = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers — every cleanup step is wrapped so a single failure never blocks
  // the rest of the teardown sequence.
  // ---------------------------------------------------------------------------

  Future<void> _safeRun(void Function() fn, String label) async {
    try {
      fn();
    } catch (e) {
      _log.warning('$label failed: $e', tag: _tag);
    }
  }

  Future<void> _safeRunAsync(
    Future<void> Function() fn,
    String label,
  ) async {
    try {
      await fn();
    } catch (e) {
      _log.warning('$label failed: $e', tag: _tag);
    }
  }
}
