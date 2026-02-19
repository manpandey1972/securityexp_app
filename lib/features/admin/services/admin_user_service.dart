import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:greenhive_app/core/auth/role_service.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/permissions/permission_types.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/admin/data/models/admin_user.dart';
import 'package:greenhive_app/features/admin/data/repositories/admin_user_repository.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';

export 'package:greenhive_app/features/admin/data/models/admin_user.dart';

/// Service for managing users in admin panel.
///
/// This service handles business logic and permission checks.
/// Data access is delegated to [AdminUserRepository].
class AdminUserService {
  final AdminUserRepository _repository;
  final FirebaseAuth _auth;
  final RoleService _roleService;
  final AppLogger _log;

  static const String _tag = 'AdminUserService';

  AdminUserService({
    AdminUserRepository? repository,
    FirebaseAuth? auth,
    RoleService? roleService,
    AppLogger? logger,
  }) : _repository = repository ?? FirestoreAdminUserRepository(),
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

  /// Get all users with optional filters.
  Future<List<AdminUser>> getUsers({
    String? searchQuery,
    String? roleFilter,
    bool? isSuspended,
    bool? isExpert,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    await _ensurePermission(AdminPermission.viewUsers);

    return ErrorHandler.handle<List<AdminUser>>(
      operation: () async {
        var users = await _repository.getUsers(
          roleFilter: roleFilter,
          isSuspended: isSuspended,
          limit: limit,
          startAfter: startAfter,
        );

        // Filter by expert status if specified
        if (isExpert != null) {
          users = users.where((u) => u.isExpert == isExpert).toList();
        }

        // Client-side filtering for 'Admin' filter to include SuperAdmin
        if (roleFilter == 'Admin') {
          users = users.where((u) => u.isAdmin).toList();
        }

        // Client-side search if query provided
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final lowerQuery = searchQuery.toLowerCase();
          users = users.where((user) {
            return user.name.toLowerCase().contains(lowerQuery) ||
                (user.email?.toLowerCase().contains(lowerQuery) ?? false) ||
                (user.phone?.contains(lowerQuery) ?? false);
          }).toList();
        }

        return users;
      },
      fallback: [],
      onError: (error) => _log.error('Error getting users: $error', tag: _tag),
    );
  }

  /// Search users by name or email.
  Future<List<AdminUser>> searchUsers(String query, {int limit = 20}) async {
    await _ensurePermission(AdminPermission.viewUsers);

    return ErrorHandler.handle<List<AdminUser>>(
      operation: () async {
        final lowerQuery = query.toLowerCase();
        final users = await _repository.searchUsers(query, limit: 100);

        return users
            .where((user) {
              return user.name.toLowerCase().contains(lowerQuery) ||
                  (user.email?.toLowerCase().contains(lowerQuery) ?? false);
            })
            .take(limit)
            .toList();
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error searching users: $error', tag: _tag),
    );
  }

  /// Get a single user by ID.
  Future<AdminUser?> getUser(String userId) async {
    return ErrorHandler.handle<AdminUser?>(
      operation: () => _repository.getUser(userId),
      fallback: null,
      onError: (error) => _log.error('Error getting user: $error', tag: _tag),
    );
  }

  /// Suspend a user.
  Future<bool> suspendUser(String userId, String reason) async {
    await _ensurePermission(AdminPermission.suspendUsers);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.updateSuspension(
          userId: userId,
          isSuspended: true,
          reason: reason,
          suspendedBy: _currentUserId,
        );
        _log.info('Suspended user: $userId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error suspending user: $error', tag: _tag),
    );
  }

  /// Unsuspend a user.
  Future<bool> unsuspendUser(String userId) async {
    await _ensurePermission(AdminPermission.suspendUsers);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.updateSuspension(userId: userId, isSuspended: false);
        _log.info('Unsuspended user: $userId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error unsuspending user: $error', tag: _tag),
    );
  }

  /// Update user roles.
  Future<bool> updateRoles(String userId, List<String> roles) async {
    await _ensurePermission(AdminPermission.manageAdmins);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.updateRoles(userId, roles);
        _log.info('Updated roles for user: $userId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error updating user roles: $error', tag: _tag),
    );
  }

  /// Add a role to user.
  Future<bool> addRole(String userId, String role) async {
    await _ensurePermission(AdminPermission.manageAdmins);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.addRole(userId, role);
        _log.info('Added role $role to user: $userId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error adding user role: $error', tag: _tag),
    );
  }

  /// Remove a role from user.
  Future<bool> removeRole(String userId, String role) async {
    await _ensurePermission(AdminPermission.manageAdmins);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.removeRole(userId, role);
        _log.info('Removed role $role from user: $userId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error removing user role: $error', tag: _tag),
    );
  }

  /// Get user statistics.
  Future<Map<String, int>> getStats() async {
    await _ensurePermission(AdminPermission.viewUsers);

    return ErrorHandler.handle<Map<String, int>>(
      operation: () async {
        final users = await _repository.getAllUsersForStats();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final thisWeek = today.subtract(const Duration(days: 7));
        final thisMonth = DateTime(now.year, now.month, 1);

        return {
          'totalUsers': users.length,
          'totalExperts': users.where((u) => u.isExpert).length,
          'totalSupport': users
              .where((u) => u.roles.contains('Support'))
              .length,
          'totalAdmins': users.where((u) => u.isAdmin).length,
          'totalSuperAdmin': users.where((u) => u.isSuperAdmin).length,
          'suspendedUsers': users.where((u) => u.isSuspended).length,
          'newToday': users.where((u) => u.createdAt.isAfter(today)).length,
          'newThisWeek': users
              .where((u) => u.createdAt.isAfter(thisWeek))
              .length,
          'newThisMonth': users
              .where((u) => u.createdAt.isAfter(thisMonth))
              .length,
          'activeToday': users
              .where((u) => u.lastLogin?.isAfter(today) ?? false)
              .length,
        };
      },
      fallback: {},
      onError: (error) =>
          _log.error('Error getting user stats: $error', tag: _tag),
    );
  }
}
