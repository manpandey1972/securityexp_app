import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

import 'package:securityexperts_app/shared/widgets/profile_picture_widget.dart';
import 'package:securityexperts_app/data/models/models.dart';

/// Displays remote video stream from peer
/// Uses LiveKit SDK for video rendering
class RemoteVideoView extends StatelessWidget {
  final Participant? liveKitParticipant;
  final VideoTrack? liveKitVideoTrack;
  final bool showPlaceholder;
  final String? placeholderName;
  final Widget? placeholder;
  final User? user; // User object for avatar

  const RemoteVideoView({
    super.key,
    this.liveKitParticipant,
    this.liveKitVideoTrack,
    this.showPlaceholder = true,
    this.placeholderName,
    this.placeholder,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    // LiveKit video rendering - check if video track is available AND not muted
    if (liveKitVideoTrack != null &&
        liveKitParticipant != null &&
        showPlaceholder != true) {
      final videoTrack = liveKitVideoTrack as VideoTrack;
      // If track is muted, show placeholder instead
      if (videoTrack.muted) {
        return _buildPlaceholder();
      }
      return SizedBox.expand(
        child: VideoTrackRenderer(
          videoTrack,
          fit: VideoViewFit.cover, // Ensure full screen cover
        ),
      );
    }

    // Show placeholder when no video available or explicitly disabled
    if (showPlaceholder) {
      return _buildPlaceholder();
    }

    return const SizedBox.expand();
  }

  /// Build placeholder UI when video is not available
  Widget _buildPlaceholder() {
    if (placeholder != null) {
      return placeholder!;
    }

    // If user is available, show avatar with name and status
    if (user != null) {
      return Container(
        color: AppColors.surfaceVariant,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ProfilePictureWidget(
                user: user!,
                size: 120, // Large avatar for remote view
                showBorder: false,
              ),
              const SizedBox(height: 24),
              if (placeholderName != null)
                Text(
                  placeholderName!,
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.semiBold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, color: AppColors.textSecondary, size: 64),
            const SizedBox(height: 16),
            if (placeholderName != null)
              Text(
                placeholderName!,
                style: AppTypography.messageText.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else
              const Text(
                'Waiting for video...',
                style: AppTypography.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
