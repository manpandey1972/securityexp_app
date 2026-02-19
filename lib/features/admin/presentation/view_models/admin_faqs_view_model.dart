import 'package:flutter/foundation.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/admin/data/models/faq.dart';
import 'package:securityexperts_app/features/admin/presentation/state/admin_state.dart';
import 'package:securityexperts_app/features/admin/services/admin_faq_service.dart';

/// ViewModel for the admin FAQs list page.
class AdminFaqsViewModel extends ChangeNotifier {
  final AdminFaqService _faqService;
  final AppLogger _log;

  static const String _tag = 'AdminFaqsViewModel';

  AdminFaqsState _state = const AdminFaqsState();
  AdminFaqsState get state => _state;

  AdminFaqsViewModel({AdminFaqService? faqService, AppLogger? logger})
    : _faqService = faqService ?? sl<AdminFaqService>(),
      _log = logger ?? sl<AppLogger>();

  /// Initialize and load FAQs.
  Future<void> initialize() async {
    await Future.wait([loadFaqs(), loadCategories(), loadStats()]);
  }

  /// Load FAQs with current filters.
  Future<void> loadFaqs() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final faqs = await _faqService.getFaqs(
        categoryId: _state.filters.categoryFilter,
        isPublished: _state.filters.publishedFilter,
        searchQuery: _state.filters.searchQuery.isNotEmpty
            ? _state.filters.searchQuery
            : null,
      );

      _state = _state.copyWith(isLoading: false, faqs: faqs);
    } catch (e) {
      _log.error('Error loading FAQs: $e', tag: _tag);
      _state = _state.copyWith(isLoading: false, error: 'Failed to load FAQs');
    }

    notifyListeners();
  }

  /// Load FAQ categories.
  Future<void> loadCategories() async {
    try {
      final categories = await _faqService.getCategories();
      _state = _state.copyWith(categories: categories);
      notifyListeners();
    } catch (e) {
      _log.error('Error loading categories: $e', tag: _tag);
    }
  }

  /// Load FAQ statistics.
  Future<void> loadStats() async {
    try {
      final stats = await _faqService.getStats();
      _state = _state.copyWith(stats: stats);
      notifyListeners();
    } catch (e) {
      _log.error('Error loading stats: $e', tag: _tag);
    }
  }

  /// Update filters and reload.
  void updateFilters(AdminFaqFilters filters) {
    _state = _state.copyWith(filters: filters);
    notifyListeners();
    loadFaqs();
  }

  /// Set category filter.
  void setCategoryFilter(String? category) {
    updateFilters(
      _state.filters.copyWith(
        categoryFilter: category,
        clearCategory: category == null,
      ),
    );
  }

  /// Set published filter.
  void setPublishedFilter(bool? published) {
    updateFilters(
      _state.filters.copyWith(
        publishedFilter: published,
        clearPublished: published == null,
      ),
    );
  }

  /// Set search query.
  void setSearchQuery(String query) {
    _state = _state.copyWith(
      filters: _state.filters.copyWith(searchQuery: query),
    );
    notifyListeners();
    loadFaqs();
  }

  /// Clear all filters.
  void clearFilters() {
    updateFilters(const AdminFaqFilters());
  }

  /// Toggle FAQ published status.
  Future<bool> togglePublished(String faqId) async {
    try {
      final success = await _faqService.togglePublished(faqId);
      if (success) {
        await loadFaqs();
        await loadStats();
      }
      return success;
    } catch (e) {
      _log.error('Error toggling FAQ published: $e', tag: _tag);
      return false;
    }
  }

  /// Delete a FAQ.
  Future<bool> deleteFaq(String faqId) async {
    try {
      final success = await _faqService.deleteFaq(faqId);
      if (success) {
        await loadFaqs();
        await loadStats();
      }
      return success;
    } catch (e) {
      _log.error('Error deleting FAQ: $e', tag: _tag);
      return false;
    }
  }

  /// Create a new FAQ.
  Future<String?> createFaq({
    required String question,
    required String answer,
    required String categoryId,
    List<String> tags = const [],
    bool isPublished = false,
    int order = 0,
  }) async {
    try {
      final faqId = await _faqService.createFaq(
        question: question,
        answer: answer,
        categoryId: categoryId,
        tags: tags,
        isPublished: isPublished,
        order: order,
      );
      if (faqId != null) {
        await loadFaqs();
        await loadStats();
      }
      return faqId;
    } catch (e) {
      _log.error('Error creating FAQ: $e', tag: _tag);
      return null;
    }
  }

  /// Update a FAQ.
  Future<bool> updateFaq(
    String faqId, {
    String? question,
    String? answer,
    String? categoryId,
    List<String>? tags,
    bool? isPublished,
    int? order,
  }) async {
    try {
      final success = await _faqService.updateFaq(
        faqId,
        question: question,
        answer: answer,
        categoryId: categoryId,
        tags: tags,
        isPublished: isPublished,
        order: order,
      );
      if (success) {
        await loadFaqs();
        await loadStats();
      }
      return success;
    } catch (e) {
      _log.error('Error updating FAQ: $e', tag: _tag);
      return false;
    }
  }

  /// Get a single FAQ by ID.
  Future<Faq?> getFaq(String faqId) async {
    try {
      return await _faqService.getFaq(faqId);
    } catch (e) {
      _log.error('Error getting FAQ: $e', tag: _tag);
      return null;
    }
  }

  // ============= Category Management =============

  /// Create a new FAQ category.
  Future<String?> createCategory({
    required String name,
    String? description,
    String? icon,
    int order = 0,
    bool isActive = true,
  }) async {
    try {
      final categoryId = await _faqService.createCategory(
        name: name,
        description: description,
        icon: icon,
        order: order,
        isActive: isActive,
      );
      if (categoryId != null) {
        await loadCategories();
        await loadStats();
      }
      return categoryId;
    } catch (e) {
      _log.error('Error creating category: $e', tag: _tag);
      return null;
    }
  }

  /// Update a FAQ category.
  Future<bool> updateCategory(
    String categoryId, {
    String? name,
    String? description,
    String? icon,
    int? order,
    bool? isActive,
  }) async {
    try {
      final success = await _faqService.updateCategory(
        categoryId,
        name: name,
        description: description,
        icon: icon,
        order: order,
        isActive: isActive,
      );
      if (success) {
        await loadCategories();
      }
      return success;
    } catch (e) {
      _log.error('Error updating category: $e', tag: _tag);
      return false;
    }
  }

  /// Delete a FAQ category.
  Future<bool> deleteCategory(String categoryId) async {
    // Check if category has FAQs
    final faqsInCategory = _state.faqs.where((f) => f.categoryId == categoryId);
    if (faqsInCategory.isNotEmpty) {
      _log.warning(
        'Cannot delete category with ${faqsInCategory.length} FAQs',
        tag: _tag,
      );
      return false;
    }

    try {
      final success = await _faqService.deleteCategory(categoryId);
      if (success) {
        await loadCategories();
        await loadStats();
      }
      return success;
    } catch (e) {
      _log.error('Error deleting category: $e', tag: _tag);
      return false;
    }
  }

  /// Reorder categories.
  Future<bool> reorderCategories(int oldIndex, int newIndex) async {
    try {
      // Create a mutable copy of categories
      final categories = List<FaqCategory>.from(_state.categories);
      final category = categories.removeAt(oldIndex);
      categories.insert(newIndex, category);

      // Update local state immediately for responsive UI
      _state = _state.copyWith(categories: categories);
      notifyListeners();

      // Update order in Firestore
      for (var i = 0; i < categories.length; i++) {
        await _faqService.updateCategory(categories[i].id, order: i);
      }

      return true;
    } catch (e) {
      _log.error('Error reordering categories: $e', tag: _tag);
      // Reload categories to restore original order
      await loadCategories();
      return false;
    }
  }

  /// Reorder FAQs.
  Future<bool> reorderFaqs(List<String> faqIds) async {
    try {
      final success = await _faqService.reorderFaqs(faqIds);
      if (success) {
        await loadFaqs();
      }
      return success;
    } catch (e) {
      _log.error('Error reordering FAQs: $e', tag: _tag);
      return false;
    }
  }
}
