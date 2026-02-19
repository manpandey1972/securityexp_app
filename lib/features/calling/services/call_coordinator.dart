import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/calling/services/call_navigation_coordinator.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';

/// Consolidated service for call initiation and coordination
/// Combines CallService and CallInitiatorService functionality
class CallCoordinator {
  // Rate limiting guard
  static DateTime? _lastCallAttempt;
  static const Duration _callRateLimitDuration = Duration(seconds: 2);

  /// Start a call - permissions are handled by the media manager
  static Future<void> startCall({
    required BuildContext context,
    required String partnerId,
    required String partnerName,
    required bool isVideo,
  }) async {
    sl<AppLogger>().debug(
      'startCall() called - partnerId: $partnerId, isVideo: $isVideo',
      tag: 'CallCoordinator',
    );

    try {
      // Rate limiting: prevent rapid re-taps
      final now = DateTime.now();
      if (_lastCallAttempt != null &&
          now.difference(_lastCallAttempt!) < _callRateLimitDuration) {
        sl<AppLogger>().warning(
          'Rate limited - call attempt too soon (${now.difference(_lastCallAttempt!).inMilliseconds}ms since last attempt)',
          tag: 'CallCoordinator',
        );
        return;
      }
      _lastCallAttempt = now;
      sl<AppLogger>().debug('Rate limit check passed', tag: 'CallCoordinator');

      final user = sl<firebase_auth.FirebaseAuth>().currentUser;
      if (user == null) {
        sl<AppLogger>().warning('No user signed in', tag: 'CallCoordinator');
        SnackbarService.show('Please sign in to make calls');
        return;
      }
      sl<AppLogger>().debug('User authenticated: ${user.uid}', tag: 'CallCoordinator');

      if (partnerId.isEmpty) {
        sl<AppLogger>().warning('Partner ID is empty', tag: 'CallCoordinator');
        SnackbarService.show('Cannot start call: Partner ID not available');
        return;
      }

      sl<AppLogger>().debug('Starting call with partner: $partnerId', tag: 'CallCoordinator');

      // Simply initiate the call UI - let the media manager handle permissions
      // This matches how chat handles audio/video messages
      sl<AppLogger>().debug('Initiating call UI...', tag: 'CallCoordinator');
      if (context.mounted) {
        CallNavigationCoordinator().initiateCall(
          calleeId: partnerId,
          calleeName: partnerName,
          isVideo: isVideo,
          isCaller: true,
        );
        sl<AppLogger>().debug('Call UI initiated successfully', tag: 'CallCoordinator');
      } else {
        sl<AppLogger>().warning('Context not mounted', tag: 'CallCoordinator');
      }
    } catch (e) {
      sl<AppLogger>().error('Error starting call', tag: 'CallCoordinator', error: e);
      if (context.mounted) {
        SnackbarService.show('Failed to start call: $e');
      }
    }
  }

  /// Start call with context-bound approach (legacy support)
  static Future<void> startCallWithContext({
    required BuildContext context,
    required String? partnerId,
    required String? partnerName,
    required bool isVideo,
  }) async {
    if (partnerId == null || partnerId.isEmpty) {
      SnackbarService.show('Cannot start call: Partner ID not available');
      return;
    }

    await startCall(
      context: context,
      partnerId: partnerId,
      partnerName: partnerName ?? 'User',
      isVideo: isVideo,
    );
  }

  /// Validate call eligibility
  /// Returns true if user can make calls, false otherwise
  static bool canStartCall(firebase_auth.User? user) {
    return user != null;
  }

  /// Show delete message confirmation dialog (utility method)
  static Future<bool?> showDeleteMessageDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Delete Message',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.normal),
        ),
        content: const Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.normal),
        ),
        actions: [
          AppButtonVariants.dialogCancel(
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            label: 'Delete',
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}
