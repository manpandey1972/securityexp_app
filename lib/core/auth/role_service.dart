import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';

/// Service for managing user roles and permissions.
///
/// This service uses the existing `roles` array in user documents.
/// Admin roles ('Support', 'Admin', 'SuperAdmin') are stored alongside
/// existing roles like 'Expert' and 'Merchant'.
///
/// Usage:
/// ```dart
/// final roleService = sl<RoleService>();
///
/// // Stream role changes
/// roleService.roleStream.listen((role) {
///   print('User role: ${role.displayName}');
/// });
///
/// // Check permission
/// final canManageFaqs = await roleService.hasPermission(AdminPermission.manageFaqs);
/// ```
class RoleService {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final AppLogger _log;

  static const String _tag = 'RoleService';

  // --- Cached role data (populated by roleStream subscription) ---
  UserRole _cachedRole = UserRole.user;
  List<String> _cachedRoles = [];
  List<String> _cachedCustomPermissions = [];
  bool _cacheReady = false;
  StreamSubscription<void>? _cacheSubscription;
  StreamSubscription<void>? _authSubscription;

  RoleService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    AppLogger? logger,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? fb.FirebaseAuth.instance,
       _log = logger ?? sl<AppLogger>() {
    _startAuthSubscription();
  }

  /// Listen to auth state changes and re-subscribe to the user doc on each login.
  void _startAuthSubscription() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      // Cancel existing doc subscription and reset cache on every auth change
      _cacheSubscription?.cancel();
      _cacheSubscription = null;
      _cacheReady = false;
      _cachedRole = UserRole.user;
      _cachedRoles = [];
      _cachedCustomPermissions = [];

      if (user != null) {
        _log.debug('Auth state changed: user=${user.uid}, re-subscribing cache', tag: _tag);
        _startCacheSubscription(user.uid);
      } else {
        _log.debug('Auth state changed: signed out, cache cleared', tag: _tag);
      }
    });
  }

  /// Start listening to a specific user's doc changes to keep cache warm.
  void _startCacheSubscription(String userId) {
    _cacheSubscription = _firestore
        .collection(FirestoreInstance.usersCollection)
        .doc(userId)
        .snapshots()
        .listen(
          (doc) {
            if (!doc.exists) {
              _cachedRole = UserRole.user;
              _cachedRoles = [];
              _cachedCustomPermissions = [];
            } else {
              final data = doc.data() ?? {};
              _cachedRoles = List<String>.from(data['roles'] ?? []);
              _cachedCustomPermissions = List<String>.from(
                data['adminPermissions'] ?? [],
              );
              _cachedRole = UserRole.fromRolesList(_cachedRoles);
            }
            _cacheReady = true;
            _log.debug(
              'Role cache updated: ${_cachedRole.displayName}',
              tag: _tag,
            );
          },
          onError: (error) {
            // permission-denied is expected during sign-out: the snapshot
            // stream may emit one final event after FirebaseAuth has cleared
            // the user. Treat that case as benign so we don't log scary
            // ERRORs on a normal logout.
            final msg = error.toString();
            final isExpectedSignOutError =
                _auth.currentUser == null &&
                msg.contains('permission-denied');
            if (isExpectedSignOutError) {
              _log.debug(
                'Role cache subscription closed during sign-out',
                tag: _tag,
              );
            } else {
              _log.error(
                'Error in role cache subscription',
                error: error,
                tag: _tag,
              );
            }
          },
        );
  }

  /// Dispose the cache subscription.
  ///
  /// Call this when the service is no longer needed (e.g. on logout).
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _cacheSubscription?.cancel();
    _cacheSubscription = null;
    _cacheReady = false;
    _cachedRole = UserRole.user;
    _cachedRoles = [];
    _cachedCustomPermissions = [];
  }

  /// Get the current authenticated user's ID.
  String? get currentUserId => _auth.currentUser?.uid;

  /// Stream the current user's role in real-time.
  ///
  /// Returns [UserRole.user] if not authenticated or no admin roles found.
  /// Only emits when the role actually changes (deduplicated).
  Stream<UserRole> get roleStream {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _log.debug('No authenticated user, returning UserRole.user', tag: _tag);
      return Stream.value(UserRole.user);
    }

    UserRole? lastRole;

    return _firestore
        .collection(FirestoreInstance.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return UserRole.user;
          }

          final data = doc.data();
          final roles = List<String>.from(data?['roles'] ?? []);
          final role = UserRole.fromRolesList(roles);
          return role;
        })
        .where((role) {
          // Deduplication: only emit when role actually changes
          if (role != lastRole) {
            _log.debug(
              'Role changed: ${lastRole?.displayName ?? "null"} -> ${role.displayName}',
              tag: _tag,
            );
            lastRole = role;
            return true;
          }
          return false;
        })
        .handleError((error) {
          _log.error('Error streaming role', error: error, tag: _tag);
          return UserRole.user;
        });
  }

  /// Get current user's roles list.
  ///
  /// Uses cached data when available, falls back to Firestore.
  Future<List<String>> getCurrentRolesList() async {
    if (_cacheReady) return List.unmodifiable(_cachedRoles);

    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final doc = await _firestore
          .collection(FirestoreInstance.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) return [];

      return List<String>.from(doc.data()?['roles'] ?? []);
    } catch (e) {
      _log.error('Error fetching roles list', error: e, tag: _tag);
      return [];
    }
  }

  /// Get current user's role (one-time fetch).
  ///
  /// Returns [UserRole.user] if not authenticated or no admin roles found.
  /// Uses cached data when available, falls back to Firestore.
  Future<UserRole> getCurrentRole() async {
    if (_cacheReady) return _cachedRole;

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _log.debug('No authenticated user', tag: _tag);
      return UserRole.user;
    }

    try {
      final doc = await _firestore
          .collection(FirestoreInstance.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) {
        _log.debug('User document does not exist', tag: _tag);
        return UserRole.user;
      }

      final roles = List<String>.from(doc.data()?['roles'] ?? []);
      final role = UserRole.fromRolesList(roles);
      _log.debug(
        'Current role: ${role.displayName} (roles: $roles)',
        tag: _tag,
      );
      return role;
    } catch (e) {
      _log.error('Error fetching role', error: e, tag: _tag);
      return UserRole.user;
    }
  }

  /// Check if current user has a specific permission.
  ///
  /// Permission can come from:
  /// 1. Default role permissions (based on user's roles array)
  /// 2. Custom permissions in user's `adminPermissions` array
  ///
  /// Super admins always have all permissions.
  /// Uses cached data when available, falls back to Firestore.
  Future<bool> hasPermission(AdminPermission permission) async {
    // Fast path: use cached data
    if (_cacheReady) {
      _log.debug(
        'hasPermission cache: role=${_cachedRole.displayName} permission=${permission.name}',
        tag: _tag,
      );
      return _hasPermissionFromCache(permission);
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _log.debug('No authenticated user, permission denied', tag: _tag);
      return false;
    }

    try {
      final doc = await _firestore
          .collection(FirestoreInstance.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) {
        _log.debug(
          'User document does not exist, permission denied',
          tag: _tag,
        );
        return false;
      }

      final data = doc.data()!;
      final roles = List<String>.from(data['roles'] ?? []);
      final role = UserRole.fromRolesList(roles);

      _log.debug(
        'hasPermission fallback: roles=$roles resolvedRole=${role.displayName} permission=${permission.name}',
        tag: _tag,
      );

      // Super admin has all permissions
      if (role == UserRole.superAdmin) {
        return true;
      }

      // Check default role permissions
      final rolePermissions = RolePermissions.getPermissionsForRole(role);
      if (rolePermissions.contains(permission)) {
        return true;
      }

      // Check custom permissions
      final customPermissions = List<String>.from(
        data['adminPermissions'] ?? [],
      );
      if (customPermissions.contains(permission.name)) {
        return true;
      }

      return false;
    } catch (e) {
      _log.error('Error checking permission', error: e, tag: _tag);
      return false;
    }
  }

  /// Check permission using cached data (no Firestore call).
  bool _hasPermissionFromCache(AdminPermission permission) {
    if (_cachedRole == UserRole.superAdmin) return true;

    final rolePermissions = RolePermissions.getPermissionsForRole(_cachedRole);
    if (rolePermissions.contains(permission)) return true;

    if (_cachedCustomPermissions.contains(permission.name)) return true;

    return false;
  }

  /// Check if current user has at least the specified role level.
  Future<bool> hasAtLeastRole(UserRole minimumRole) async {
    final currentRole = await getCurrentRole();
    return currentRole.hasAtLeast(minimumRole);
  }

  /// Check if current user is admin (admin or super_admin).
  Future<bool> isAdmin() async {
    final role = await getCurrentRole();
    return role.isAdmin;
  }

  /// Check if current user is support or higher.
  Future<bool> isSupport() async {
    final role = await getCurrentRole();
    return role.isSupport;
  }

  /// Get all permissions for the current user.
  ///
  /// Returns combined set of role-based and custom permissions.
  /// Uses cached data when available, falls back to Firestore.
  Future<Set<AdminPermission>> getAllPermissions() async {
    // Fast path: use cached data
    if (_cacheReady) {
      return _getAllPermissionsFromCache();
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    try {
      final doc = await _firestore
          .collection(FirestoreInstance.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) return {};

      final data = doc.data()!;
      final roles = List<String>.from(data['roles'] ?? []);
      final role = UserRole.fromRolesList(roles);

      // Super admin has all permissions
      if (role == UserRole.superAdmin) {
        return RolePermissions.superAdminPermissions;
      }

      // Start with role-based permissions
      final permissions = Set<AdminPermission>.from(
        RolePermissions.getPermissionsForRole(role),
      );

      // Add custom permissions
      final customPermissions = List<String>.from(
        data['adminPermissions'] ?? [],
      );
      for (final permName in customPermissions) {
        final perm = AdminPermissionExtension.fromString(permName);
        if (perm != null) {
          permissions.add(perm);
        }
      }

      return permissions;
    } catch (e) {
      _log.error('Error getting all permissions', error: e, tag: _tag);
      return {};
    }
  }

  /// Get all permissions from cached data (no Firestore call).
  Set<AdminPermission> _getAllPermissionsFromCache() {
    if (_cachedRole == UserRole.superAdmin) {
      return RolePermissions.superAdminPermissions;
    }

    final permissions = Set<AdminPermission>.from(
      RolePermissions.getPermissionsForRole(_cachedRole),
    );

    for (final permName in _cachedCustomPermissions) {
      final perm = AdminPermissionExtension.fromString(permName);
      if (perm != null) {
        permissions.add(perm);
      }
    }

    return permissions;
  }

  /// Add an admin role to a user (requires super_admin permission).
  ///
  /// This adds the role to the existing roles array.
  Future<void> addRoleToUser(String targetUserId, UserRole roleToAdd) async {
    final hasPermission = await this.hasPermission(
      AdminPermission.manageAdmins,
    );
    if (!hasPermission) {
      throw Exception('Permission denied: cannot manage admin roles');
    }

    final roleString = roleToAdd.toRoleString();
    if (roleString.isEmpty) {
      throw Exception('Cannot add user role explicitly');
    }

    await _firestore
        .collection(FirestoreInstance.usersCollection)
        .doc(targetUserId)
        .update({
          'roles': FieldValue.arrayUnion([roleString]),
          'updated_at': FieldValue.serverTimestamp(),
        });

    _log.info('Added role $roleString to user $targetUserId', tag: _tag);
  }

  /// Remove an admin role from a user (requires super_admin permission).
  ///
  /// This removes the role from the existing roles array.
  Future<void> removeRoleFromUser(
    String targetUserId,
    UserRole roleToRemove,
  ) async {
    final hasPermission = await this.hasPermission(
      AdminPermission.manageAdmins,
    );
    if (!hasPermission) {
      throw Exception('Permission denied: cannot manage admin roles');
    }

    final roleString = roleToRemove.toRoleString();
    if (roleString.isEmpty) {
      throw Exception('Cannot remove user role explicitly');
    }

    await _firestore
        .collection(FirestoreInstance.usersCollection)
        .doc(targetUserId)
        .update({
          'roles': FieldValue.arrayRemove([roleString]),
          'updated_at': FieldValue.serverTimestamp(),
        });

    _log.info('Removed role $roleString from user $targetUserId', tag: _tag);
  }
}
