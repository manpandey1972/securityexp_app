import 'package:flutter/material.dart';
import 'package:greenhive_app/features/admin/data/models/faq.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

/// List item widget for displaying an FAQ in admin views.
class FaqListItem extends StatelessWidget {
  final Faq faq;
  final FaqCategory category;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublished;
  final VoidCallback onDelete;

  const FaqListItem({
    super.key,
    required this.faq,
    required this.category,
    required this.onTap,
    required this.onEdit,
    required this.onTogglePublished,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: faq.isPublished
              ? AppColors.primaryLight.withValues(alpha: 0.1)
              : AppColors.warmAccent.withValues(alpha: 0.1),
          child: Icon(
            faq.isPublished ? Icons.check_circle : Icons.edit_note,
            color: faq.isPublished ? AppColors.primaryLight : AppColors.warmAccent,
          ),
        ),
        title: Text(
          faq.question,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: _FaqStats(faq: faq, categoryName: category.name),
        trailing: _FaqPopupMenu(
          faq: faq,
          onEdit: onEdit,
          onTogglePublished: onTogglePublished,
          onDelete: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _FaqStats extends StatelessWidget {
  final Faq faq;
  final String categoryName;

  const _FaqStats({required this.faq, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          categoryName,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.visibility, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 2),
        Text(
          '${faq.viewCount}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.thumb_up, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 2),
        Text(
          '${faq.helpfulCount}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FaqPopupMenu extends StatelessWidget {
  final Faq faq;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublished;
  final VoidCallback onDelete;

  const _FaqPopupMenu({
    required this.faq,
    required this.onEdit,
    required this.onTogglePublished,
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
            onTogglePublished();
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
              Icon(faq.isPublished ? Icons.unpublished : Icons.publish),
              const SizedBox(width: 8),
              Text(faq.isPublished ? 'Unpublish' : 'Publish'),
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

/// Empty state widget for FAQ list.
class FaqEmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const FaqEmptyState({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.help_outline,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No FAQs found',
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onCreate,
            child: const Text('Create FAQ'),
          ),
        ],
      ),
    );
  }
}
