import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import 'app_button_variants.dart';

/// Swipeable list item widget with customizable actions
/// Provides modern swipe-to-action pattern for list items
class SwipeableListItem extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;
  final VoidCallback? onEdit;
  final List<SwipeAction>? customActions;
  final double actionWidth;
  final Curve curve;
  final Duration animationDuration;

  const SwipeableListItem({
    super.key,
    required this.child,
    this.onDelete,
    this.onArchive,
    this.onEdit,
    this.customActions,
    this.actionWidth = 80,
    this.curve = Curves.easeOutCubic,
    this.animationDuration = const Duration(milliseconds: 250),
  });

  @override
  State<SwipeableListItem> createState() => _SwipeableListItemState();
}

class _SwipeableListItemState extends State<SwipeableListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  double _dragExtent = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    // Drag started - could add haptic feedback here if needed
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final width = context.size?.width ?? 1;

    setState(() {
      _dragExtent = (_dragExtent + delta).clamp(-width, 0.0);
      _controller.value = (_dragExtent.abs() / width).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final width = context.size?.width ?? 1;

    // If swiped more than 40% or fast swipe velocity, reveal actions
    if (_dragExtent.abs() > width * 0.4 || velocity < -300) {
      _controller.forward();
    } else {
      _controller.reverse();
      _dragExtent = 0;
    }
  }

  void _executeAction(VoidCallback? action) {
    _controller.reverse();
    _dragExtent = 0;
    action?.call();
  }

  List<SwipeAction> _getActions() {
    if (widget.customActions != null && widget.customActions!.isNotEmpty) {
      return widget.customActions!;
    }

    final actions = <SwipeAction>[];

    if (widget.onDelete != null) {
      actions.add(
        SwipeAction(
          icon: Icons.delete,
          color: AppColors.error,
          label: 'Delete',
          onTap: widget.onDelete!,
        ),
      );
    }

    if (widget.onArchive != null) {
      actions.add(
        SwipeAction(
          icon: Icons.archive,
          color: AppColors.primary,
          label: 'Archive',
          onTap: widget.onArchive!,
        ),
      );
    }

    if (widget.onEdit != null) {
      actions.add(
        SwipeAction(
          icon: Icons.edit,
          color: AppColors.primaryLight,
          label: 'Edit',
          onTap: widget.onEdit!,
        ),
      );
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final actions = _getActions();

    if (actions.isEmpty) {
      return widget.child;
    }

    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          // Background actions
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions.map((action) {
                return Container(
                  width: widget.actionWidth,
                  color: action.color,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _executeAction(action.onTap),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(action.icon, color: AppColors.white, size: AppIconSizes.standard),
                          if (action.label != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              action.label!,
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Foreground content
          SlideTransition(position: _slideAnimation, child: widget.child),
        ],
      ),
    );
  }
}

/// Model for swipe actions
class SwipeAction {
  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback onTap;

  const SwipeAction({
    required this.icon,
    required this.color,
    this.label,
    required this.onTap,
  });
}

/// Quick preset for delete-only swipe
class SwipeToDelete extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  final String deleteLabel;

  const SwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.deleteLabel = 'Delete',
  });

  @override
  Widget build(BuildContext context) {
    return SwipeableListItem(
      onDelete: onDelete,
      customActions: [
        SwipeAction(
          icon: Icons.delete_outline,
          color: AppColors.error,
          label: deleteLabel,
          onTap: onDelete,
        ),
      ],
      child: child,
    );
  }
}

/// Dismissible alternative with confirmation
class SwipeToDismiss extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismissed;
  final String? confirmationMessage;
  final Color backgroundColor;
  final IconData icon;

  const SwipeToDismiss({
    super.key,
    required this.child,
    required this.onDismissed,
    this.confirmationMessage,
    this.backgroundColor = AppColors.error,
    this.icon = Icons.delete,
  });

  Future<bool> _confirmDismiss(BuildContext context) async {
    if (confirmationMessage == null) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(confirmationMessage!),
        actions: [
          AppButtonVariants.dialogCancel(
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            label: 'Confirm',
            isPrimary: true,
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDismiss(context),
      onDismissed: (direction) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: backgroundColor,
        child: Icon(icon, color: AppColors.white, size: AppIconSizes.large),
      ),
      child: child,
    );
  }
}
