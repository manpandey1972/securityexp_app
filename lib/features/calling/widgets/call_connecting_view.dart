import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/widgets/profile_picture_widget.dart';
import 'package:greenhive_app/data/models/models.dart';

/// Banner-style connecting view (similar to incoming call banner)
/// Shows a compact draggable banner while connecting to the call
class CallConnectingView extends StatefulWidget {
  final String displayName;
  final User? peerUser;
  final String status;
  final VoidCallback onEndCall;

  const CallConnectingView({
    super.key,
    required this.displayName,
    this.peerUser,
    required this.status,
    required this.onEndCall,
  });

  @override
  State<CallConnectingView> createState() => _CallConnectingViewState();
}

class _CallConnectingViewState extends State<CallConnectingView> {
  // Banner position - starts at top
  double? _top;
  double? _left;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Initialize position on first build
    if (!_initialized) {
      _top = topPadding + 8;
      _left = 12;
      _initialized = true;
    }

    // Banner dimensions
    const bannerHeight = 80.0;
    const horizontalMargin = 12.0;
    final bannerWidth = size.width - (horizontalMargin * 2);

    return Stack(
      children: [
        // Draggable compact banner
        Positioned(
          top: _top,
          left: _left,
          width: bannerWidth,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _top = (_top! + details.delta.dy).clamp(
                  topPadding + 8,
                  size.height - bannerHeight - bottomPadding - 8,
                );
                _left = (_left! + details.delta.dx).clamp(
                  8.0,
                  size.width - bannerWidth - 8,
                );
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Material(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: bannerHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: _buildBannerContent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Drag handle indicator
          Container(
            width: 4,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Avatar with pulse animation
          _buildCompactAvatar(),
          const SizedBox(width: 12),

          // Caller info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.displayName,
                  style: AppTypography.bodyEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _AnimatedStatusText(status: widget.status),
              ],
            ),
          ),

          // End call button
          GestureDetector(
            onTap: widget.onEndCall,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_end,
                color: AppColors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAvatar() {
    if (widget.peerUser != null) {
      return _PulsingAvatar(
        child: SizedBox(
          width: 48,
          height: 48,
          child: ProfilePictureWidget(
            user: widget.peerUser!,
            size: 48,
            showBorder: false,
            variant: 'thumbnail',
          ),
        ),
      );
    }

    return _PulsingAvatar(
      child: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.surfaceVariant,
        child: Text(
          (widget.displayName.isNotEmpty ? widget.displayName : 'User')[0].toUpperCase(),
          style: AppTypography.bodyEmphasis.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Pulsing animation widget wrapper for avatar during connecting state
class _PulsingAvatar extends StatefulWidget {
  final Widget child;

  const _PulsingAvatar({required this.child});

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.95,
      end: 1.05,
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
      child: widget.child,
    );
  }
}

/// Animated status text with pulsing dots for "Connecting..." state
class _AnimatedStatusText extends StatefulWidget {
  final String status;

  const _AnimatedStatusText({required this.status});

  @override
  State<_AnimatedStatusText> createState() => _AnimatedStatusTextState();
}

class _AnimatedStatusTextState extends State<_AnimatedStatusText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _fadeAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a "Connecting..." type status
    final isConnecting = widget.status.toLowerCase().contains('connect');

    if (!isConnecting) {
      // For other statuses, show without animation
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.phone_in_talk,
            color: AppColors.textSecondary,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            widget.status,
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    // Animated connecting text with pulsing dots
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        // Calculate which dots to show based on animation progress
        final progress = _controller.value;
        final dotCount = ((progress * 3) % 4).floor();
        final dots = '.' * dotCount;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sync,
              color: AppColors.textSecondary,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              widget.status
                  .replaceAll('...', '')
                  .replaceAll('..', '')
                  .replaceAll('.', ''),
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(
              width: 16, // Fixed width for dots to prevent text shifting
              child: Text(
                dots,
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textSecondary.withValues(
                    alpha: _fadeAnimation.value,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
