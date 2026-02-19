import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/widgets/profile_picture_widget.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/features/calling/widgets/call_room_constants.dart';
import 'package:greenhive_app/features/calling/widgets/mute_indicator_badge.dart';
import 'package:greenhive_app/features/calling/services/media/media_manager.dart';

/// Picture-in-Picture layer for video calls.
/// Shows local preview (or remote when swapped) in a draggable overlay.
class PipVideoLayer extends StatelessWidget {
  /// The media manager for building video views
  final MediaManager mediaManager;

  /// Current user for avatar when local camera is off
  final models.User? currentUser;

  /// Peer user for avatar when remote camera is off
  final models.User? peerUser;

  /// Display name of the peer
  final String displayName;

  /// Current position of the PiP layer
  final Offset position;

  /// Whether videos are swapped (local fullscreen, remote PiP)
  final bool swapVideos;

  /// Callback when PiP is dragged
  final void Function(DragUpdateDetails) onPanUpdate;

  /// Callback when PiP is double-tapped to swap
  final VoidCallback onDoubleTap;

  const PipVideoLayer({
    super.key,
    required this.mediaManager,
    required this.position,
    required this.swapVideos,
    required this.onPanUpdate,
    required this.onDoubleTap,
    required this.displayName,
    this.currentUser,
    this.peerUser,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onPanUpdate,
        onDoubleTap: onDoubleTap,
        child: Container(
          width: CallRoomConstants.pipWidth,
          height: CallRoomConstants.pipHeight,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.87),
            borderRadius: BorderRadius.circular(
              CallRoomConstants.pipBorderRadius,
            ),
            border: Border.all(
              color: AppColors.primary,
              width: CallRoomConstants.pipBorderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.background.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              CallRoomConstants.pipBorderRadius - 2,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [IgnorePointer(child: _buildContent())],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (swapVideos) {
      // Swapped: Remote is PiP
      return _buildRemotePiP();
    } else {
      // Default: Local is PiP
      return _buildLocalPiP();
    }
  }

  Widget _buildRemotePiP() {
    return ValueListenableBuilder<bool>(
      valueListenable: mediaManager.isRemoteVideoEnabled,
      builder: (ctx, enabled, _) {
        if (!enabled) {
          return _buildRemoteAvatarWithMute();
        }
        return _buildRemoteVideoWithMute();
      },
    );
  }

  Widget _buildRemoteAvatarWithMute() {
    return Stack(
      children: [
        Container(
          color: AppColors.surface,
          child: Center(
            child: peerUser != null
                ? ProfilePictureWidget(
                    user: peerUser!,
                    size: CallRoomConstants.avatarSizeSmall,
                    showBorder: false,
                  )
                : const Icon(
                    Icons.person,
                    size: CallRoomConstants.avatarSizeSmall,
                    color: AppColors.textSecondary,
                  ),
          ),
        ),
        if (mediaManager.isRemoteAudioMuted != null)
          Positioned(
            bottom: 4,
            right: 4,
            child: MuteIndicatorBadge(
              isMutedNotifier: mediaManager.isRemoteAudioMuted,
              style: MuteBadgeStyle.circleSmall,
            ),
          ),
      ],
    );
  }

  Widget _buildRemoteVideoWithMute() {
    return Stack(
      children: [
        mediaManager.buildRemoteVideo(
          fit: BoxFit.cover,
          placeholderName: displayName,
        ),
        if (mediaManager.isRemoteAudioMuted != null)
          Positioned(
            bottom: 4,
            right: 4,
            child: MuteIndicatorBadge(
              isMutedNotifier: mediaManager.isRemoteAudioMuted,
              style: MuteBadgeStyle.circleSmall,
            ),
          ),
      ],
    );
  }

  Widget _buildLocalPiP() {
    return ValueListenableBuilder<bool>(
      valueListenable: mediaManager.isVideoEnabled,
      builder: (ctx, enabled, _) {
        if (!enabled) {
          return Container(
            color: AppColors.surface,
            child: Center(
              child: currentUser != null
                  ? ProfilePictureWidget(
                      user: currentUser!,
                      size: CallRoomConstants.avatarSizeSmall,
                      showBorder: false,
                    )
                  : const Icon(
                      Icons.person,
                      size: CallRoomConstants.avatarSizeSmall,
                      color: AppColors.textSecondary,
                    ),
            ),
          );
        }
        return mediaManager.buildLocalPreview(fit: BoxFit.cover, mirror: true);
      },
    );
  }
}
