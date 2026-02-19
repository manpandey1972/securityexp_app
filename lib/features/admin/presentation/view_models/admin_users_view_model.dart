import 'package:flutter/foundation.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/admin/presentation/state/admin_state.dart';
import 'package:securityexperts_app/features/admin/services/admin_user_service.dart';

/// ViewModel for the admin users list page.
class AdminUsersViewModel extends ChangeNotifier {
  final AdminUserService _userService;
  final AppLogger _log;

  static const String _tag = 'AdminUsersViewModel';

  bool _isDisposed = false;

  AdminUsersState _state = const AdminUsersState();
  AdminUsersState get state => _state;

  AdminUsersViewModel({AdminUserService? userService, AppLogger? logger})
      : _userService = userService ?? sl<AdminUserService>(),
        _log = logger ?? sl<AppLogger>();

  /// Safe notifyListeners that checks disposal state.
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Initialize and load users.
  Future<void> initialize() async {
    await Future.wait([
      loadUsers(),
      loadStats(),
    ]);
  }

  /// Load users with current filters.
  Future<void> loadUsers() async {
    if (_isDisposed) return;
    _state = _state.copyWith(isLoading: true, clearError: true);
    _safeNotifyListeners();

    try {
      final users = await _userService.getUsers(
        roleFilter: _state.filters.roleFilter,
        isSuspended: _state.filters.suspendedFilter,
      );

      if (_isDisposed) return;
      _state = _state.copyWith(
        isLoading: false,
        users: users,
      );
    } catch (e) {
      _log.error('Error loading users: $e', tag: _tag);
      if (_isDisposed) return;
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to load users',
      );
    }

    _safeNotifyListeners();
  }

  /// Load user statistics.
  Future<void> loadStats() async {
    if (_isDisposed) return;
    try {
      final stats = await _userService.getStats();
      if (_isDisposed) return;
      _state = _state.copyWith(stats: stats);
      _safeNotifyListeners();
    } catch (e) {
      _log.error('Error loading stats: $e', tag: _tag);
    }
  }

  /// Search users by query.
  Future<void> searchUsers(String query) async {
    if (_isDisposed) return;
    if (query.isEmpty) {
      await loadUsers();
      return;
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    _safeNotifyListeners();

    try {
      final users = await _userService.searchUsers(query);
      if (_isDisposed) return;
      _state = _state.copyWith(
        isLoading: false,
        users: users,
        filters: _state.filters.copyWith(searchQuery: query),
      );
    } catch (e) {
      _log.error('Error searching users: $e', tag: _tag);
      if (_isDisposed) return;
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to search users',
      );
    }

    _safeNotifyListeners();
  }

  /// Update filters and reload.
  void updateFilters(AdminUserFilters filters) {
    if (_isDisposed) return;
    _state = _state.copyWith(filters: filters);
    _safeNotifyListeners();
    loadUsers();
  }

  /// Set role filter.
  void setRoleFilter(String? role) {
    updateFilters(
      _state.filters.copyWith(roleFilter: role, clearRole: role == null),
    );
  }

  /// Set suspended filter.
  void setSuspendedFilter(bool? suspended) {
    updateFilters(
      _state.filters.copyWith(
        suspendedFilter: suspended,
        clearSuspended: suspended == null,
      ),
    );
  }

  /// Set search query (local filter).
  void setSearchQuery(String query) {
    if (_isDisposed) return;
    _state = _state.copyWith(
      filters: _state.filters.copyWith(searchQuery: query),
    );
    _safeNotifyListeners();
  }

  /// Clear all filters.
  void clearFilters() {
    updateFilters(const AdminUserFilters());
  }

  /// Suspend a user.
  Future<bool> suspendUser(String userId, String reason) async {
    if (_isDisposed) return false;
    try {
      final success = await _userService.suspendUser(userId, reason);
      if (success && !_isDisposed) {
        await loadUsers();
        await loadStats();
      }
      return success;
    } catch (e) {
      _log.error('Error suspending user: $e', tag: _tag);
      return false;
    }
  }

  /// Unsuspend a user.
  Future<bool> unsuspendUser(String userId) async {
    if (_isDisposed) return false;
    try {
      final success = await _userService.unsuspendUser(userId);
      if (success && !_isDisposed) {
        await loadUsers();
        await loadStats();
      }
      return success;
    } catch (e) {
      _log.error('Error unsuspending user: $e', tag: _tag);
      return false;
    }
  }

  /// Update user roles.
  Future<bool> updateRoles(String userId, List<String> roles) async {
    if (_isDisposed) return false;
    try {
      final success = await _userService.updateRoles(userId, roles);
      if (success && !_isDisposed) {
        await loadUsers();
        await loadStats();
      }
      return success;
    } catch (e) {
      _log.error('Error updating user roles: $e', tag: _tag);
      return false;
    }
  }

  /// Get a single user by ID.
  Future<AdminUser?> getUser(String userId) async {
    try {
      return await _userService.getUser(userId);
    } catch (e) {
      _log.error('Error getting user: $e', tag: _tag);
      return null;
    }
  }
}
