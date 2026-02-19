import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:greenhive_app/features/admin/services/admin_user_service.dart';
import 'package:greenhive_app/features/admin/widgets/admin_role_badge.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

/// Bottom sheet for displaying user details.
class UserDetailsSheet extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onEditRoles;
  final VoidCallback onToggleSuspension;
  final String Function(DateTime) formatDate;

  const UserDetailsSheet({
    super.key,
    required this.user,
    required this.onEditRoles,
    required this.onToggleSuspension,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // User header
            _UserHeader(user: user),
            const SizedBox(height: 24),

            // Status badges
            _StatusBadges(user: user),
            const SizedBox(height: 24),

            // Details section
            _DetailsSection(user: user, formatDate: formatDate),
            const SizedBox(height: 24),

            // Actions
            _ActionsSection(
              user: user,
              onEditRoles: onEditRoles,
              onToggleSuspension: onToggleSuspension,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final AdminUser user;

  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        user.profilePictureUrl != null
            ? CachedNetworkImage(
                imageUrl: user.profilePictureUrl!,
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: imageProvider,
                ),
                placeholder: (context, url) => CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    (user.name.isNotEmpty ? user.name : user.email ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            : CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  (user.name.isNotEmpty ? user.name : user.email ?? 'U')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name.isNotEmpty ? user.name : 'No name',
                style: AppTypography.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                user.email ?? 'No email',
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadges extends StatelessWidget {
  final AdminUser user;

  const _StatusBadges({required this.user});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...user.roles.map((role) => AdminRoleBadge(role: role)),
        if (user.isSuspended)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Suspended',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final AdminUser user;
  final String Function(DateTime) formatDate;

  const _DetailsSection({required this.user, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Details',
          style: AppTypography.bodyEmphasis.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _DetailRow(label: 'User ID', value: user.id),
        _DetailRow(label: 'Email', value: user.email ?? 'Not set'),
        _DetailRow(label: 'Phone', value: user.phone ?? 'Not set'),
        _DetailRow(label: 'Created', value: formatDate(user.createdAt)),
        _DetailRow(
          label: 'Last Login',
          value: user.lastLogin != null ? formatDate(user.lastLogin!) : 'Never',
        ),
        if (user.suspendedReason != null)
          _DetailRow(label: 'Suspension Reason', value: user.suspendedReason!),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onEditRoles;
  final VoidCallback onToggleSuspension;

  const _ActionsSection({
    required this.user,
    required this.onEditRoles,
    required this.onToggleSuspension,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: AppTypography.bodyEmphasis.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEditRoles,
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Edit Roles'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: user.isSuspended
                  ? OutlinedButton.icon(
                      onPressed: onToggleSuspension,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Unsuspend'),
                    )
                  : OutlinedButton.icon(
                      onPressed: onToggleSuspension,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      icon: const Icon(Icons.block),
                      label: const Text('Suspend'),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Show user details bottom sheet
Future<void> showUserDetailsSheet(
  BuildContext context, {
  required AdminUser user,
  required VoidCallback onEditRoles,
  required VoidCallback onToggleSuspension,
  required String Function(DateTime) formatDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => UserDetailsSheet(
      user: user,
      onEditRoles: onEditRoles,
      onToggleSuspension: onToggleSuspension,
      formatDate: formatDate,
    ),
  );
}
