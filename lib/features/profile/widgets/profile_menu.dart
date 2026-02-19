import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/providers/auth_provider.dart';
import 'package:securityexperts_app/providers/role_provider.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/features/phone_auth/pages/phone_auth_screen.dart';
import 'package:securityexperts_app/features/support/pages/support_hub_page.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';

/// Reusable Profile Menu widget for user profile actions.
///
/// Features:
/// - Displays greeting with user name
/// - Edit profile option
/// - Logout with confirmation dialog
/// - Integrates with UserProfileService for global state
///
/// Usage:
/// ```dart
/// PopupMenuButton<String>(
///   icon: const Icon(Icons.person),
///   color: AppColors.surface,
///   offset: const Offset(0, 50),
///   onSelected: (value) async {
///     if (value == 'edit_profile') {
///       // Navigate to profile page
///     } else if (value == 'logout') {
///       // Logout handled by dialog
///     }
///   },
///   itemBuilder: (context) => ProfileMenu.buildMenuItems(
///     context,
///     onLogoutConfirmed: () => handleLogout(),
///   ),
/// )
/// ```
class ProfileMenu {
  /// Build standard menu items for profile menu
  /// Returns list of PopupMenuEntry widgets
  static List<PopupMenuEntry<String>> buildMenuItems(
    BuildContext context, {
    required Function() onLogoutConfirmed,
    required Function() onDeleteAccountConfirmed,
  }) {
    final userName = UserProfileService().userProfile?.name ?? 'User';

    return [
      // Header: User greeting
      PopupMenuItem(
        enabled: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Hi $userName',
            style: AppTypography.bodyEmphasis.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
      const PopupMenuDivider(),

      // Edit Profile option
      PopupMenuItem(
        value: 'edit_profile',
        child: Row(
          children: [
            Icon(Icons.edit, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Update Profile',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // Notifications toggle option
      PopupMenuItem(
        value: 'toggle_notifications',
        child: Row(
          children: [
            Icon(
              UserProfileService().userProfile?.notificationsEnabled == true
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              size: 20,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              UserProfileService().userProfile?.notificationsEnabled == true
                  ? 'Notifications On'
                  : 'Notifications Off',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Switch(
              value:
                  UserProfileService().userProfile?.notificationsEnabled ??
                  true,
              onChanged: null, // Handled by menu selection
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // Help & Support option
      PopupMenuItem(
        value: 'help_support',
        child: Row(
          children: [
            Icon(Icons.support_agent, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 8),
              Text(
                'Help Center',
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // Admin Dashboard option - only shown for support/admin/superadmin users
      if (_isAdminUser(context)) ...[
        PopupMenuItem(
          value: 'admin_dashboard',
          child: Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Admin Dashboard',
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ],

      // Delete Account option
      PopupMenuItem(
        value: 'delete_account',
        child: Row(
          children: [
            Icon(Icons.delete_forever, size: 20, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'Delete Account',
              style: AppTypography.bodyRegular.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // Logout option
      PopupMenuItem(
        value: 'logout',
        child: Row(
          children: [
            Icon(Icons.logout, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Log Out',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Check if the current user has admin/support role.
  static bool _isAdminUser(BuildContext context) {
    try {
      final roleProvider = context.read<RoleProvider>();
      return roleProvider.currentRole.isSupport;
    } catch (e) {
      // RoleProvider not available, check roles array directly
      final userProfile = UserProfileService().userProfile;
      if (userProfile == null) return false;

      // Use case-insensitive helper method
      return AdminRoles.hasSupportRole(userProfile.roles);
    }
  }

  /// Show delete account confirmation dialog
  /// Returns true if user confirmed deletion
  static Future<bool?> showDeleteAccountConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Account',
          style: AppTypography.headingSmall.copyWith(color: AppColors.error),
        ),
        content: Text(
          'This will permanently delete your account and all your data. This action cannot be undone. Are you sure?',
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          AppButtonVariants.dialogCancel(
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.of(ctx).pop(true),
            label: 'Delete',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  /// Handle delete account: call UserRepository.deleteAccount and navigate to auth screen
  static Future<bool> handleDeleteAccount(BuildContext context) async {
    return ErrorHandler.handle<bool>(
      operation: () async {
        await sl<UserRepository>().deleteAccount();
        if (!context.mounted) return false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PhoneAuthPage()),
          (route) => false,
        );
        SnackbarService.show('Account deleted successfully');
        return true;
      },
      fallback: false,
      onError: (error) async {
        if (!context.mounted) return;

        // Check if this is a requires-recent-login error
        if (error.toString().contains('requires-recent-login')) {
          // Show re-authentication required dialog
          final shouldReauth = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                'Re-authentication Required',
                style: AppTypography.headingSmall.copyWith(
                  color: AppColors.error,
                ),
              ),
              content: Text(
                'For security reasons, you need to log out and log back in before deleting your account. This ensures your account is protected.',
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                AppButtonVariants.dialogCancel(
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                AppButtonVariants.dialogAction(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  label: 'Log Out & Re-login',
                  isDestructive: false,
                ),
              ],
            ),
          );

          if (shouldReauth == true && context.mounted) {
            // Log out the user so they can log back in
            await handleLogout(context);
          }
        } else {
          // Show generic error for other types of errors
          SnackbarService.show('Account deletion failed: $error');
        }
      },
    );
  }

  /// Show logout confirmation dialog
  /// Returns true if user confirmed logout
  static Future<bool?> showLogoutConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Log Out',
          style: AppTypography.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          AppButtonVariants.dialogCancel(
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.of(ctx).pop(true),
            label: 'Log Out',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  /// Handle logout: sign out from Firebase and clear global profile
  /// Navigate to phone auth screen
  /// Returns true if logout was successful
  static Future<bool> handleLogout(BuildContext context) async {
    return ErrorHandler.handle<bool>(
      operation: () async {
        // Sign out using AuthState which handles cleanup via AccountCleanupService
        final authState = context.read<AuthState>();
        await authState.signOut();

        // Navigate to phone auth screen
        if (!context.mounted) return false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PhoneAuthPage()),
          (route) => false,
        );

        return true;
      },
      fallback: false,
      onError: (error) {
        if (!context.mounted) return;
        SnackbarService.show('Logout failed: $error');
      },
    );
  }

  /// Toggle notifications on/off
  /// Updates Firestore and local profile
  static Future<void> toggleNotifications(BuildContext context) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final currentProfile = UserProfileService().userProfile;
        if (currentProfile == null) return;

        final currentValue = currentProfile.notificationsEnabled;
        final newValue = !currentValue;

        // Update in Firestore
        await sl<UserRepository>().toggleNotifications(newValue);

        // Update local profile
        final updatedProfile = currentProfile.copyWith(
          notificationsEnabled: newValue,
        );
        UserProfileService().updateUserProfile(updatedProfile);

        SnackbarService.show(
          newValue ? 'Notifications enabled' : 'Notifications disabled',
        );
      },
      onError: (error) {
        SnackbarService.show('Failed to update notification settings');
      },
    );
  }

  /// Process menu selection with logout confirmation
  static Future<void> handleMenuSelection(
    BuildContext context,
    String value, {
    required Function() onEditProfile,
  }) async {
    if (value == 'edit_profile') {
      onEditProfile();
    } else if (value == 'toggle_notifications') {
      await toggleNotifications(context);
    } else if (value == 'help_support') {
      if (!context.mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SupportHubPage()));
    } else if (value == 'admin_dashboard') {
      if (!context.mounted) return;
      // Import dynamically to avoid circular dependencies
      Navigator.of(context).pushNamed('/admin');
    } else if (value == 'logout') {
      if (!context.mounted) return;
      final confirmed = await showLogoutConfirmation(context);
      if (confirmed == true && context.mounted) {
        await handleLogout(context);
      }
    } else if (value == 'delete_account') {
      if (!context.mounted) return;
      final confirmed = await showDeleteAccountConfirmation(context);
      if (confirmed == true && context.mounted) {
        await handleDeleteAccount(context);
      }
    }
  }
}
