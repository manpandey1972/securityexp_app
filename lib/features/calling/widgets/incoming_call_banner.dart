import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/widgets/profile_picture_widget.dart';
import 'package:securityexperts_app/data/models/models.dart' as models;
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

/// iOS CallKit-style incoming call banner with expand/collapse functionality
/// Starts as a compact banner at the top and can expand to full screen
class IncomingCallBanner extends StatefulWidget {
  /// Caller's display name
  final String callerName;

  /// Caller's user ID
  final String callerId;

  /// Whether this is a video call
  final bool isVideoCall;

  /// Caller's user object (for profile picture)
  final models.User? callerUser;

  /// Called when the accept button is pressed
  final VoidCallback? onAccept;

  /// Called when the decline button is pressed
  final VoidCallback? onDecline;

  /// Whether to start expanded (full screen)
  final bool startExpanded;

  const IncomingCallBanner({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.isVideoCall,
    this.callerUser,
    this.onAccept,
    this.onDecline,
    this.startExpanded = false,
  });

  @override
  State<IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends State<IncomingCallBanner>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  models.User? _fetchedCallerUser;

  static const String _tag = 'IncomingCallBanner';
  final AppLogger _log = sl<AppLogger>();

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.startExpanded;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    if (_isExpanded) {
      _animationController.value = 1.0;
    }

    // Fetch actual user from Firestore for profile picture
    _fetchCallerUser();
  }

  Future<void> _fetchCallerUser() async {
    if (widget.callerId.isEmpty) return;

    try {
      // Use UserCacheService for cached user fetching - avoids redundant Firestore reads
      final user = await sl<UserCacheService>().getOrFetch(widget.callerId);
      if (mounted && user != null) {
        // Use post-frame callback to ensure we don't setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _fetchedCallerUser = user;
            });
          }
        });
      }
    } catch (e) {
      _log.warning('Failed to fetch caller user: $e', tag: _tag);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final expandValue = _expandAnimation.value;

        // Interpolate dimensions
        final bannerHeight = lerpDouble(80, size.height, expandValue)!;
        final bannerTop = lerpDouble(topPadding + 8, 0, expandValue)!;
        final bannerLeft = lerpDouble(12, 0, expandValue)!;
        final bannerRight = lerpDouble(12, 0, expandValue)!;
        final borderRadius = lerpDouble(16, 0, expandValue)!;

        return Stack(
          children: [
            // Dimmed background (only when expanded)
            if (expandValue > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _isExpanded ? _toggleExpand : null,
                  child: Container(
                    color: AppColors.background.withValues(
                      alpha: 0.7 * expandValue,
                    ),
                  ),
                ),
              ),

            // Banner/Full screen card
            Positioned(
              top: bannerTop,
              left: bannerLeft,
              right: bannerRight,
              child: GestureDetector(
                onTap: _isExpanded ? null : _toggleExpand,
                onVerticalDragEnd: (details) {
                  // Swipe down to collapse, swipe up to expand
                  if (details.velocity.pixelsPerSecond.dy > 200 &&
                      _isExpanded) {
                    _toggleExpand();
                  } else if (details.velocity.pixelsPerSecond.dy < -200 &&
                      !_isExpanded) {
                    _toggleExpand();
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Material(
                      color: _isExpanded
                          ? AppColors.surfaceVariant
                          : AppColors.surfaceVariant.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Container(
                        height: bannerHeight,
                        decoration: expandValue < 1
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  borderRadius,
                                ),
                                border: Border.all(
                                  color: AppColors.divider.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 0.5,
                                ),
                              )
                            : null,
                        child: expandValue < 0.5
                            ? _buildCompactBanner()
                            : _buildExpandedView(size),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Compact banner view (CallKit-style)
  Widget _buildCompactBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // App icon / Caller photo
          _buildCompactAvatar(),
          const SizedBox(width: 12),

          // Caller info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.callerName,
                  style: AppTypography.bodyEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      isVideoCall ? Icons.videocam : Icons.phone,
                      color: AppColors.textSecondary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVideoCall ? 'Video Call' : 'Audio Call',
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Compact action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decline button
              _CompactActionButton(
                icon: Icons.call_end,
                color: AppColors.error,
                onPressed: widget.onDecline,
              ),
              const SizedBox(width: 8),
              // Accept button
              _CompactActionButton(
                icon: isVideoCall ? Icons.videocam : Icons.call,
                color: AppColors.primary,
                onPressed: widget.onAccept,
                isPulsing: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Expanded full-screen view
  Widget _buildExpandedView(Size size) {
    return SafeArea(
      child: Column(
        children: [
          // Handle indicator for collapse
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          const Spacer(),

          // Caller photo
          _buildExpandedAvatar(),
          const SizedBox(height: 24),

          // Caller name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.callerName,
              style: AppTypography.headingLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),

          // Call type indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isVideoCall ? Icons.videocam : Icons.phone,
                color: AppColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isVideoCall ? 'Video Call' : 'Audio Call',
                style: AppTypography.captionEmphasis.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Action buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 60, left: 48, right: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline
                _ExpandedActionButton(
                  icon: Icons.call_end,
                  color: AppColors.error,
                  onPressed: widget.onDecline,
                ),
                // Accept
                _ExpandedActionButton(
                  icon: isVideoCall ? Icons.videocam : Icons.call,
                  color: AppColors.primary,
                  onPressed: widget.onAccept,
                  isPulsing: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAvatar() {
    // Prefer fetched user (has real profilePictureUrl from Firestore)
    // Fall back to widget.callerUser (synthetic user with generated URL)
    final user = _fetchedCallerUser ?? widget.callerUser;

    if (user != null) {
      return SizedBox(
        width: 48,
        height: 48,
        child: ProfilePictureWidget(
          user: user,
          size: 48,
          showBorder: false,
          variant: 'thumbnail',
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isVideoCall ? Icons.videocam : Icons.call,
        color: AppColors.primary,
        size: 24,
      ),
    );
  }

  Widget _buildExpandedAvatar() {
    // Prefer fetched user (has real profilePictureUrl from Firestore)
    // Fall back to widget.callerUser (synthetic user with generated URL)
    final user = _fetchedCallerUser ?? widget.callerUser;

    if (user != null) {
      return SizedBox(
        width: 120,
        height: 120,
        child: ProfilePictureWidget(
          user: user,
          size: 120,
          showBorder: true,
          variant: 'thumbnail',
        ),
      );
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isVideoCall ? Icons.videocam : Icons.call,
        color: AppColors.primary,
        size: 56,
      ),
    );
  }

  bool get isVideoCall => widget.isVideoCall;
}

/// Compact circular action button for banner view
class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isPulsing;

  const _CompactActionButton({
    required this.icon,
    required this.color,
    this.onPressed,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.white, size: 22),
      ),
    );

    if (isPulsing) {
      return _PulsingWrapper(child: button);
    }
    return button;
  }
}

/// Expanded action button (icons only)
class _ExpandedActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isPulsing;

  const _ExpandedActionButton({
    required this.icon,
    required this.color,
    this.onPressed,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.white, size: 28),
      ),
    );

    if (isPulsing) {
      return _PulsingWrapper(child: button);
    }
    return button;
  }
}

/// Pulsing animation wrapper
class _PulsingWrapper extends StatefulWidget {
  final Widget child;

  const _PulsingWrapper({required this.child});

  @override
  State<_PulsingWrapper> createState() => _PulsingWrapperState();
}

class _PulsingWrapperState extends State<_PulsingWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}
