import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:securityexperts_app/features/admin/services/admin_user_service.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_role_badge.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

/// List item widget for displaying a user in admin views.
class UserListItem extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;

  const UserListItem({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _UserAvatar(user: user),
        title: Text(
          user.name.isNotEmpty ? user.name : 'No name',
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email ?? 'No email',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: user.roles
                  .take(3)
                  .map((role) => AdminRoleBadge(role: role, small: true))
                  .toList(),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onTap,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final AdminUser user;

  const _UserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        user.profilePictureUrl != null
            ? CachedNetworkImage(
                imageUrl: user.profilePictureUrl!,
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: imageProvider,
                ),
                placeholder: (context, url) => CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    (user.name.isNotEmpty ? user.name : user.email ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              )
            : CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  (user.name.isNotEmpty ? user.name : user.email ?? 'U')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
        if (user.isSuspended)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Detail row widget for user details sheet.
class UserDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const UserDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

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

/// Filter chip for user type stats.
class UserTypeFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;

  const UserTypeFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? color : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.captionEmphasis.copyWith(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: AppTypography.captionTiny.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget for user list.
class UserEmptyState extends StatelessWidget {
  const UserEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
