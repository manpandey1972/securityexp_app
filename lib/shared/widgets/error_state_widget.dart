import 'package:flutter/material.dart';
import 'package:securityexperts_app/features/support/services/issue_reporter.dart';
import '../themes/app_colors.dart';
import '../themes/app_spacing.dart';
import '../themes/app_typography.dart';
import 'app_button_variants.dart';

/// Reusable error state widget for displaying error messages
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onRetry;
  final Color? iconColor;
  final double iconSize;
  final EdgeInsets padding;
  final bool showAction;
  final Widget? details;
  /// Whether to show "Report Issue" button.
  final bool showReportIssue;

  const ErrorStateWidget({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.error_outline,
    this.actionLabel = 'Retry',
    this.onRetry,
    this.iconColor,
    this.iconSize = 64,
    this.padding = const EdgeInsets.all(24),
    this.showAction = true,
    this.details,
    this.showReportIssue = false,
  });

  /// Factory constructor for network error
  factory ErrorStateWidget.network({
    String? title = 'Network Error',
    String? message = 'Failed to load data. Please check your connection.',
    String? actionLabel = 'Retry',
    VoidCallback? onRetry,
    EdgeInsets? padding,
  }) {
    return ErrorStateWidget(
      title: title ?? 'Network Error',
      message: message,
      icon: Icons.cloud_off,
      actionLabel: actionLabel,
      onRetry: onRetry,
      iconColor: AppColors.warning,
      padding: padding ?? const EdgeInsets.all(24),
    );
  }

  /// Factory constructor for server error
  factory ErrorStateWidget.server({
    String? title = 'Server Error',
    String? message = 'Something went wrong. Please try again later.',
    String? actionLabel = 'Retry',
    VoidCallback? onRetry,
    EdgeInsets? padding,
  }) {
    return ErrorStateWidget(
      title: title ?? 'Server Error',
      message: message,
      icon: Icons.storage,
      actionLabel: actionLabel,
      onRetry: onRetry,
      iconColor: AppColors.error,
      padding: padding ?? const EdgeInsets.all(24),
    );
  }

  /// Factory constructor for permission error
  factory ErrorStateWidget.permission({
    required String title,
    String? message = 'You do not have permission to access this resource.',
    String? actionLabel = 'Grant Permission',
    VoidCallback? onRetry,
    EdgeInsets? padding,
  }) {
    return ErrorStateWidget(
      title: title,
      message: message,
      icon: Icons.lock_outline,
      actionLabel: actionLabel,
      onRetry: onRetry,
      iconColor: AppColors.textMuted,
      padding: padding ?? const EdgeInsets.all(24),
    );
  }

  /// Factory constructor for timeout error
  factory ErrorStateWidget.timeout({
    String? title = 'Request Timeout',
    String? message = 'The request took too long. Please try again.',
    String? actionLabel = 'Retry',
    VoidCallback? onRetry,
    EdgeInsets? padding,
  }) {
    return ErrorStateWidget(
      title: title ?? 'Request Timeout',
      message: message,
      icon: Icons.schedule,
      actionLabel: actionLabel,
      onRetry: onRetry,
      iconColor: AppColors.warning,
      padding: padding ?? const EdgeInsets.all(24),
    );
  }

  /// Factory constructor for not found error
  factory ErrorStateWidget.notFound({
    required String title,
    String? message = 'The requested resource was not found.',
    String? actionLabel = 'Go Back',
    VoidCallback? onRetry,
    EdgeInsets? padding,
  }) {
    return ErrorStateWidget(
      title: title,
      message: message,
      icon: Icons.person_off_outlined,
      actionLabel: actionLabel,
      onRetry: onRetry,
      iconColor: AppColors.textMuted,
      padding: padding ?? const EdgeInsets.all(24),
    );
  }

  /// Factory constructor for validation error
  factory ErrorStateWidget.validation({
    required String title,
    required String message,
    String? actionLabel = 'Fix Errors',
    VoidCallback? onRetry,
    EdgeInsets? padding,
  }) {
    return ErrorStateWidget(
      title: title,
      message: message,
      icon: Icons.warning_amber,
      actionLabel: actionLabel,
      onRetry: onRetry,
      iconColor: AppColors.warning,
      padding: padding ?? const EdgeInsets.all(24),
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
            Container(
              width: iconSize + 16,
              height: iconSize + 16,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.error).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? AppColors.error,
              ),
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

            /// Message (if provided)
            if (message != null) ...[
              SizedBox(height: AppSpacing.spacing8),
              Text(
                message!,
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            /// Details (if provided)
            if (details != null) ...[
              SizedBox(height: AppSpacing.spacing16),
              details!,
            ],

            /// Retry Button
            if (showAction && actionLabel != null && onRetry != null) ...[
              SizedBox(height: AppSpacing.spacing24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButtonVariants.actionWithIcon(
                    onPressed: onRetry!,
                    icon: Icons.refresh,
                    label: actionLabel!,
                  ),
                ],
              ),
            ],

            /// Report Issue Button
            if (showReportIssue) ...[
              SizedBox(height: AppSpacing.spacing12),
              TextButton.icon(
                onPressed: () => IssueReporter.reportIssue(
                  errorMessage: message,
                  errorContext: title,
                ),
                icon: Icon(
                  Icons.bug_report_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                label: Text(
                  'Report Issue',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
