import 'package:flutter/material.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/widgets/profile_picture_widget.dart';
import 'package:greenhive_app/features/ratings/widgets/expert_rating_summary.dart';

/// Reusable Expert Card widget that displays expert info with action buttons.
///
/// Features:
/// - Profile picture with fallback
/// - Expert name and expertise
/// - Rating display (if available)
/// - Three action buttons: chat, audio call, video call
/// - Tap to view full profile
/// - Optional custom callbacks for actions
///
/// Usage:
/// ```dart
/// ExpertCard(
///   expert: expertUser,
///   skillNames: utils.getSkillNames(expertUser.expertises),
///   onChat: (expertId, name) => startChat(expertId, name),
///   onAudioCall: (expertId, name) => startAudioCall(expertId, name),
///   onVideoCall: (expertId, name) => startVideoCall(expertId, name),
///   onTap: () => navigateToProfile(expert),
/// )
/// ```
class ExpertCard extends StatelessWidget {
  static const String _tag = 'ExpertCard';
  final AppLogger _log = sl<AppLogger>();

  /// The expert user data
  final models.User expert;

  /// List of formatted skill/expertise names (already mapped from IDs)
  /// Example: ['Flutter', 'Dart', 'Firebase']
  final List<String> skillNames;

  /// Callback when chat button is tapped
  /// Parameters: expertId, expertName
  final Function(String, String)? onChat;

  /// Callback when audio call button is tapped
  /// Parameters: expertId, expertName
  final Function(String, String)? onAudioCall;

  /// Callback when video call button is tapped
  /// Parameters: expertId, expertName
  final Function(String, String)? onVideoCall;

  /// Callback when card is tapped (usually navigate to profile)
  final Function()? onTap;

  /// Whether to show profile picture
  final bool showProfilePicture;

  /// Size of the profile picture
  final double profilePictureSize;

  /// Elevation of the card
  final double elevation;

  /// Enable/disable action buttons
  final bool enableActions;

  /// Expert's average rating (0-5)
  final double? averageRating;

  /// Total number of ratings
  final int? totalRatings;

  ExpertCard({
    super.key,
    required this.expert,
    this.skillNames = const [],
    this.onChat,
    this.onAudioCall,
    this.onVideoCall,
    this.onTap,
    this.showProfilePicture = true,
    this.profilePictureSize = 56,
    this.elevation = 0,
    this.enableActions = true,
    this.averageRating,
    this.totalRatings,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spacing12,
          vertical: AppSpacing.spacing8,
        ),
        elevation: elevation,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          hoverColor: AppColors.primaryLight.withValues(alpha: 0.05),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacing12,
              vertical: AppSpacing.spacing12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: profile picture, name, action buttons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile picture
                    if (showProfilePicture)
                      ProfilePictureWidget(
                        user: expert,
                        size: profilePictureSize,
                        showBorder: false,
                        variant: 'thumbnail',
                      ),
                    if (showProfilePicture) const SizedBox(width: 12),

                    // Name and expertise
                    Expanded(
                      child: Text(
                        expert.name,
                        style: AppTypography.headingXSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    // Action buttons
                    if (enableActions) ...[
                      // Chat button
                      GestureDetector(
                        onTap: onChat != null
                            ? () => onChat!(expert.id, expert.name)
                            : null,
                        child: Icon(
                          Icons.chat,
                          size: 24,
                          color: onChat != null
                              ? AppColors.white
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 18),

                      // Audio call button
                      GestureDetector(
                        onTap: onAudioCall != null
                            ? () {
                                _log.debug(
                                  'Audio call button tapped for ${expert.name}',
                                  tag: _tag,
                                );
                                onAudioCall!(expert.id, expert.name);
                              }
                            : null,
                        child: Icon(
                          Icons.call,
                          size: 24,
                          color: onAudioCall != null
                              ? AppColors.white
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 18),

                      // Video call button
                      GestureDetector(
                        onTap: onVideoCall != null
                            ? () {
                                _log.debug(
                                  'Video call button tapped for ${expert.name}',
                                  tag: _tag,
                                );
                                onVideoCall!(expert.id, expert.name);
                              }
                            : null,
                        child: Icon(
                          Icons.videocam,
                          size: 24,
                          color: onVideoCall != null
                              ? AppColors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),

                // Rating display - show badge or "No reviews yet"
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: (averageRating != null && totalRatings != null && totalRatings! > 0)
                      ? ExpertRatingBadge(
                          averageRating: averageRating!,
                          totalRatings: totalRatings!,
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_outline_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'No reviews yet',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                ),

                // Expertise string (if available)
                if (skillNames.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      skillNames.join(', '),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
