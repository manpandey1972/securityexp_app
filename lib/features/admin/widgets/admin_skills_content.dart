import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/features/admin/presentation/state/admin_state.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_skills_view_model.dart';
import 'package:securityexperts_app/features/admin/services/admin_skills_service.dart';
import 'package:securityexperts_app/features/admin/pages/admin_skill_editor_page.dart';
import 'package:securityexperts_app/features/admin/widgets/skill/skill_widgets.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_compact_stat_card.dart';
import 'package:securityexperts_app/shared/animations/page_transitions.dart';

/// Embeddable content widget for skills management.
/// Used in the admin dashboard's IndexedStack.
class AdminSkillsContent extends StatefulWidget {
  const AdminSkillsContent({super.key});

  @override
  State<AdminSkillsContent> createState() => _AdminSkillsContentState();
}

class _AdminSkillsContentState extends State<AdminSkillsContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
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

    return Stack(
      children: [
        Column(
          children: [
            // Tab bar
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: 'Skills'),
                  Tab(text: 'Categories'),
                ],
              ),
            ),

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
        // Floating action button
        if (_tabController.index == 0)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'admin_skills_content_fab',
              backgroundColor: AppColors.primary,
              onPressed: _navigateToEditor,
              child: const Icon(Icons.add, color: AppColors.white),
            ),
          ),
      ],
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
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('All Categories'),
                        ),
                        ...state.categories.map(
                          (c) => DropdownMenuItem<String>(
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
                      ElevatedButton(
                        onPressed: () => _navigateToEditor(),
                        child: const Text('Add Skill'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 80),
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

                    return SkillListItem(
                      skill: skill,
                      category: category,
                      onTap: () => _navigateToEditor(skill.id),
                      onEdit: () => _navigateToEditor(skill.id),
                      onToggleActive: () => _toggleActive(viewModel, skill),
                      onDelete: () => _deleteSkill(viewModel, skill),
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
              const CategoryInfoBanner(),
              Expanded(
                child: state.categories.isEmpty
                    ? const CategoryEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.categories.length,
                        itemBuilder: (context, index) {
                          final category = state.categories[index];
                          final skillCount = state.skills
                              .where((s) => s.category == category.name)
                              .length;

                          return SkillCategoryListItem(
                            category: category,
                            skillCount: skillCount,
                          );
                        },
                      ),
              ),
            ],
          );
  }
}
