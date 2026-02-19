import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:greenhive_app/features/admin/data/models/faq.dart';
import 'package:greenhive_app/features/admin/presentation/state/admin_state.dart';
import 'package:greenhive_app/features/admin/presentation/view_models/admin_faqs_view_model.dart';
import 'package:greenhive_app/features/admin/pages/admin_faq_editor_page.dart';
import 'package:greenhive_app/features/admin/widgets/admin_compact_stat_card.dart';
import 'package:greenhive_app/features/admin/widgets/faq/faq_widgets.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/animations/page_transitions.dart';

/// Embeddable content widget for FAQ management.
/// Used in the admin dashboard's IndexedStack.
class AdminFaqsContent extends StatefulWidget {
  const AdminFaqsContent({super.key});

  @override
  State<AdminFaqsContent> createState() => _AdminFaqsContentState();
}

class _AdminFaqsContentState extends State<AdminFaqsContent>
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
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
    showCategoryEditor(
      context,
      category: category,
      onSave: ({
        required String name,
        required String description,
        required String icon,
      }) async {
        if (category == null) {
          await viewModel.createCategory(
            name: name,
            description: description,
            icon: icon,
          );
        } else {
          await viewModel.updateCategory(
            category.id,
            name: name,
            description: description,
            icon: icon,
          );
        }
      },
    );
  }

  void _navigateToEditor([String? faqId]) {
    Navigator.of(context).push(
      PageTransitions.slideFromRight(page: AdminFaqEditorPage(faqId: faqId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminFaqsViewModel>();
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
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: 'FAQs'),
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
        // Floating action button
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'admin_faqs_content_fab',
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
        ),
      ],
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
                      ElevatedButton(
                        onPressed: () => _navigateToEditor(),
                        child: const Text('Create FAQ'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 80),
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

                    return FaqListItem(
                      faq: faq,
                      category: category,
                      onTap: () => _navigateToEditor(faq.id),
                      onEdit: () => _navigateToEditor(faq.id),
                      onTogglePublished: () => _togglePublished(viewModel, faq),
                      onDelete: () => _deleteFaq(viewModel, faq),
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
                ElevatedButton(
                  onPressed: () => _showCategoryEditor(viewModel),
                  child: const Text('Create Category'),
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

              return CategoryListItem(
                key: ValueKey(category.id),
                category: category,
                faqCount: faqCount,
                onEdit: () => _showCategoryEditor(viewModel, category),
                onToggleActive: () => viewModel.updateCategory(
                  category.id,
                  isActive: !category.isActive,
                ),
                onDelete: () => _deleteCategory(viewModel, state, category),
              );
            },
          );
  }
}
