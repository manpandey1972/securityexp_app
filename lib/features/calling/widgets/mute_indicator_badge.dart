import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/features/calling/widgets/call_room_constants.dart';

/// Style variants for the mute indicator badge
enum MuteBadgeStyle {
  /// Banner style with text - used for prominent display
  banner,

  /// Small circular icon - used in PiP view
  circleSmall,

  /// Larger circular icon - used on video overlay
  circleLarge,
}

/// A reusable widget that displays a mute indicator badge
/// when the remote participant has muted their audio.
class MuteIndicatorBadge extends StatelessWidget {
  /// The ValueListenable that indicates if remote audio is muted
  final ValueListenable<bool>? isMutedNotifier;

  /// Display name for the banner style (e.g., "John is muted")
  final String? displayName;

  /// The style variant to render
  final MuteBadgeStyle style;

  const MuteIndicatorBadge({
    super.key,
    required this.isMutedNotifier,
    this.displayName,
    this.style = MuteBadgeStyle.banner,
  });

  @override
  Widget build(BuildContext context) {
    if (isMutedNotifier == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: isMutedNotifier!,
      builder: (context, isMuted, _) {
        if (!isMuted) {
          return const SizedBox.shrink();
        }

        return switch (style) {
          MuteBadgeStyle.banner => _buildBanner(),
          MuteBadgeStyle.circleSmall => _buildCircle(isSmall: true),
          MuteBadgeStyle.circleLarge => _buildCircle(isSmall: false),
        };
      },
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CallRoomConstants.muteBadgePaddingHorizontal,
        vertical: CallRoomConstants.muteBadgePaddingVertical,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(
          CallRoomConstants.muteBadgeBorderRadius,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic_off,
            color: AppColors.error,
            size: CallRoomConstants.muteBadgeIconSize,
          ),
          const SizedBox(width: 8),
          Text(
            displayName != null ? "$displayName is muted" : "Muted",
            style: AppTypography.captionSmall.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildCircle({required bool isSmall}) {
    final size = isSmall
        ? CallRoomConstants.muteBadgeIconSizeSmall
        : CallRoomConstants.muteBadgeIconSize + 4;
    final padding = isSmall ? 4.0 : 8.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: isSmall ? 0.7 : 0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.mic_off, color: AppColors.error, size: size),
    );
  }
}
