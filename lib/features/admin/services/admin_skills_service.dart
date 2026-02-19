import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/core/auth/role_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/admin/data/models/admin_skill.dart';
import 'package:securityexperts_app/features/admin/data/repositories/admin_skills_repository.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';

export 'package:securityexperts_app/features/admin/data/models/admin_skill.dart';

/// Service for managing skills in admin panel.
///
/// This service handles business logic and permission checks.
/// Data access is delegated to [AdminSkillsRepository].
class AdminSkillsService {
  final AdminSkillsRepository _repository;
  final FirebaseAuth _auth;
  final RoleService _roleService;
  final AppLogger _log;

  static const String _tag = 'AdminSkillsService';

  AdminSkillsService({
    AdminSkillsRepository? repository,
    FirebaseAuth? auth,
    RoleService? roleService,
    AppLogger? logger,
  })  : _repository = repository ?? FirestoreAdminSkillsRepository(),
        _auth = auth ?? FirebaseAuth.instance,
        _roleService = roleService ?? sl<RoleService>(),
        _log = logger ?? sl<AppLogger>();

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============= Permission Checks =============

  Future<void> _ensurePermission(AdminPermission permission) async {
    final hasPermission = await _roleService.hasPermission(permission);
    if (!hasPermission) {
      _log.warning('Permission denied: ${permission.name}', tag: _tag);
      throw Exception('Permission denied: ${permission.name}');
    }
  }

  // ============= Skill Categories =============

  /// Get all skill categories from skills collection.
  /// Since skill_categories collection doesn't exist, extract unique categories from skills.
  Future<List<SkillCategory>> getCategories() async {
    return ErrorHandler.handle<List<SkillCategory>>(
      operation: () async {
        final categories = await getUniqueCategories();
        return categories.asMap().entries.map((entry) {
          return SkillCategory(
            id: entry.value,
            name: entry.value,
            order: entry.key,
            createdAt: DateTime.now(),
          );
        }).toList();
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error getting skill categories: $error', tag: _tag),
    );
  }

  /// Get unique category names from skills collection.
  Future<List<String>> getUniqueCategories() async {
    return ErrorHandler.handle<List<String>>(
      operation: () => _repository.getUniqueCategories(),
      fallback: [],
      onError: (error) =>
          _log.error('Error getting unique categories: $error', tag: _tag),
    );
  }

  /// Create a new skill category - Not implemented (no skill_categories collection).
  /// Categories are created automatically when skills are added with new categories.
  @Deprecated('Use createSkill with a new category instead')
  Future<String?> createCategory({
    required String name,
    String? description,
    String? icon,
    int order = 0,
    bool isActive = true,
  }) async {
    _log.warning('createCategory called but skill_categories collection does not exist', tag: _tag);
    return null;
  }

  /// Update a skill category - Not implemented (no skill_categories collection).
  @Deprecated('Categories are derived from skills collection')
  Future<bool> updateCategory(
    String categoryId, {
    String? name,
    String? description,
    String? icon,
    int? order,
    bool? isActive,
  }) async {
    _log.warning('updateCategory called but skill_categories collection does not exist', tag: _tag);
    return false;
  }

  /// Delete a skill category - Not implemented (no skill_categories collection).
  @Deprecated('Categories are derived from skills collection')
  Future<bool> deleteCategory(String categoryId) async {
    _log.warning('deleteCategory called but skill_categories collection does not exist', tag: _tag);
    return false;
  }

  // ============= Skills =============

  /// Get all skills with optional filters.
  Future<List<AdminSkill>> getSkills({
    String? category,
    bool? isActive,
    String? searchQuery,
    int limit = 1000,
  }) async {
    await _ensurePermission(AdminPermission.manageSkills);

    return ErrorHandler.handle<List<AdminSkill>>(
      operation: () async {
        var skills = await _repository.getSkills(
          category: category,
          isActive: isActive,
          limit: limit,
        );

        // Client-side search if query provided
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final lowerQuery = searchQuery.toLowerCase();
          skills = skills.where((skill) {
            return skill.name.toLowerCase().contains(lowerQuery) ||
                skill.category.toLowerCase().contains(lowerQuery) ||
                skill.tags.any(
                    (tag) => tag.toLowerCase().contains(lowerQuery));
          }).toList();
        }

        return skills;
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error getting skills: $error', tag: _tag),
    );
  }

  /// Get a single skill by ID.
  Future<AdminSkill?> getSkill(String skillId) async {
    return ErrorHandler.handle<AdminSkill?>(
      operation: () => _repository.getSkill(skillId),
      fallback: null,
      onError: (error) =>
          _log.error('Error getting skill: $error', tag: _tag),
    );
  }

  /// Create a new skill.
  Future<String?> createSkill({
    required String name,
    required String category,
    String? description,
    List<String> tags = const [],
    bool isActive = true,
  }) async {
    await _ensurePermission(AdminPermission.manageSkills);

    return ErrorHandler.handle<String?>(
      operation: () async {
        final skillId = await _repository.createSkill(
          name: name,
          category: category,
          description: description,
          tags: tags,
          isActive: isActive,
          createdBy: _currentUserId,
        );
        _log.info('Created skill: $name', tag: _tag);
        return skillId;
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error creating skill: $error', tag: _tag),
    );
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
    await _ensurePermission(AdminPermission.manageSkills);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.updateSkill(
          skillId,
          name: name,
          category: category,
          description: description,
          tags: tags,
          isActive: isActive,
        );
        _log.info('Updated skill: $skillId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error updating skill: $error', tag: _tag),
    );
  }

  /// Delete a skill.
  Future<bool> deleteSkill(String skillId) async {
    await _ensurePermission(AdminPermission.manageSkills);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.deleteSkill(skillId);
        _log.info('Deleted skill: $skillId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error deleting skill: $error', tag: _tag),
    );
  }

  /// Toggle skill active status.
  Future<bool> toggleActive(String skillId) async {
    await _ensurePermission(AdminPermission.manageSkills);

    return ErrorHandler.handle<bool>(
      operation: () async {
        final newActive = await _repository.toggleActive(skillId);
        _log.info(
            'Skill $skillId ${newActive ? 'activated' : 'deactivated'}',
            tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error toggling skill active: $error', tag: _tag),
    );
  }

  /// Get skill statistics.
  Future<Map<String, int>> getStats() async {
    await _ensurePermission(AdminPermission.manageSkills);

    return ErrorHandler.handle<Map<String, int>>(
      operation: () async {
        final skills = await _repository.getAllSkillsForStats();
        final categories = await _repository.getUniqueCategories();

        return {
          'totalSkills': skills.length,
          'activeSkills': skills.where((s) => s.isActive).length,
          'inactiveSkills': skills.where((s) => !s.isActive).length,
          'totalCategories': categories.length,
          'totalUsage': skills.fold(0, (total, s) => total + s.usageCount),
        };
      },
      fallback: {},
      onError: (error) =>
          _log.error('Error getting skill stats: $error', tag: _tag),
    );
  }
}
