import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

/// A badge widget displaying a user role with appropriate color coding.
///
/// Role colors:
/// - User: Secondary text color
/// - Expert: Green accent
/// - Support: Primary hover color
/// - Admin: Warm accent (orange)
/// - SuperAdmin: Error (red)
class AdminRoleBadge extends StatelessWidget {
  /// The role name to display.
  final String role;

  /// Whether to use a smaller size variant.
  final bool small;

  const AdminRoleBadge({
    super.key,
    required this.role,
    this.small = false,
  });

  /// Gets the color for a given role.
  static Color getColorForRole(String role) {
    return switch (role.toLowerCase()) {
      'expert' => AppColors.primaryLight,
      'support' => AppColors.primaryLight,
      'admin' => AppColors.warmAccent,
      'superadmin' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = getColorForRole(role);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 4 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatRole(role),
        style: AppTypography.captionSmall.copyWith(
          color: color,
          fontSize: small ? 10 : 12,
        ),
      ),
    );
  }

  /// Formats the role name with proper capitalization.
  String _formatRole(String role) {
    if (role.isEmpty) return role;
    return role.substring(0, 1).toUpperCase() + role.substring(1);
  }
}
