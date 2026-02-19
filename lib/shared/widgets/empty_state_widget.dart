import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../themes/app_spacing.dart';
import '../themes/app_typography.dart';
import 'app_button_variants.dart';

/// Reusable empty state widget for displaying when no data is available
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final double iconSize;
  final EdgeInsets padding;
  final bool showAction;

  const EmptyStateWidget({
    super.key,
    this.icon = Icons.inbox,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconSize = 64,
    this.padding = const EdgeInsets.all(24),
    this.showAction = true,
  });

  /// Factory constructor for list empty state
  factory EmptyStateWidget.list({
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
    EdgeInsets? padding,
  }) {
    return EmptyStateWidget(
      icon: Icons.inbox_outlined,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: AppColors.textMuted,
      padding: padding ?? const EdgeInsets.all(24),
    );
  }

  /// Factory constructor for search empty state
  factory EmptyStateWidget.search({
    required String query,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: 'No Results Found',
      description: 'No items found for "$query"',
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: AppColors.textMuted,
    );
  }

  /// Factory constructor for error/failed state
  factory EmptyStateWidget.error({
    required String title,
    required String description,
    String? actionLabel = 'Try Again',
    VoidCallback? onAction,
  }) {
    return EmptyStateWidget(
      icon: Icons.error_outline,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: AppColors.error,
    );
  }

  /// Factory constructor for no connection state
  factory EmptyStateWidget.noConnection({
    String? actionLabel = 'Retry',
    VoidCallback? onAction,
  }) {
    return EmptyStateWidget(
      icon: Icons.wifi_off,
      title: 'No Connection',
      description: 'Please check your internet connection and try again.',
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: AppColors.warning,
    );
  }

  /// Factory constructor for no permission state
  factory EmptyStateWidget.noPermission({
    required String title,
    required String description,
    String? actionLabel = 'Grant Permission',
    VoidCallback? onAction,
  }) {
    return EmptyStateWidget(
      icon: Icons.lock_outline,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: AppColors.textMuted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// Icon
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? AppColors.textMuted,
            ),
            SizedBox(height: AppSpacing.spacing16),

            /// Title
            Text(
              title,
              style: AppTypography.headingMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.spacing8),

            /// Description
            Text(
              description,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            /// Action Button (if provided)
            if (showAction && actionLabel != null && onAction != null) ...[
              SizedBox(height: AppSpacing.spacing24),
              AppButtonVariants.actionWithIcon(
                onPressed: onAction!,
                icon: Icons.refresh,
                label: actionLabel!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
