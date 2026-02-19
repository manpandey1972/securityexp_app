import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/widgets/profile_picture_widget.dart';
import 'package:greenhive_app/features/calling/widgets/call_duration_display.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/features/calling/widgets/call_room_constants.dart';
import 'package:greenhive_app/features/calling/widgets/mute_indicator_badge.dart';

/// Widget for displaying the audio-only call UI.
/// Shows peer avatar, name, duration, and mute indicator.
class AudioCallView extends StatelessWidget {
  /// Display name of the peer
  final String displayName;

  /// Peer user profile for avatar
  final models.User? peerUser;

  /// ValueListenable for call duration in seconds
  final ValueListenable<int> durationSeconds;

  /// ValueListenable for remote audio mute state
  final ValueListenable<bool>? isRemoteAudioMuted;

  const AudioCallView({
    super.key,
    required this.displayName,
    required this.durationSeconds,
    this.peerUser,
    this.isRemoteAudioMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Compute the height available for content above call controls.
          // Full content needs ~213px (avatar 120 + spacing 36 + text ~57).
          final contentHeight =
              constraints.maxHeight - CallRoomConstants.controlsBottomReserve;

          // Three layout tiers based on effective content height:
          //  minimized  (<150): PIP / tiny — avatar only, no bottom reserve
          //  compact  (<230): small screen — medium avatar + tighter spacing
          //  full     (≥230): normal — large avatar + full spacing + mute badge
          final isMinimized = contentHeight < 150;
          final isCompact = !isMinimized && contentHeight < 230;
          final bottomReserve = isMinimized
              ? 0.0
              : CallRoomConstants.controlsBottomReserve;

          return Stack(
            children: [
              // Center the content with space for bottom controls
              Positioned.fill(
                bottom: bottomReserve,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMinimized)
                        _buildAvatar(size: _AvatarSize.medium)
                      else ...[
                        _buildAvatar(
                          size: isCompact
                              ? _AvatarSize.medium
                              : _AvatarSize.large,
                        ),
                        SizedBox(height: isCompact ? 16 : 24),
                        _buildDisplayName(),
                        SizedBox(height: isCompact ? 8 : 12),
                        _buildDuration(),
                      ],
                    ],
                  ),
                ),
              ),
              // Mute indicator at top (full mode only)
              if (isRemoteAudioMuted != null && !isMinimized && !isCompact)
                Positioned(
                  top: CallRoomConstants.topOffset,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: MuteIndicatorBadge(
                      isMutedNotifier: isRemoteAudioMuted,
                      displayName: displayName,
                      style: MuteBadgeStyle.banner,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar({_AvatarSize size = _AvatarSize.large}) {
    final avatarSize = switch (size) {
      _AvatarSize.large => CallRoomConstants.avatarSizeLarge,
      _AvatarSize.medium => CallRoomConstants.avatarSizeMedium,
      _AvatarSize.small => CallRoomConstants.avatarSizeSmall,
    };
    final iconSize = switch (size) {
      _AvatarSize.large => CallRoomConstants.avatarIconSizeLarge,
      _AvatarSize.medium => CallRoomConstants.avatarIconSizeMedium,
      _AvatarSize.small => CallRoomConstants.avatarIconSizeSmall,
    };

    if (peerUser != null) {
      return ProfilePictureWidget(
        user: peerUser!,
        size: avatarSize,
        showBorder: true,
        variant: 'display',
      );
    }

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.background.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.person,
        size: iconSize,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildDisplayName() {
    return Text(
      displayName,
      style: AppTypography.headingMedium.copyWith(
        color: AppColors.textPrimary,
        fontWeight: AppTypography.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDuration() {
    return ValueListenableBuilder<int>(
      valueListenable: durationSeconds,
      builder: (ctx, duration, _) {
        return CallDurationDisplay(
          durationSeconds: duration,
          textStyle: AppTypography.bodyEmphasis.copyWith(
            color: AppColors.textSecondary,
            fontWeight: AppTypography.regular,
          ),
        );
      },
    );
  }
}

/// Avatar size tier for responsive layout.
enum _AvatarSize { large, medium, small }
