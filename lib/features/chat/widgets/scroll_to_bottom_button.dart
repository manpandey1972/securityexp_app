import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/features/chat/utils/chat_utils.dart';

class ScrollToBottomButton extends StatefulWidget {
  final ItemPositionsListener itemPositionsListener;
  final ItemScrollController itemScrollController;

  const ScrollToBottomButton({
    super.key,
    required this.itemPositionsListener,
    required this.itemScrollController,
  });

  @override
  State<ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<ScrollToBottomButton> {
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener.itemPositions.addListener(
      _updateButtonVisibility,
    );
  }

  void _updateButtonVisibility() {
    final positions = widget.itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final isBottomVisible = positions.any((p) => p.index == 0);
    final shouldShow = !isBottomVisible;

    if (_showButton != shouldShow) {
      setState(() => _showButton = shouldShow);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showButton
        ? Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textPrimary,
                ),
                onPressed: () {
                  if (widget.itemScrollController.isAttached) {
                    widget.itemScrollController.scrollTo(
                      index: 0,
                      duration: ChatConstants.scrollAnimationDuration,
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}
