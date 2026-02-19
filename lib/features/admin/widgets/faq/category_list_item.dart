import 'package:flutter/material.dart';
import 'package:securityexperts_app/features/admin/data/models/faq.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

/// List item widget for displaying a FAQ category in admin views.
class CategoryListItem extends StatelessWidget {
  final FaqCategory category;
  final int faqCount;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const CategoryListItem({
    super.key,
    required this.category,
    required this.faqCount,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey(category.id),
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          child: Text(
            category.icon ?? '📋',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          category.name,
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${category.description ?? 'No description'} • $faqCount FAQs',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!category.isActive) _InactiveBadge(),
            _CategoryPopupMenu(
              category: category,
              onEdit: onEdit,
              onToggleActive: onToggleActive,
              onDelete: onDelete,
            ),
            const Icon(
              Icons.drag_handle,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warmAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Inactive',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.warmAccent,
        ),
      ),
    );
  }
}

class _CategoryPopupMenu extends StatelessWidget {
  final FaqCategory category;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _CategoryPopupMenu({
    required this.category,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
            break;
          case 'toggle':
            onToggleActive();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(category.isActive ? Icons.visibility_off : Icons.visibility),
              const SizedBox(width: 8),
              Text(category.isActive ? 'Deactivate' : 'Activate'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Empty state widget for category list.
class CategoryEmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const CategoryEmptyState({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.category_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No categories yet',
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onCreate,
            child: const Text('Create Category'),
          ),
        ],
      ),
    );
  }
}
