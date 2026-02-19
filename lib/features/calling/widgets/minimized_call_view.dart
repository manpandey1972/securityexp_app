import 'package:flutter/material.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/widgets/profile_picture_widget.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/features/calling/pages/call_controller.dart';

class MinimizedCallView extends StatefulWidget {
  final CallController controller;
  final User? peerUser;
  final String displayName;
  final VoidCallback onRestore;

  const MinimizedCallView({
    super.key,
    required this.controller,
    required this.peerUser,
    required this.displayName,
    required this.onRestore,
  });

  @override
  State<MinimizedCallView> createState() => _MinimizedCallViewState();
}

class _MinimizedCallViewState extends State<MinimizedCallView> {
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'MinimizedCallView';

  @override
  Widget build(BuildContext context) {
    // Safety check - if controller is disposed or state is invalid, show minimal fallback
    if (widget.controller.isDisposed ||
        widget.controller.callState == CallState.ended ||
        widget.controller.callState == CallState.failed) {
      _log.warning('Controller in invalid state', tag: _tag, data: {
        'disposed': widget.controller.isDisposed,
        'callState': widget.controller.callState.toString()
      });
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.background,
        child: const Center(
          child: Text(
            'Call ended',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.normal),
          ),
        ),
      );
    }

    _log.verbose('Building', tag: _tag, data: {
      'hasMediaManager': widget.controller.mediaManager != null,
      'isVideo': widget.controller.isVideo,
      'callState': widget.controller.callState.toString()
    });

    // CallOverlay handles the outer Material wrapper and styling
    // Background is non-interactive to allow dragging
    // Only the control buttons at bottom are interactive
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background, // Match main call screen background
      child: Stack(
        children: [
          // Background - Video or Avatar (non-interactive for dragging)
          Positioned.fill(
            child: IgnorePointer(child: _buildBackground(context)),
          ),

          // Overlay gradient (non-interactive)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Controls (interactive)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: _buildControls(context),
          ),

          // Remote mute indicator - wrapped in safety check
          if (!widget.controller.isDisposed &&
              widget.controller.mediaManager?.isRemoteAudioMuted != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Builder(
                builder: (context) {
                  try {
                    return ValueListenableBuilder<bool>(
                      valueListenable:
                          widget.controller.mediaManager!.isRemoteAudioMuted!,
                      builder: (context, isMuted, _) {
                        if (!isMuted) return const SizedBox.shrink();

                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic_off,
                                  color: AppColors.error,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  "Muted",
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  } catch (e) {
                    _log.error('Error building remote mute indicator', tag: _tag, error: e);
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    // Early exit if controller is disposed
    if (widget.controller.isDisposed) {
      return _buildAvatar();
    }

    final mediaManager = widget.controller.mediaManager;
    if (mediaManager == null) {
      return _buildAvatar();
    }

    // Use try-catch to handle disposed ValueNotifier
    try {
      return ValueListenableBuilder<bool>(
        valueListenable: mediaManager.isRemoteVideoEnabled,
        builder: (context, remoteVideoEnabled, _) {
          final isConnected =
              widget.controller.callState == CallState.connected;

          if (isConnected && widget.controller.isVideo && remoteVideoEnabled) {
            try {
              return mediaManager.buildRemoteVideo(
                placeholderName: widget.displayName,
                fit: BoxFit.cover,
              );
            } catch (e) {
              _log.error('Error building remote video', tag: _tag, error: e);
              return _buildAvatar();
            }
          }
          return _buildAvatar();
        },
      );
    } catch (e) {
      _log.error('Error in _buildBackground', tag: _tag, error: e);
      return _buildAvatar();
    }
  }

  Widget _buildAvatar() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: widget.peerUser != null
            ? ProfilePictureWidget(
                user: widget.peerUser!,
                size: 60,
                showBorder: true,
                variant: 'display',
              )
            : CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.surfaceVariant,
                child: Text(
                  (widget.displayName.isNotEmpty
                          ? widget.displayName
                          : 'User')[0]
                      .toUpperCase(),
                  style: AppTypography.headingLarge,
                ),
              ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    // Early exit if controller is disposed
    if (widget.controller.isDisposed) {
      return const SizedBox.shrink();
    }

    final mediaManager = widget.controller.mediaManager;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Consume taps in control area to prevent propagation to background
        _log.verbose('Control area tapped', tag: _tag);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute Toggle - only show if mediaManager is valid
            if (mediaManager != null)
              Builder(
                builder: (context) {
                  try {
                    return ValueListenableBuilder<bool>(
                      valueListenable: mediaManager.isMuted,
                      builder: (context, isMuted, _) {
                        return GestureDetector(
                          onTap: () => widget.controller.toggleMute(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isMuted
                                  ? AppColors.textPrimary
                                  : AppColors.surface.withValues(alpha: 0.54),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isMuted ? Icons.mic_off : Icons.mic,
                              color: isMuted
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                              size: 18,
                            ),
                          ),
                        );
                      },
                    );
                  } catch (e) {
                    _log.error('Error building mute button', tag: _tag, error: e);
                    return const SizedBox.shrink();
                  }
                },
              ),

            // End Call
            GestureDetector(
              onTap: () => widget.controller.endCall(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_end,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
