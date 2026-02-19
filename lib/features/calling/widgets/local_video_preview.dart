import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';

import 'package:securityexperts_app/shared/widgets/profile_picture_widget.dart';
import 'package:securityexperts_app/data/models/models.dart';

/// Displays local camera preview in a small corner window (Picture-in-Picture style)
/// When video is disabled, shows "Video Off" indicator instead
/// Uses LiveKit SDK for video rendering
class LocalVideoPreview extends StatelessWidget {
  final LocalParticipant? localParticipant;
  final VideoTrack? videoTrack;
  final bool isVideoEnabled;
  final double width;
  final double height;
  final Alignment alignment;
  final double borderRadius;
  final bool mirror;
  final VoidCallback? onTap;
  final String? heroTag;
  final User? user; // User object for avatar
  final String? userName; // User name fallback

  const LocalVideoPreview({
    super.key,
    this.localParticipant,
    this.videoTrack,
    required this.isVideoEnabled,
    this.width = 120,
    this.height = 160,
    this.alignment = Alignment.bottomRight,
    this.borderRadius = 12,
    this.mirror = true,
    this.onTap,
    this.heroTag,
    this.user,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.primary, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.background.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildPreviewContent(),
    );

    if (onTap != null) {
      child = GestureDetector(onTap: onTap, child: child);
    }

    if (heroTag != null) {
      child = Hero(tag: heroTag!, child: child);
    }

    return Align(
      alignment: alignment,
      child: Padding(padding: const EdgeInsets.all(16.0), child: child),
    );
  }

  /// Build the appropriate preview content (video, profile pic, or icon)
  Widget _buildPreviewContent() {
    if (isVideoEnabled && videoTrack != null && !videoTrack!.muted) {
      // Show live video using LiveKit VideoTrackRenderer
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: VideoTrackRenderer(videoTrack!, fit: VideoViewFit.cover),
      );
    } else {
      // Show avatar/profile picture when video disabled or not available
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipOval(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: user != null
                      ? ProfilePictureWidget(
                          user: user!,
                          size: width * 0.7, // Reasonable size with padding
                          variant: 'thumbnail',
                          showBorder: false,
                        )
                      : Container(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          child: Center(
                            child: Text(
                              userName != null && userName!.isNotEmpty
                                  ? userName![0].toUpperCase()
                                  : '?',
                              style: AppTypography.headingLarge.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: width * 0.25,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}
