import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/widgets/profile_picture_widget.dart';
import 'package:securityexperts_app/data/models/models.dart' as models;
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/ratings/widgets/star_rating_input.dart';

/// Displays a single call history record with all call details
/// Extracted from call_page.dart _buildCallHistoryTile for better reusability
class CallHistoryCard extends StatelessWidget {
  /// Caller or callee display name
  final String displayName;

  /// Call direction: 'incoming', 'outgoing', or 'missed'
  final String direction;

  /// Whether this was a video call or audio call
  final bool isVideoCall;

  /// Call duration in seconds
  final int durationSeconds;

  /// When the call occurred
  final DateTime createdAt;

  /// User object for profile picture display (optional)
  final models.User? otherUser;

  /// Callback when chat button is tapped
  final VoidCallback? onChatTap;

  /// Callback when audio call button is tapped
  final VoidCallback? onAudioCallTap;

  /// Callback when video call button is tapped
  final VoidCallback? onVideoCallTap;

  /// Callback when card is tapped (optional)
  final VoidCallback? onTap;

  /// Callback when card is long-pressed (for selection mode)
  final VoidCallback? onLongPress;

  /// Callback when delete is requested (swipe or selection)
  final VoidCallback? onDelete;

  /// Callback when rate button is tapped
  final VoidCallback? onRateTap;

  /// Whether this card is currently selected
  final bool isSelected;

  /// Whether selection mode is active (shows checkboxes)
  final bool isSelectionMode;

  /// Custom leading widget (overrides profile picture if provided)
  final Widget? customLeading;

  /// Whether to show action buttons (chat, audio, video)
  final bool showActionButtons;

  /// Custom horizontal padding
  final double horizontalPadding;

  /// Custom vertical padding
  final double verticalPadding;

  /// Whether the call has been rated
  final bool hasRated;

  /// The rating given (if hasRated is true)
  final int? givenRating;

  const CallHistoryCard({
    super.key,
    required this.displayName,
    required this.direction,
    required this.isVideoCall,
    required this.durationSeconds,
    required this.createdAt,
    this.otherUser,
    this.onChatTap,
    this.onAudioCallTap,
    this.onVideoCallTap,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.onRateTap,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.customLeading,
    this.showActionButtons = true,
    this.horizontalPadding = 12,
    this.verticalPadding = 6,
    this.hasRated = false,
    this.givenRating,
  });

  /// Format duration string (e.g., "2m" or "45s")
  String _formatDuration(int seconds) {
    if (seconds >= 60) {
      return '${(seconds / 60).toStringAsFixed(0)}m';
    }
    return '${seconds}s';
  }

  /// Format date and time (e.g., "Today 2:30 PM" or "Jan 5, 2:30 PM")
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (dateToCheck == today) {
      dateStr = 'Today';
    } else if (dateToCheck == yesterday) {
      dateStr = 'Yesterday';
    } else {
      // Format as "Jan 5"
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      dateStr = '${months[dateTime.month]} ${dateTime.day}';
    }

    // Format time as "2:30 PM"
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$dateStr ${displayHour.toString().padLeft(1)}:${minute.toString().padLeft(2, '0')} $ampm';
  }

  /// Get color for direction indicator
  Color _getDirectionColor() {
    return direction == 'missed' ? AppColors.error : AppColors.textPrimary;
  }

  /// Get icon for call type
  IconData _getCallTypeIcon() {
    return isVideoCall ? Icons.videocam : Icons.call;
  }

  /// Get leading widget (profile picture or custom widget)
  Widget _buildLeading() {
    if (customLeading != null) {
      return customLeading!;
    }

    if (otherUser != null) {
      return ProfilePictureWidget(
        user: otherUser!,
        size: 48,
        showBorder: false,
        variant: 'thumbnail',
      );
    }

    return Icon(_getCallTypeIcon(), color: AppColors.primary, size: 24);
  }

  /// Build a single action button (chat, audio, video)
  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    String? tooltip,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Tooltip(
        message: tooltip ?? '',
        child: Icon(icon, size: 24, color: AppColors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidget = GestureDetector(
      onTap: isSelectionMode ? onTap : onTap,
      onLongPress: onLongPress,
      child: Card(
        margin: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: checkbox (in selection mode), profile picture, name, and action buttons
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Selection checkbox - red when selected for delete
                  if (isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onTap?.call(),
                      activeColor: AppColors.error,
                      checkColor: AppColors.white,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildLeading(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
                      style: AppTypography.headingXSmall.copyWith(
                        color: AppColors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showActionButtons && !isSelectionMode) ...[
                    const SizedBox(width: 18),
                    _buildActionButton(
                      onPressed: onChatTap,
                      icon: Icons.chat,
                      tooltip: 'Send message',
                    ),
                    const SizedBox(width: 18),
                    _buildActionButton(
                      onPressed: onAudioCallTap,
                      icon: Icons.call,
                      tooltip: 'Audio call',
                    ),
                    const SizedBox(width: 18),
                    _buildActionButton(
                      onPressed: onVideoCallTap,
                      icon: Icons.videocam,
                      tooltip: 'Video call',
                    ),
                  ],
                ],
              ),
              // Bottom row: call details (type, direction, time, duration)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: [
                    // Call type icon
                    Icon(
                      _getCallTypeIcon(),
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    // Direction label
                    Text(
                      direction,
                      style: AppTypography.captionSmall.copyWith(
                        color: _getDirectionColor(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Separator
                    Text('·', style: AppTypography.subtitle.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    // Time
                    Expanded(
                      child: Text(
                        _formatDateTime(createdAt),
                        style: AppTypography.subtitle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Separator
                    Text('·', style: AppTypography.subtitle.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    // Duration
                    Text(
                      _formatDuration(durationSeconds),
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Rating row - show "Rate Now" button or rating display
              if (direction != 'missed' && durationSeconds > 30 && !isSelectionMode && (hasRated || onRateTap != null)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: hasRated
                      ? Row(
                          children: [
                            Text(
                              'Your rating: ',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            StarRatingDisplay(
                              rating: (givenRating ?? 0).toDouble(),
                              size: 14,
                            ),
                          ],
                        )
                      : InkWell(
                          onTap: onRateTap,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_outline,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Rate this call',
                                  style: AppTypography.captionSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Wrap with Dismissible for swipe-to-delete when not in selection mode
    if (onDelete != null && !isSelectionMode) {
      return Dismissible(
        key: Key('${displayName}_${createdAt.millisecondsSinceEpoch}'),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: AppColors.white, size: 24),
        ),
        confirmDismiss: (direction) async {
          return true; // Confirmation handled at page level
        },
        onDismissed: (direction) => onDelete?.call(),
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}
