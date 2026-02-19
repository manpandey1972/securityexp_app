import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/features/admin/data/models/faq.dart';
import 'package:securityexperts_app/features/admin/presentation/state/admin_state.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_faqs_view_model.dart';
import 'package:securityexperts_app/features/admin/pages/admin_faq_editor_page.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_compact_stat_card.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_section_wrapper.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/shared/animations/page_transitions.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';

/// Admin page for managing FAQs.
class AdminFaqsPage extends StatelessWidget {
  const AdminFaqsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminRouteGuard(
      minimumRole: UserRole.support,
      child: ChangeNotifierProvider(
        create: (_) => AdminFaqsViewModel()..initialize(),
        child: const _AdminFaqsView(),
      ),
    );
  }
}

class _AdminFaqsView extends StatefulWidget {
  const _AdminFaqsView();

  @override
  State<_AdminFaqsView> createState() => _AdminFaqsViewState();
}

class _AdminFaqsViewState extends State<_AdminFaqsView>
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

  Future<void> _togglePublished(AdminFaqsViewModel viewModel, Faq faq) async {
    final success = await viewModel.togglePublished(faq.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('FAQ ${faq.isPublished ? 'unpublished' : 'published'}'),
        ),
      );
    }
  }

  Future<void> _deleteFaq(AdminFaqsViewModel viewModel, Faq faq) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete FAQ'),
        content: Text('Are you sure you want to delete "${faq.question}"?'),
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
      final success = await viewModel.deleteFaq(faq.id);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('FAQ deleted')));
      }
    }
  }

  Future<void> _deleteCategory(
    AdminFaqsViewModel viewModel,
    AdminFaqsState state,
    FaqCategory category,
  ) async {
    // Check if category has FAQs
    final faqsInCategory = state.faqs.where((f) => f.categoryId == category.id);
    if (faqsInCategory.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot delete category with ${faqsInCategory.length} FAQs. Move or delete them first.',
            ),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
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
      final success = await viewModel.deleteCategory(category.id);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category deleted')));
      }
    }
  }

  void _showCategoryEditor(
    AdminFaqsViewModel viewModel, [
    FaqCategory? category,
  ]) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(
      text: category?.description ?? '',
    );
    final iconController = TextEditingController(text: category?.icon ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              category == null ? 'New Category' : 'Edit Category',
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(
                labelText: 'Icon (emoji)',
                border: OutlineInputBorder(),
                hintText: '📱',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    child: OutlinedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty) return;

                        Navigator.pop(context);

                        if (category == null) {
                          await viewModel.createCategory(
                            name: nameController.text,
                            description: descController.text,
                            icon: iconController.text.isEmpty
                                ? '📋'
                                : iconController.text,
                          );
                        } else {
                          await viewModel.updateCategory(
                            category.id,
                            name: nameController.text,
                            description: descController.text,
                            icon: iconController.text,
                          );
                        }
                      },
                      child: Text(category == null ? 'Create' : 'Save'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToEditor([String? faqId]) async {
    final result = await Navigator.of(context).push<bool>(
      PageTransitions.slideFromRight(page: AdminFaqEditorPage(faqId: faqId)),
    );

    // If FAQ was created/updated, refresh the list
    if (result == true && mounted) {
      final viewModel = context.read<AdminFaqsViewModel>();
      await viewModel.loadFaqs();
      await viewModel.loadCategories();
      await viewModel.loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminFaqsViewModel>();
    final state = viewModel.state;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'FAQ Management',
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
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'FAQs'),
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
                    value: state.stats['totalFaqs']?.toString() ?? '0',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  AdminCompactStatCard(
                    label: 'Published',
                    value: state.stats['publishedFaqs']?.toString() ?? '0',
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 12),
                  AdminCompactStatCard(
                    label: 'Draft',
                    value: state.stats['draftFaqs']?.toString() ?? '0',
                    color: AppColors.warmAccent,
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
                _buildFaqsTab(viewModel, state),
                _buildCategoriesTab(viewModel, state),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_faqs_page_fab',
        backgroundColor: AppColors.primary,
        onPressed: () {
          if (_tabController.index == 0) {
            _navigateToEditor();
          } else {
            _showCategoryEditor(viewModel);
          }
        },
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildFaqsTab(AdminFaqsViewModel viewModel, AdminFaqsState state) {
    return Column(
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search FAQs...',
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
                    label: const Text('Published'),
                    selected: state.filters.publishedFilter == true,
                    onSelected: (value) {
                      viewModel.setPublishedFilter(value ? true : null);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // FAQ List
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.filteredFaqs.isEmpty
              ? Center(
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
                      AppButtonVariants.secondary(
                        onPressed: () => _navigateToEditor(),
                        label: 'Create FAQ',
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.filteredFaqs.length,
                  itemBuilder: (context, index) {
                    final faq = state.filteredFaqs[index];
                    final category = state.categories.firstWhere(
                      (c) => c.id == faq.categoryId,
                      orElse: () => FaqCategory(
                        id: '',
                        name: 'Unknown',
                        order: 0,
                        createdAt: DateTime.now(),
                      ),
                    );

                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: faq.isPublished
                              ? AppColors.primaryLight.withValues(alpha: 0.1)
                              : AppColors.warmAccent.withValues(alpha: 0.1),
                          child: Icon(
                            faq.isPublished
                                ? Icons.check_circle
                                : Icons.edit_note,
                            color: faq.isPublished
                                ? AppColors.primaryLight
                                : AppColors.warmAccent,
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
                        subtitle: Row(
                          children: [
                            Text(
                              category.name,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.visibility,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${faq.viewCount}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.thumb_up,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${faq.helpfulCount}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _navigateToEditor(faq.id);
                                break;
                              case 'toggle':
                                _togglePublished(viewModel, faq);
                                break;
                              case 'delete':
                                _deleteFaq(viewModel, faq);
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
                                  Icon(
                                    faq.isPublished
                                        ? Icons.unpublished
                                        : Icons.publish,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    faq.isPublished ? 'Unpublish' : 'Publish',
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete, color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: const TextStyle(color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _navigateToEditor(faq.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(
    AdminFaqsViewModel viewModel,
    AdminFaqsState state,
  ) {
    return state.isLoading
        ? const Center(child: CircularProgressIndicator())
        : state.categories.isEmpty
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
                AppButtonVariants.secondary(
                  onPressed: () => _showCategoryEditor(viewModel),
                  label: 'Create Category',
                ),
              ],
            ),
          )
        : ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.categories.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              await viewModel.reorderCategories(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final category = state.categories[index];
              final faqCount = state.faqs
                  .where((f) => f.categoryId == category.id)
                  .length;

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
                      if (!category.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                        ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showCategoryEditor(viewModel, category);
                              break;
                            case 'toggle':
                              viewModel.updateCategory(
                                category.id,
                                isActive: !category.isActive,
                              );
                              break;
                            case 'delete':
                              _deleteCategory(viewModel, state, category);
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
                                Icon(
                                  category.isActive
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category.isActive ? 'Deactivate' : 'Activate',
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, color: AppColors.error),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.drag_handle,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
