import 'package:flutter/material.dart';
import 'package:greenhive_app/features/admin/services/admin_skills_service.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

/// List item widget for displaying a skill in admin views.
class SkillListItem extends StatelessWidget {
  final AdminSkill skill;
  final SkillCategory category;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const SkillListItem({
    super.key,
    required this.skill,
    required this.category,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _SkillAvatar(skill: skill, category: category),
        title: Text(
          skill.name,
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: _SkillSubtitle(skill: skill, category: category),
        trailing: _SkillTrailing(
          skill: skill,
          onEdit: onEdit,
          onToggleActive: onToggleActive,
          onDelete: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SkillAvatar extends StatelessWidget {
  final AdminSkill skill;
  final SkillCategory category;

  const _SkillAvatar({required this.skill, required this.category});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: skill.isActive
          ? AppColors.primaryLight.withValues(alpha: 0.1)
          : AppColors.surface,
      child: Text(
        category.icon ?? '🛠️',
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}

class _SkillSubtitle extends StatelessWidget {
  final AdminSkill skill;
  final SkillCategory category;

  const _SkillSubtitle({required this.skill, required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          skill.description ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _CategoryBadge(categoryName: category.name),
            const SizedBox(width: 8),
            _UsageCountBadge(usageCount: skill.usageCount),
          ],
        ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String categoryName;

  const _CategoryBadge({required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        categoryName,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.primary,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _UsageCountBadge extends StatelessWidget {
  final int usageCount;

  const _UsageCountBadge({required this.usageCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.trending_up,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 2),
        Text(
          '$usageCount uses',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SkillTrailing extends StatelessWidget {
  final AdminSkill skill;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _SkillTrailing({
    required this.skill,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!skill.isActive) const _InactiveBadge(),
        _SkillPopupMenu(
          skill: skill,
          onEdit: onEdit,
          onToggleActive: onToggleActive,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warmAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Inactive',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.warmAccent,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _SkillPopupMenu extends StatelessWidget {
  final AdminSkill skill;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _SkillPopupMenu({
    required this.skill,
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
              Icon(skill.isActive ? Icons.visibility_off : Icons.visibility),
              const SizedBox(width: 8),
              Text(skill.isActive ? 'Deactivate' : 'Activate'),
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

/// Empty state widget for skills list.
class SkillEmptyState extends StatelessWidget {
  final VoidCallback onAddSkill;

  const SkillEmptyState({
    super.key,
    required this.onAddSkill,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.psychology_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No skills found',
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onAddSkill,
            child: const Text('Add Skill'),
          ),
        ],
      ),
    );
  }
}
