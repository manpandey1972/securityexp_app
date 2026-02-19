import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/features/admin/data/models/admin_user.dart';

/// Repository for admin user data operations.
///
/// This repository handles all Firestore operations for user management.
/// Business logic and permission checks are handled by [AdminUserService].
abstract class AdminUserRepository {
  /// Get users with optional filters and pagination.
  Future<List<AdminUser>> getUsers({
    String? roleFilter,
    bool? isSuspended,
    int limit = 50,
    DocumentSnapshot? startAfter,
  });

  /// Search users by name or email.
  Future<List<AdminUser>> searchUsers(String query, {int limit = 100});

  /// Get a single user by ID.
  Future<AdminUser?> getUser(String userId);

  /// Update user suspension status.
  Future<void> updateSuspension({
    required String userId,
    required bool isSuspended,
    String? reason,
    String? suspendedBy,
  });

  /// Update user roles.
  Future<void> updateRoles(String userId, List<String> roles);

  /// Add a role to user.
  Future<void> addRole(String userId, String role);

  /// Remove a role from user.
  Future<void> removeRole(String userId, String role);

  /// Get all users for statistics calculation.
  Future<List<AdminUser>> getAllUsersForStats();
}

/// Firestore implementation of [AdminUserRepository].
class FirestoreAdminUserRepository implements AdminUserRepository {
  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';

  FirestoreAdminUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreInstance().db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_usersCollection);

  @override
  Future<List<AdminUser>> getUsers({
    String? roleFilter,
    bool? isSuspended,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _collection;

    // Skip Firestore role filtering for 'Admin' - we'll filter client-side
    // to include both 'Admin' and 'SuperAdmin' roles
    if (roleFilter != null && roleFilter != 'Admin') {
      query = query.where('roles', arrayContains: roleFilter);
    }

    if (isSuspended != null) {
      query = query.where('isSuspended', isEqualTo: isSuspended);
    }

    query = query.orderBy('name').limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => AdminUser.fromFirestore(doc)).toList();
  }

  @override
  Future<List<AdminUser>> searchUsers(String query, {int limit = 100}) async {
    final snapshot = await _collection.limit(limit).get();
    return snapshot.docs.map((doc) => AdminUser.fromFirestore(doc)).toList();
  }

  @override
  Future<AdminUser?> getUser(String userId) async {
    final doc = await _collection.doc(userId).get();
    if (!doc.exists) return null;
    return AdminUser.fromFirestore(doc);
  }

  @override
  Future<void> updateSuspension({
    required String userId,
    required bool isSuspended,
    String? reason,
    String? suspendedBy,
  }) async {
    if (isSuspended) {
      await _collection.doc(userId).update({
        'isSuspended': true,
        'suspendedReason': reason,
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspendedBy': suspendedBy,
      });
    } else {
      await _collection.doc(userId).update({
        'isSuspended': false,
        'suspendedReason': FieldValue.delete(),
        'suspendedAt': FieldValue.delete(),
        'suspendedBy': FieldValue.delete(),
      });
    }
  }

  @override
  Future<void> updateRoles(String userId, List<String> roles) async {
    await _collection.doc(userId).update({
      'roles': roles,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> addRole(String userId, String role) async {
    await _collection.doc(userId).update({
      'roles': FieldValue.arrayUnion([role]),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeRole(String userId, String role) async {
    await _collection.doc(userId).update({
      'roles': FieldValue.arrayRemove([role]),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<AdminUser>> getAllUsersForStats() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => AdminUser.fromFirestore(doc)).toList();
  }
}
