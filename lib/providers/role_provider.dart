import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:securityexperts_app/core/auth/role_service.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Provider for managing and exposing user role state.
///
/// This provider:
/// - Streams role changes from Firestore in real-time
/// - Caches the current role for synchronous access
/// - Provides convenient getters for role-based UI decisions
/// - Automatically re-subscribes to role stream when user authenticates
///
/// Usage:
/// ```dart
/// // In widget tree with Provider
/// Consumer<RoleProvider>(
///   builder: (context, roleProvider, child) {
///     if (roleProvider.isAdmin) {
///       return AdminDashboard();
///     }
///     return UserDashboard();
///   },
/// )
///
/// // Or with Provider.of
/// final isAdmin = context.watch<RoleProvider>().isAdmin;
/// ```
class RoleProvider extends ChangeNotifier {
  final RoleService _roleService;
  final AppLogger _log;
  final fb.FirebaseAuth _auth;

  static const String _tag = 'RoleProvider';

  UserRole _currentRole = UserRole.user;
  bool _isInitialized = false;
  StreamSubscription<UserRole>? _roleSubscription;
  StreamSubscription<fb.User?>? _authSubscription;

  /// Create a RoleProvider with the given RoleService.
  RoleProvider(
    this._roleService, {
    AppLogger? logger,
    fb.FirebaseAuth? auth,
  }) : _log = logger ?? sl<AppLogger>(),
       _auth = auth ?? fb.FirebaseAuth.instance {
    _init();
  }

  /// Initialize the provider and start listening to auth and role changes.
  void _init() {
    _log.debug('Initializing RoleProvider', tag: _tag);

    // Listen to auth state changes to re-subscribe to role stream when user logs in
    _authSubscription = _auth.authStateChanges().listen(
      (user) {
        _log.debug(
          'Auth state changed: ${user == null ? "logged out" : "logged in (${user.uid})"}',
          tag: _tag,
        );
        // Re-subscribe to role stream when auth state changes
        // This ensures we get the correct role for the newly authenticated user
        _resubscribeToRoleStream();
      },
    );

    // Initial subscription to role stream
    _subscribeToRoleStream();
  }

  /// Subscribe to the role stream.
  void _subscribeToRoleStream() {
    _log.debug('Subscribing to role stream', tag: _tag);

    _roleSubscription = _roleService.roleStream.listen(
      (role) {
        _currentRole = role;
        _isInitialized = true;
        notifyListeners();
      },
      onError: (error) {
        _log.error('Error in role stream', error: error, tag: _tag);
        _currentRole = UserRole.user;
        _isInitialized = true;
        notifyListeners();
      },
    );
  }

  /// Re-subscribe to the role stream.
  ///
  /// This is called when auth state changes to ensure we're listening
  /// to the correct role stream for the currently authenticated user.
  void _resubscribeToRoleStream() {
    _log.debug('Re-subscribing to role stream', tag: _tag);
    
    // Cancel existing subscription
    _roleSubscription?.cancel();
    
    // Reset initialization flag to show loading state briefly
    _isInitialized = false;
    notifyListeners();
    
    // Subscribe to new role stream
    _subscribeToRoleStream();
  }

  /// The current user's role.
  UserRole get currentRole => _currentRole;

  /// Whether the provider has been initialized with a role value.
  bool get isInitialized => _isInitialized;

  /// Whether the current user has admin privileges.
  bool get isAdmin => _currentRole.isAdmin;

  /// Whether the current user has support privileges.
  bool get isSupport => _currentRole.isSupport;

  /// Whether the current user is a super admin.
  bool get isSuperAdmin => _currentRole == UserRole.superAdmin;

  /// Whether the current user can manage content (FAQs, skills).
  bool get canManageContent => _currentRole.canManageContent;

  /// Whether the current user can manage users.
  bool get canManageUsers => _currentRole.canManageUsers;

  /// Whether the current user can manage other admins.
  bool get canManageAdmins => _currentRole.canManageAdmins;

  /// Whether the current user can view analytics.
  bool get canViewAnalytics => _currentRole.canViewAnalytics;

  /// Check if user has at least the specified role level.
  bool hasAtLeastRole(UserRole minimumRole) {
    return _currentRole.hasAtLeast(minimumRole);
  }

  /// Refresh the role from Firestore.
  ///
  /// Useful after role changes or when you need to ensure the latest role.
  Future<void> refresh() async {
    _log.debug('Refreshing role', tag: _tag);
    final role = await _roleService.getCurrentRole();
    if (role != _currentRole) {
      _currentRole = role;
      notifyListeners();
    }
  }

  /// Check if user has a specific permission.
  ///
  /// This is an async operation that checks both role-based
  /// and custom permissions from Firestore.
  Future<bool> hasPermission(AdminPermission permission) async {
    return _roleService.hasPermission(permission);
  }

  @override
  void dispose() {
    _log.debug('Disposing RoleProvider', tag: _tag);
    _roleSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
