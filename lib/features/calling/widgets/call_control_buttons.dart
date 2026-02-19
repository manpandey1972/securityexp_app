import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_spacing.dart';
import 'package:securityexperts_app/features/calling/services/audio_device_service.dart';
import 'package:securityexperts_app/features/calling/widgets/audio_device_selector.dart';

/// Control buttons for call operations (mute, video, speaker, end call, etc.)
/// Extracted from call_page.dart for better reusability and separation
class CallControlButtons extends StatelessWidget {
  final VoidCallback onToggleMute;
  final VoidCallback onToggleVideo;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;
  final VoidCallback? onFlipCamera;
  final VoidCallback? onMinimize; // Made optional for backward compatibility
  final bool isMuted;
  final bool isVideoEnabled;
  final bool isSpeakerEnabled;
  final bool isVideoCall;
  final bool isMinimized; // Hide non-essential buttons when in PiP mode
  final MainAxisAlignment mainAxisAlignment;
  final double buttonSize;
  final double iconSize;

  /// Audio device service for showing device selector (optional)
  /// If provided, speaker button becomes an audio device selector
  final AudioDeviceService? audioDeviceService;

  const CallControlButtons({
    super.key,
    required this.onToggleMute,
    required this.onToggleVideo,
    required this.onToggleSpeaker,
    required this.onEndCall,
    this.onFlipCamera,
    this.onMinimize,
    required this.isMuted,
    required this.isVideoEnabled,
    required this.isSpeakerEnabled,
    required this.isVideoCall,
    this.isMinimized = false,
    this.mainAxisAlignment = MainAxisAlignment.spaceEvenly,
    this.buttonSize = 48,
    this.iconSize = 24,
    this.audioDeviceService,
  });

  /// Build a single control button
  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color activeColor,
    required Color inactiveColor,
    required bool isActive,
    String? tooltip,
  }) {
    return _ScaleButton(
      onPressed: onPressed,
      tooltip: tooltip ?? '',
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          shape: BoxShape.circle,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            icon,
            color: isActive
                ? (activeColor == AppColors.error
                      ? AppColors.white
                      : AppColors.textPrimary)
                : AppColors.textPrimary,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  /// Build audio device selector button
  /// Shows current device icon and opens selector on tap
  Widget _buildAudioDeviceButton(BuildContext context) {
    if (audioDeviceService == null) {
      // Fallback to simple speaker toggle button
      return _buildControlButton(
        onPressed: onToggleSpeaker,
        icon: isSpeakerEnabled ? Icons.volume_up : Icons.volume_off,
        activeColor: AppColors.surface.withValues(alpha: 0.54),
        inactiveColor: AppColors.surface.withValues(alpha: 0.54),
        isActive: isSpeakerEnabled,
        tooltip: isSpeakerEnabled ? 'Disable speaker' : 'Enable speaker',
      );
    }

    // Use StreamBuilder to react to device changes
    return StreamBuilder<AudioDevice>(
      stream: audioDeviceService!.onDeviceChanged,
      initialData: audioDeviceService!.currentDevice,
      builder: (context, snapshot) {
        final currentDevice = snapshot.data ?? AudioDevice.speaker;

        // Get icon for current device
        IconData deviceIcon;
        switch (currentDevice) {
          case AudioDevice.speaker:
            deviceIcon = Icons.volume_up;
            break;
          case AudioDevice.earpiece:
            deviceIcon = Icons.phone_android;
            break;
          case AudioDevice.bluetooth:
            deviceIcon = Icons.bluetooth_audio;
            break;
          case AudioDevice.headset:
            deviceIcon = Icons.headset;
            break;
          case AudioDevice.carplay:
            deviceIcon = Icons.directions_car;
            break;
          case AudioDevice.unknown:
            deviceIcon = Icons.volume_up;
            break;
        }

        return _ScaleButton(
          onPressed: () {
            AudioDeviceSelector.show(
              context,
              audioDeviceService: audioDeviceService!,
            );
          },
          tooltip: 'Audio output',
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.54),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                deviceIcon,
                color: AppColors.textPrimary,
                size: iconSize,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Auto-detect if we should use minimized layout based on available width
        // If less than 250px available, use minimized layout to prevent overflow
        final bool autoMinimized = constraints.maxWidth < 250;
        final bool useMinimizedLayout = isMinimized || autoMinimized;

        // Adjust spacing for very constrained spaces
        final double spacing = constraints.maxWidth < 140
            ? AppSpacing.spacing4
            : AppSpacing.spacing12;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.spacing16,
            vertical: AppSpacing.spacing12,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            spacing: spacing,
            children: [
              // Minimize button (hide when already minimized)
              if (onMinimize != null && !useMinimizedLayout)
                _buildControlButton(
                  onPressed: onMinimize!,
                  icon: Icons.picture_in_picture_alt,
                  activeColor: AppColors.surface.withValues(alpha: 0.54),
                  inactiveColor: AppColors.surface.withValues(alpha: 0.54),
                  isActive: false,
                  tooltip: 'Minimize call',
                ),

              // Mute button (always show)
              _buildControlButton(
                onPressed: onToggleMute,
                icon: isMuted ? Icons.mic_off : Icons.mic,
                activeColor: AppColors.error,
                inactiveColor: AppColors.surface.withValues(alpha: 0.54),
                isActive: isMuted,
                tooltip: isMuted ? 'Unmute' : 'Mute',
              ),

              // Video button (only for video calls, always show)
              if (isVideoCall)
                _buildControlButton(
                  onPressed: onToggleVideo,
                  icon: Icons.videocam,
                  activeColor: AppColors.error,
                  inactiveColor: AppColors.surface.withValues(alpha: 0.54),
                  isActive: !isVideoEnabled,
                  tooltip: isVideoEnabled ? 'Disable video' : 'Enable video',
                ),

              // Audio device button (hide when minimized, not on web)
              if (!useMinimizedLayout && !kIsWeb)
                _buildAudioDeviceButton(context),

              // Flip camera button (only for video calls, not on web, hide when minimized)
              if (isVideoCall &&
                  onFlipCamera != null &&
                  !kIsWeb &&
                  !useMinimizedLayout)
                _buildControlButton(
                  onPressed: onFlipCamera!,
                  icon: Icons.flip_camera_ios,
                  activeColor: AppColors.surface.withValues(alpha: 0.54),
                  inactiveColor: AppColors.surface.withValues(alpha: 0.54),
                  isActive: false,
                  tooltip: 'Flip camera',
                ),

              // End call button (red, prominent)
              _ScaleButton(
                onPressed: onEndCall,
                tooltip: 'End call',
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.call_end,
                      color: AppColors.white,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Button with scale animation and haptic feedback on press
class _ScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final String tooltip;

  const _ScaleButton({
    required this.onPressed,
    required this.child,
    this.tooltip = '',
  });

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    // Haptic feedback on press
    if (!kIsWeb) {
      HapticFeedback.mediumImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onPressed();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: AnimatedScale(
            scale: _isPressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
