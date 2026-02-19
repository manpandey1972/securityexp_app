import 'package:flutter/foundation.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/admin/presentation/state/admin_state.dart';
import 'package:greenhive_app/features/admin/services/admin_skills_service.dart';

/// ViewModel for the admin skills list page.
class AdminSkillsViewModel extends ChangeNotifier {
  final AdminSkillsService _skillsService;
  final AppLogger _log;

  static const String _tag = 'AdminSkillsViewModel';

  AdminSkillsState _state = const AdminSkillsState();
  AdminSkillsState get state => _state;

  AdminSkillsViewModel({AdminSkillsService? skillsService, AppLogger? logger})
      : _skillsService = skillsService ?? sl<AdminSkillsService>(),
        _log = logger ?? sl<AppLogger>();

  /// Initialize and load skills.
  Future<void> initialize() async {
    await Future.wait([
      loadSkills(),
      loadCategories(),
      loadStats(),
    ]);
  }

  /// Load skills with current filters.
  Future<void> loadSkills() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final skills = await _skillsService.getSkills(
        category: _state.filters.categoryFilter,
        isActive: _state.filters.activeFilter,
        searchQuery: _state.filters.searchQuery.isNotEmpty
            ? _state.filters.searchQuery
            : null,
      );

      _state = _state.copyWith(
        isLoading: false,
        skills: skills,
      );
    } catch (e) {
      _log.error('Error loading skills: $e', tag: _tag);
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to load skills',
      );
    }

    notifyListeners();
  }

  /// Load skill categories.
  Future<void> loadCategories() async {
    try {
      final categories = await _skillsService.getCategories();
      _state = _state.copyWith(categories: categories);
      notifyListeners();
    } catch (e) {
      _log.error('Error loading categories: $e', tag: _tag);
    }
  }

  /// Load skill statistics.
  Future<void> loadStats() async {
    try {
      final stats = await _skillsService.getStats();
      _state = _state.copyWith(stats: stats);
      notifyListeners();
    } catch (e) {
      _log.error('Error loading stats: $e', tag: _tag);
    }
  }

  /// Update filters and reload.
  void updateFilters(AdminSkillFilters filters) {
    _state = _state.copyWith(filters: filters);
    notifyListeners();
    loadSkills();
  }

  /// Set category filter.
  void setCategoryFilter(String? category) {
    updateFilters(
      _state.filters
          .copyWith(categoryFilter: category, clearCategory: category == null),
    );
  }

  /// Set active filter.
  void setActiveFilter(bool? active) {
    updateFilters(
      _state.filters.copyWith(activeFilter: active, clearActive: active == null),
    );
  }

  /// Set search query.
  void setSearchQuery(String query) {
    _state = _state.copyWith(
      filters: _state.filters.copyWith(searchQuery: query),
    );
    notifyListeners();
    loadSkills();
  }

  /// Clear all filters.
  void clearFilters() {
    updateFilters(const AdminSkillFilters());
  }

  /// Toggle skill active status.
  Future<bool> toggleActive(String skillId) async {
    try {
      final success = await _skillsService.toggleActive(skillId);
      if (success) {
        await loadSkills();
        await loadStats();
      }
      return success;
    } catch (e) {
      _log.error('Error toggling skill active: $e', tag: _tag);
      return false;
    }
  }

  /// Delete a skill.
  Future<bool> deleteSkill(String skillId) async {
    try {
      final success = await _skillsService.deleteSkill(skillId);
      if (success) {
        await loadSkills();
        await loadStats();
        await loadCategories();
      }
      return success;
    } catch (e) {
      _log.error('Error deleting skill: $e', tag: _tag);
      return false;
    }
  }

  /// Create a new skill.
  Future<String?> createSkill({
    required String name,
    required String category,
    String? description,
    List<String> tags = const [],
    bool isActive = true,
  }) async {
    try {
      final skillId = await _skillsService.createSkill(
        name: name,
        category: category,
        description: description,
        tags: tags,
        isActive: isActive,
      );
      if (skillId != null) {
        await loadSkills();
        await loadStats();
        await loadCategories();
      }
      return skillId;
    } catch (e) {
      _log.error('Error creating skill: $e', tag: _tag);
      return null;
    }
  }

  /// Update a skill.
  Future<bool> updateSkill(
    String skillId, {
    String? name,
    String? category,
    String? description,
    List<String>? tags,
    bool? isActive,
  }) async {
    try {
      final success = await _skillsService.updateSkill(
        skillId,
        name: name,
        category: category,
        description: description,
        tags: tags,
        isActive: isActive,
      );
      if (success) {
        await loadSkills();
        await loadStats();
        await loadCategories();
      }
      return success;
    } catch (e) {
      _log.error('Error updating skill: $e', tag: _tag);
      return false;
    }
  }

  /// Get a single skill by ID.
  Future<AdminSkill?> getSkill(String skillId) async {
    try {
      return await _skillsService.getSkill(skillId);
    } catch (e) {
      _log.error('Error getting skill: $e', tag: _tag);
      return null;
    }
  }

  /// Get unique categories.
  Future<List<String>> getUniqueCategories() async {
    try {
      return await _skillsService.getUniqueCategories();
    } catch (e) {
      _log.error('Error getting unique categories: $e', tag: _tag);
      return [];
    }
  }
}
