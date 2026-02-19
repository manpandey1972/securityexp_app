import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/widgets/profile_picture_widget.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/features/calling/widgets/call_room_constants.dart';

/// A widget that displays an avatar with a subtle breathing/pulsing animation.
/// Used when video is turned off to show presence.
class BreathingAvatar extends StatefulWidget {
  /// The user whose avatar to display
  final models.User? user;

  /// Size of the avatar
  final double size;

  const BreathingAvatar({
    super.key,
    required this.user,
    this.size = CallRoomConstants.avatarSizeLarge,
  });

  @override
  State<BreathingAvatar> createState() => _BreathingAvatarState();
}

class _BreathingAvatarState extends State<BreathingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: CallRoomConstants.breathingAnimationDuration,
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) =>
          Transform.scale(scale: _animation.value, child: child),
      child: widget.user != null
          ? ProfilePictureWidget(
              user: widget.user!,
              size: widget.size,
              showBorder: true,
              variant: 'display',
            )
          : Container(
              width: widget.size,
              height: widget.size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: Icon(
                Icons.videocam_off,
                size: widget.size * 0.53,
                color: AppColors.textSecondary,
              ),
            ),
    );
  }
}
