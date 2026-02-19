import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:greenhive_app/core/permissions/permission_types.dart';
import 'package:greenhive_app/providers/role_provider.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';

/// Widget that conditionally shows its child based on user role.
///
/// Use this widget to wrap admin-only UI elements. The child will only
/// be rendered if the user has at least the specified minimum role.
///
/// Example:
/// ```dart
/// AdminSection(
///   child: ListTile(
///     title: Text('Admin Dashboard'),
///     onTap: () => Navigator.pushNamed(context, '/admin'),
///   ),
/// )
/// ```
///
/// With custom minimum role:
/// ```dart
/// AdminSection(
///   minimumRole: UserRole.support,
///   child: Text('Support-only content'),
/// )
/// ```
class AdminSection extends StatelessWidget {
  /// The widget to show if the user has the required role.
  final Widget child;

  /// Optional fallback widget to show if user doesn't have required role.
  /// If null, returns [SizedBox.shrink()].
  final Widget? fallback;

  /// The minimum role required to show the child.
  /// Defaults to [UserRole.admin].
  final UserRole minimumRole;

  /// Whether to show a loading indicator while the role is being fetched.
  /// Defaults to false (shows nothing until role is known).
  final bool showLoadingIndicator;

  const AdminSection({
    super.key,
    required this.child,
    this.fallback,
    this.minimumRole = UserRole.admin,
    this.showLoadingIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, _) {
        // Show loading if not initialized and indicator is requested
        if (!roleProvider.isInitialized && showLoadingIndicator) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        // Check if user has the required role level
        final hasAccess = roleProvider.hasAtLeastRole(minimumRole);

        if (hasAccess) {
          return child;
        }

        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Guard widget for protecting entire routes from unauthorized access.
///
/// Use this widget to wrap entire pages that should only be accessible
/// to users with a specific role. Unauthorized users will see an
/// access denied screen.
///
/// Example:
/// ```dart
/// // In your router
/// GoRoute(
///   path: '/admin',
///   builder: (context, state) => const AdminRouteGuard(
///     child: AdminDashboardPage(),
///   ),
/// )
/// ```
///
/// With custom minimum role:
/// ```dart
/// AdminRouteGuard(
///   minimumRole: UserRole.support,
///   child: SupportTicketsPage(),
/// )
/// ```
class AdminRouteGuard extends StatelessWidget {
  /// The page to show if the user has the required role.
  final Widget child;

  /// The minimum role required to access this route.
  /// Defaults to [UserRole.admin].
  final UserRole minimumRole;

  /// Custom widget to show when access is denied.
  /// If null, shows a default access denied screen.
  final Widget? accessDeniedWidget;

  /// Whether to show a back button on the access denied screen.
  /// Defaults to true.
  final bool showBackButton;

  const AdminRouteGuard({
    super.key,
    required this.child,
    this.minimumRole = UserRole.admin,
    this.accessDeniedWidget,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, _) {
        // Show loading while role is being fetched
        if (!roleProvider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check if user has the required role level
        final hasAccess = roleProvider.hasAtLeastRole(minimumRole);

        if (hasAccess) {
          return child;
        }

        // Show access denied screen
        return accessDeniedWidget ?? _buildAccessDeniedScreen(context);
      },
    );
  }

  Widget _buildAccessDeniedScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 24),
              Text(
                'Access Denied',
                style: AppTypography.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You do not have permission to access this page.\n'
                'Required role: ${minimumRole.displayName}',
                textAlign: TextAlign.center,
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),
              if (showBackButton)
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget that shows different content based on specific permission.
///
/// Use this for fine-grained permission checks beyond just role level.
///
/// Example:
/// ```dart
/// PermissionSection(
///   permission: AdminPermission.manageFaqs,
///   child: FAQEditor(),
///   fallback: Text('You cannot edit FAQs'),
/// )
/// ```
class PermissionSection extends StatelessWidget {
  /// The widget to show if the user has the required permission.
  final Widget child;

  /// Optional fallback widget to show if user doesn't have permission.
  final Widget? fallback;

  /// The permission required to show the child.
  final AdminPermission permission;

  const PermissionSection({
    super.key,
    required this.child,
    required this.permission,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, _) {
        return FutureBuilder<bool>(
          future: roleProvider.hasPermission(permission),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            final hasPermission = snapshot.data ?? false;

            if (hasPermission) {
              return child;
            }

            return fallback ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
