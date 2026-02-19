import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';

/// Animated checkmark widget for success feedback
/// Usage: Show this widget after successful actions like saving, sending, etc.
class SuccessAnimation extends StatefulWidget {
  final double size;
  final VoidCallback? onComplete;
  final Duration duration;

  const SuccessAnimation({
    super.key,
    this.size = 80,
    this.onComplete,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    // Scale animation (0.0 -> 1.0 -> 1.1 -> 1.0)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    // Checkmark draw animation (0.0 -> 1.0)
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
      ),
    );

    _controller.forward().then((_) {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: CustomPaint(
              painter: _CheckmarkPainter(
                progress: _checkAnimation.value,
                color: AppColors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for animated checkmark
class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Checkmark coordinates (relative to size)
    final double startX = size.width * 0.25;
    final double startY = size.height * 0.5;
    final double midX = size.width * 0.45;
    final double midY = size.height * 0.65;
    final double endX = size.width * 0.75;
    final double endY = size.height * 0.35;

    // Total path length (approximation)
    final firstSegmentLength = 0.4; // First 40% of animation
    final secondSegmentLength = 0.6; // Last 60% of animation

    if (progress <= firstSegmentLength) {
      // Draw first part of checkmark (down-left)
      final segmentProgress = progress / firstSegmentLength;
      path.moveTo(startX, startY);
      path.lineTo(
        startX + (midX - startX) * segmentProgress,
        startY + (midY - startY) * segmentProgress,
      );
    } else {
      // Draw complete first segment and animate second segment (up-right)
      final segmentProgress =
          (progress - firstSegmentLength) / secondSegmentLength;
      path.moveTo(startX, startY);
      path.lineTo(midX, midY);
      path.lineTo(
        midX + (endX - midX) * segmentProgress,
        midY + (endY - midY) * segmentProgress,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Helper widget to show success animation in a dialog
Future<void> showSuccessDialog(
  BuildContext context, {
  String? message,
  Duration displayDuration = const Duration(milliseconds: 1500),
}) async {
  return showDialog(
    context: context,
    barrierColor: AppColors.surface,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SuccessAnimation(size: 100),
          if (message != null) ...[
            SizedBox(height: AppSpacing.spacing16),
            Text(
              message,
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    ),
  ).then((_) {
    // Auto-dismiss after duration
    Future.delayed(displayDuration, () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  });
}
