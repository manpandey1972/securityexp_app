import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../themes/app_colors.dart';
import '../themes/app_animations.dart';
import '../themes/app_icon_sizes.dart';
import '../themes/app_card_styles.dart';

/// A modern context menu widget that displays a list of actions in a popup.
/// Used for showing action options for content (similar to right-click context menus).
///
/// Usage:
/// ```dart
/// ContextMenu.show(
///   context: context,
///   actions: [
///     ContextMenuAction(
///       label: 'Edit',
///       icon: Icons.edit,
///       onTap: () => handleEdit(),
///     ),
///     ContextMenuAction(
///       label: 'Delete',
///       icon: Icons.delete,
///       isDestructive: true,
///       onTap: () => handleDelete(),
///     ),
///   ],
/// )
/// ```
class ContextMenu {
  ContextMenu._(); // Private constructor

  /// Show a context menu with the given actions
  static Future<void> show({
    required BuildContext context,
    required List<ContextMenuAction> actions,
    double width = 0.6,
    double maxHeight = 300,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _ContextMenuPopup(
        actions: actions,
        width: width,
        maxHeight: maxHeight,
      ),
    );
  }

  /// Show a context menu at a specific position
  static Future<void> showAtPosition({
    required BuildContext context,
    required Offset position,
    required List<ContextMenuAction> actions,
    double width = 200,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _PositionedContextMenu(
        position: position,
        actions: actions,
        width: width,
      ),
    );
  }
}

class _ContextMenuPopup extends StatelessWidget {
  final List<ContextMenuAction> actions;
  final double width;
  final double maxHeight;

  const _ContextMenuPopup({
    required this.actions,
    required this.width,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop with blur
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: AppColors.background.withValues(alpha: 0.3),
            ),
          ),
        ),

        // Context menu
        Center(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(
                parent: ModalRoute.of(context)!.animation!,
                curve: AppAnimations.enterEasing,
              ),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * width,
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: AppCardStyle.elevated,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    actions.length,
                    (index) => _buildAction(
                      context,
                      actions[index],
                      isLast: index == actions.length - 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAction(
    BuildContext context,
    ContextMenuAction action, {
    required bool isLast,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 100), action.onTap);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      color: action.isDestructive
                          ? AppColors.error
                          : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Icon(
                    action.icon,
                    color: action.isDestructive
                        ? AppColors.error
                        : AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Container(
            height: 1,
            color: AppColors.divider,
          ),
      ],
    );
  }
}

class _PositionedContextMenu extends StatelessWidget {
  final Offset position;
  final List<ContextMenuAction> actions;
  final double width;

  const _PositionedContextMenu({
    required this.position,
    required this.actions,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss area
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(color: Colors.transparent),
        ),

        // Positioned menu
        Positioned(
          left: position.dx,
          top: position.dy,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(
                parent: ModalRoute.of(context)!.animation!,
                curve: AppAnimations.enterEasing,
              ),
            ),
            child: Container(
              width: width,
              decoration: AppCardStyle.elevated,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  actions.length,
                  (index) => _buildAction(
                    context,
                    actions[index],
                    isLast: index == actions.length - 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAction(
    BuildContext context,
    ContextMenuAction action, {
    required bool isLast,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 100), action.onTap);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    action.icon,
                    color: action.isDestructive
                        ? AppColors.error
                        : AppColors.textSecondary,
                    size: AppIconSizes.small,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    action.label,
                    style: TextStyle(
                      color: action.isDestructive
                          ? AppColors.error
                          : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Container(
            height: 1,
            color: AppColors.divider,
          ),
      ],
    );
  }
}

/// Represents a single action in a context menu
class ContextMenuAction {
  /// Display label for the action
  final String label;

  /// Icon to display
  final IconData icon;

  /// Callback when action is tapped
  final VoidCallback onTap;

  /// Whether this is a destructive action (colored red)
  final bool isDestructive;

  /// Optional tooltip
  final String? tooltip;

  ContextMenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.tooltip,
  });
}

/// Helper builder for creating context menus from a list of tuples
class ContextMenuBuilder {
  ContextMenuBuilder._();

  /// Create context menu actions from simple data
  static Future<void> showFromItems({
    required BuildContext context,
    required List<({String label, IconData icon, VoidCallback onTap})> items,
    List<int> destructiveIndices = const [],
  }) {
    final actions = [
      for (int i = 0; i < items.length; i++)
        ContextMenuAction(
          label: items[i].label,
          icon: items[i].icon,
          onTap: items[i].onTap,
          isDestructive: destructiveIndices.contains(i),
        ),
    ];

    return ContextMenu.show(context: context, actions: actions);
  }
}
