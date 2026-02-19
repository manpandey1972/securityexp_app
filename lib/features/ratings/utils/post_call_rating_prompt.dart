import 'package:flutter/material.dart';
import 'package:securityexperts_app/features/ratings/pages/rating_page.dart';
import 'package:securityexperts_app/features/ratings/services/rating_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/shared/services/pending_notification_handler.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_spacing.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_borders.dart';

/// Utility to show the post-call rating prompt.
///
/// This should be called after a call ends to prompt the user
/// to rate the expert they just spoke with.
class PostCallRatingPrompt {
  static const String _tag = 'PostCallRatingPrompt';
  static final AppLogger _log = sl<AppLogger>();

  /// Shows a rating dialog after a call ends.
  ///
  /// Parameters:
  /// - [expertId]: ID of the expert who was in the call
  /// - [expertName]: Name of the expert
  /// - [callId]: The call/room ID (used as bookingId for rating)
  /// - [callDurationSeconds]: Duration of the call in seconds (optional)
  ///
  /// Only shows the dialog if:
  /// - The call lasted at least 30 seconds
  /// - The user hasn't already rated this call
  ///
  /// Note: Uses global navigator key for navigation, so no context needed.
  static Future<void> showIfEligible({
    required String expertId,
    required String expertName,
    required String callId,
    int? callDurationSeconds,
  }) async {
    // Don't show for very short calls (under 30 seconds)
    if (callDurationSeconds != null && callDurationSeconds < 30) {
      _log.debug(
        'Skipping rating prompt: call too short (${callDurationSeconds}s)',
        tag: _tag,
      );
      return;
    }

    // Check if already rated
    final ratingService = sl<RatingService>();
    _log.debug(
      'Checking if user already rated callId=$callId',
      tag: _tag,
    );
    
    final hasRated = await ratingService.hasRatedBooking(callId);
    
    if (hasRated) {
      _log.warning(
        '⏭️ Skipping rating prompt: already rated callId=$callId',
        tag: _tag,
      );
      return;
    }

    _log.info(
      '✅ User eligible for rating prompt - callId=$callId, expert=$expertName',
      tag: _tag,
    );

    // Use global navigator key to navigate - this works even after call page is popped
    final navigatorState = PendingNotificationHandler.navigatorKey.currentState;
    if (navigatorState == null) {
      _log.warning(
        '❌ Navigator state is null - cannot show rating prompt',
        tag: _tag,
      );
      return;
    }

    _log.info(
      '📱 Showing rating prompt for expert $expertName',
      tag: _tag,
    );

    try {
      // Navigate to rating page using global navigator
      await navigatorState.push(
        MaterialPageRoute(
          builder: (_) => RatingPage(
            expertId: expertId,
            expertName: expertName,
            bookingId: callId,
            sessionDate: DateTime.now(),
          ),
          fullscreenDialog: true,
        ),
      );
      _log.info(
        '✅ Rating dialog completed',
        tag: _tag,
      );
    } catch (e) {
      _log.error(
        '❌ Error showing rating dialog',
        tag: _tag,
        error: e,
      );
    }
  }

  /// Shows a compact rating dialog (bottom sheet) instead of full page.
  ///
  /// Use this for a less intrusive rating prompt.
  static Future<bool?> showCompactDialog({
    required BuildContext context,
    required String expertId,
    required String expertName,
    required String callId,
  }) async {
    // Check if already rated
    final ratingService = sl<RatingService>();
    final hasRated = await ratingService.hasRatedBooking(callId);
    
    if (hasRated) {
      _log.debug('Skipping compact rating: already rated', tag: _tag);
      return null;
    }

    if (!context.mounted) return null;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RatingBottomSheet(
        expertId: expertId,
        expertName: expertName,
        callId: callId,
      ),
    );
  }
}

/// Compact bottom sheet for rating prompt.
class _RatingBottomSheet extends StatelessWidget {
  final String expertId;
  final String expertName;
  final String callId;

  const _RatingBottomSheet({
    required this.expertId,
    required this.expertName,
    required this.callId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacing24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorders.radiusLarge)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(AppBorders.radiusSmall),
            ),
          ),
          const SizedBox(height: AppSpacing.spacing24),

          // Title
          Text(
            'How was your call with $expertName?',
            style: AppTypography.headingXSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.spacing24),

          // Rate Now button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RatingPage(
                      expertId: expertId,
                      expertName: expertName,
                      bookingId: callId,
                    ),
                    fullscreenDialog: true,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacing16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorders.radiusMedium),
                ),
              ),
              child: Text(
                'Rate Now',
                style: AppTypography.bodyEmphasis.copyWith(color: AppColors.white),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.spacing12),

          // Maybe later button
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Maybe Later',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.spacing16),
        ],
      ),
    );
  }
}
