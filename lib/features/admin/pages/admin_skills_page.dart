import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/features/admin/presentation/state/admin_state.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_skills_view_model.dart';
import 'package:securityexperts_app/features/admin/services/admin_skills_service.dart';
import 'package:securityexperts_app/features/admin/pages/admin_skill_editor_page.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_section_wrapper.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_compact_stat_card.dart';
import 'package:securityexperts_app/shared/animations/page_transitions.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';

/// Admin page for managing skills that experts can have.
class AdminSkillsPage extends StatelessWidget {
  const AdminSkillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminRouteGuard(
      minimumRole: UserRole.admin,
      child: ChangeNotifierProvider(
        create: (_) => AdminSkillsViewModel()..initialize(),
        child: const _AdminSkillsView(),
      ),
    );
  }
}

class _AdminSkillsView extends StatefulWidget {
  const _AdminSkillsView();

  @override
  State<_AdminSkillsView> createState() => _AdminSkillsViewState();
}

class _AdminSkillsViewState extends State<_AdminSkillsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(
    AdminSkillsViewModel viewModel,
    AdminSkill skill,
  ) async {
    final success = await viewModel.toggleActive(skill.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skill ${skill.isActive ? 'deactivated' : 'activated'}',
          ),
        ),
      );
    }
  }

  Future<void> _deleteSkill(
    AdminSkillsViewModel viewModel,
    AdminSkill skill,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Skill'),
        content: Text('Are you sure you want to delete "${skill.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          AppButtonVariants.dialogDestructive(
            onPressed: () => Navigator.pop(context, true),
            label: 'Delete',
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await viewModel.deleteSkill(skill.id);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Skill deleted')));
      }
    }
  }

  void _navigateToEditor([String? skillId]) {
    Navigator.of(context).push(
      PageTransitions.slideFromRight(
        page: AdminSkillEditorPage(skillId: skillId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminSkillsViewModel>();
    final state = viewModel.state;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Skills Management',
          style: AppTypography.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () => viewModel.initialize(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Skills'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats row
          if (!state.isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AdminCompactStatCard(
                    label: 'Total',
                    value: state.stats['totalSkills']?.toString() ?? '0',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  AdminCompactStatCard(
                    label: 'Active',
                    value: state.stats['activeSkills']?.toString() ?? '0',
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 12),
                  AdminCompactStatCard(
                    label: 'Categories',
                    value: state.stats['totalCategories']?.toString() ?? '0',
                    color: AppColors.primaryLight,
                  ),
                ],
              ),
            ),

          // Error display
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => viewModel.initialize(),
                      color: AppColors.error,
                    ),
                  ],
                ),
              ),
            ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSkillsTab(viewModel, state),
                _buildCategoriesTab(state),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              heroTag: 'admin_skills_page_fab',
              backgroundColor: AppColors.primary,
              onPressed: _navigateToEditor,
              child: const Icon(Icons.add, color: AppColors.white),
            )
          : null,
    );
  }

  Widget _buildSkillsTab(
    AdminSkillsViewModel viewModel,
    AdminSkillsState state,
  ) {
    return Column(
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search skills...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (value) {
                  viewModel.setSearchQuery(value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: state.filters.categoryFilter ?? '',
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All Categories'),
                        ),
                        ...state.categories.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        viewModel.setCategoryFilter(
                          value?.isEmpty == true ? null : value,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Active'),
                    selected: state.filters.activeFilter == true,
                    onSelected: (value) {
                      viewModel.setActiveFilter(value ? true : null);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Skills List
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.filteredSkills.isEmpty
              ? Center(
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
                      AppButtonVariants.secondary(
                        onPressed: () => _navigateToEditor(),
                        label: 'Add Skill',
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.filteredSkills.length,
                  itemBuilder: (context, index) {
                    final skill = state.filteredSkills[index];
                    final category = state.categories.firstWhere(
                      (c) => c.name == skill.category,
                      orElse: () => SkillCategory(
                        id: '',
                        name: skill.category,
                        order: 0,
                        createdAt: DateTime.now(),
                      ),
                    );

                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: skill.isActive
                              ? AppColors.primaryLight.withValues(alpha: 0.1)
                              : AppColors.surface,
                          child: Text(
                            category.icon ?? '🛠️',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          skill.name,
                          style: AppTypography.bodyRegular.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Column(
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    category.name,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.trending_up,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${skill.usageCount} uses',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!skill.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warmAccent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Inactive',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.warmAccent,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _navigateToEditor(skill.id);
                                    break;
                                  case 'toggle':
                                    _toggleActive(viewModel, skill);
                                    break;
                                  case 'delete':
                                    _deleteSkill(viewModel, skill);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: const Row(
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
                                      Icon(
                                        skill.isActive
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        skill.isActive
                                            ? 'Deactivate'
                                            : 'Activate',
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.delete,
                                        color: AppColors.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: const TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _navigateToEditor(skill.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(AdminSkillsState state) {
    return state.isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Categories are automatically created from skills. Add skills with new categories to create them.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.categories.isEmpty
                    ? Center(
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
                            Text(
                              'Create skills to generate categories',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.categories.length,
                        itemBuilder: (context, index) {
                          final category = state.categories[index];
                          final skillCount = state.skills
                              .where((s) => s.category == category.name)
                              .length;

                          return Card(
                            color: AppColors.surface,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.1,
                                ),
                                child: Text(
                                  category.icon ?? '🛠️',
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
                                '$skillCount ${skillCount == 1 ? 'skill' : 'skills'}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Auto-generated',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.primaryLight,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
  }
}


