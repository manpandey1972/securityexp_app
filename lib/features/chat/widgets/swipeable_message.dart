import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';

/// Wrapper widget that enables swipe-to-reply gesture on message bubbles
/// Swipe direction depends on message position:
/// - Own messages (right): swipe left
/// - Peer messages (left): swipe right
class SwipeableMessage extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  final bool fromMe;

  const SwipeableMessage({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
    required this.fromMe,
  }) : super();

  @override
  State<SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<SwipeableMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _isSwiped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Direction based on message position
    // Own messages (right side): slide left, icon on right
    // Peer messages (left side): slide right, icon on left
    final slideOffset = widget.fromMe ? -0.3 : 0.3;

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(slideOffset, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetSwipe() {
    _controller.reverse();
    _isSwiped = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Own messages: swipe left (dx < 0)
        // Peer messages: swipe right (dx > 0)
        final isValidSwipe = widget.fromMe
            ? details.delta.dx <
                  -5 // Swipe left for own messages
            : details.delta.dx > 5; // Swipe right for peer messages

        final isReverseSwipe = widget.fromMe
            ? details.delta.dx > 5
            : details.delta.dx < -5;

        if (!_isSwiped && isValidSwipe) {
          // Start animation
          _controller.forward();
          _isSwiped = true;
        } else if (_isSwiped && isReverseSwipe) {
          // Reverse animation
          _controller.reverse();
          _isSwiped = false;
        }
      },
      onHorizontalDragEnd: (details) {
        // If swiped far enough, trigger reply
        if (_isSwiped && _controller.value > 0.5) {
          widget.onReply();
          _resetSwipe();
        } else {
          _resetSwipe();
        }
      },
      child: Stack(
        children: [
          // Background with reply action
          Positioned.fill(
            child: Align(
              alignment: widget.fromMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  right: widget.fromMe ? 16.0 : 0,
                  left: widget.fromMe ? 0 : 16.0,
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0, end: 1).animate(
                    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          widget.onReply();
                          _resetSwipe();
                        },
                        child: Tooltip(
                          message: 'Reply',
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warmAccent.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.reply,
                              color: AppColors.warmAccent,
                              size: AppIconSizes.medium,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Message bubble on top with slide animation
          SlideTransition(position: _slideAnimation, child: widget.child),
        ],
      ),
    );
  }
}
