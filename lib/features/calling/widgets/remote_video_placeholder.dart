import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/widgets/profile_picture_widget.dart';
import 'package:securityexperts_app/data/models/models.dart' as models;
import 'package:securityexperts_app/features/calling/widgets/call_room_constants.dart';
import 'package:securityexperts_app/features/calling/widgets/mute_indicator_badge.dart';

/// Widget displayed when remote participant's camera is off.
/// Shows an avatar placeholder with optional mute indicator.
class RemoteVideoPlaceholder extends StatelessWidget {
  /// Display name of the peer
  final String displayName;

  /// Peer user profile for avatar
  final models.User? peerUser;

  /// Whether the remote stream is connected
  final bool hasStream;

  /// Whether to show "Connecting..." text
  final bool showConnecting;

  /// ValueListenable for remote audio mute state
  final ValueListenable<bool>? isRemoteAudioMuted;

  const RemoteVideoPlaceholder({
    super.key,
    required this.displayName,
    required this.hasStream,
    required this.showConnecting,
    this.peerUser,
    this.isRemoteAudioMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background,
      alignment: Alignment.center,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(),
                const SizedBox(height: 16),
                Text(
                  showConnecting
                      ? "Connecting..."
                      : "$displayName turned off camera",
                  style: AppTypography.bodyEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Mute indicator
          if (hasStream && isRemoteAudioMuted != null)
            Positioned(
              top: 80,
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
      ),
    );
  }

  Widget _buildAvatar() {
    if (peerUser != null) {
      return ProfilePictureWidget(
        user: peerUser!,
        size: CallRoomConstants.avatarSizeLarge,
        showBorder: true,
        variant: 'display',
      );
    }

    return Container(
      width: CallRoomConstants.avatarSizeLarge,
      height: CallRoomConstants.avatarSizeLarge,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
      ),
      child: const Icon(
        Icons.person,
        size: CallRoomConstants.avatarIconSizeLarge,
        color: AppColors.textPrimary,
      ),
    );
  }
}
