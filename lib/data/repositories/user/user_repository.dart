import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/calling/services/platform_utils.dart';
import 'package:securityexperts_app/shared/services/account_cleanup_service.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/data/repositories/interfaces/repository_interfaces.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';
import 'package:securityexperts_app/providers/auth_provider.dart';

/// Repository for User profile CRUD operations using Firestore directly.
/// Replaces Cloud Run API calls for user management.
class UserRepository implements IUserRepository {
  /// Delete the current user's account and all associated data.
  ///
  /// Writes a deletion request document to Firestore, which triggers a
  /// background Cloud Function for GDPR-compliant cleanup:
  /// - Firestore: user doc + subcollections, chat rooms + messages,
  ///   call data, ratings, support tickets
  /// - Storage: profile pictures, chat attachments, support attachments
  /// - RTDB: presence data
  /// - Auth: Firebase Auth account
  ///
  /// Client-side cleanup is done first for local state (FCM, VoIP, presence,
  /// cache), then a Firestore-triggered Cloud Function handles all server-side
  /// data deletion in the background. The client does NOT wait for the
  /// server-side cleanup to complete — it signs out immediately.
  @override
  Future<void> deleteAccount() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final userId = currentUser.uid;
    try {
      // 1. Client-side cleanup (tokens, presence, listeners, cache)
      //    Requires auth, so must happen BEFORE deletion request
      await sl<AccountCleanupService>().performCleanup(userId);

      // 2. Write a deletion request document — this triggers a background
      //    Cloud Function that handles all server-side data cleanup
      //    (including deleting the Firebase Auth account).
      await _firestoreService.db
          .collection('deletion_requests')
          .doc(userId)
          .set({
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'platform': _getPlatformString(),
      });

      _log.info(
        'Deletion request written, background cleanup will proceed',
        tag: _tag,
      );

      // 3. Prevent auth listener from re-running cleanup
      sl<AuthState>().markCleanupHandled();

      // 4. Sign out immediately — don't wait for server-side cleanup
      await _auth.signOut();

      _log.info('User signed out after deletion request', tag: _tag);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete account',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      rethrow;
    }
  }

  final FirestoreInstance _firestoreService = FirestoreInstance();
  final firebase_auth.FirebaseAuth _auth = sl<firebase_auth.FirebaseAuth>();
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'UserRepository';

  /// Get the current authenticated user's ID
  @override
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get current user profile from Firestore
  @override
  Future<User?> getCurrentUserProfile() async {
    return await ErrorHandler.handle<User?>(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) return null;

        final doc = await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid)
            .get();

        if (!doc.exists) {
          return null;
        }

        final userData = doc.data() as Map<String, dynamic>;
        // Ensure ID is set
        if (!userData.containsKey('id') ||
            (userData['id'] as String?)?.isEmpty == true) {
          userData['id'] = doc.id;
        }
        return User.fromJson(userData);
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error fetching user profile: $error', tag: _tag),
    );
  }

  /// Get user profile by ID from Firestore
  /// Uses UserCacheService to avoid redundant Firestore reads
  @override
  Future<User?> getUserById(String userId) async {
    // Check cache first via UserCacheService
    final userCache = sl<UserCacheService>();
    final cachedUser = userCache.get(userId);
    if (cachedUser != null) {
      return cachedUser;
    }

    return await ErrorHandler.handle<User?>(
      operation: () async {
        // Start Firestore read trace
        final trace = sl<AnalyticsService>().newTrace(
          'firestore_read_user_profile',
        );
        await trace.start();

        final doc = await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(userId)
            .get();

        trace.putAttribute('doc_exists', doc.exists.toString());
        await trace.stop();

        if (!doc.exists) {
          return null;
        }

        final userData = doc.data() as Map<String, dynamic>;
        if (!userData.containsKey('id') ||
            (userData['id'] as String?)?.isEmpty == true) {
          userData['id'] = doc.id;
        }
        final user = User.fromJson(userData);

        // Cache the fetched user for future requests
        userCache.set(userId, user);

        return user;
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error fetching user by ID: $error', tag: _tag),
    );
  }

  /// Create a new user profile in Firestore.
  @override
  Future<User> createUser(User user) async {
    return await ErrorHandler.handle<User>(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('No authenticated user');
        }

        final userData = user.toJson();
        userData['created_at'] = FieldValue.serverTimestamp();
        userData['updated_at'] = FieldValue.serverTimestamp();
        userData['last_login'] = FieldValue.serverTimestamp();

        await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid)
            .set(userData, SetOptions(merge: true));

        // Fetch the created user to get server timestamps
        final doc = await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid)
            .get();

        final createdData = doc.data() as Map<String, dynamic>;
        createdData['id'] = doc.id;
        return User.fromJson(createdData);
      },
      fallback: user,
      onError: (error) => _log.error('Error creating user: $error', tag: _tag),
    );
  }

  /// Update user profile in Firestore.
  @override
  Future<User> updateUser(User user) async {
    return await ErrorHandler.handle<User>(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('No authenticated user');
        }

        final userData = user.toJson();
        userData['updated_at'] = FieldValue.serverTimestamp();

        await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid)
            .update(userData);

        // Fetch and return updated user
        final doc = await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid)
            .get();

        final updatedData = doc.data() as Map<String, dynamic>;
        updatedData['id'] = doc.id;
        return User.fromJson(updatedData);
      },
      fallback: user,
      onError: (error) => _log.error('Error updating user: $error', tag: _tag),
    );
  }

  /// Update a specific field in the user profile
  @override
  Future<void> updateField(String field, dynamic value) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('No authenticated user');
        }

        await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid)
            .update({field: value, 'updated_at': FieldValue.serverTimestamp()});
      },
      onError: (error) => _log.error(
        'Error updating field $field: $error',
        tag: _tag,
      ),
    );
  }

  /// Toggle notifications enabled/disabled
  @override
  Future<bool> toggleNotifications(bool enabled) async {
    return await ErrorHandler.handle<bool>(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('No authenticated user');
        }

        await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid)
            .update({
              'notifications_enabled': enabled,
              'updated_at': FieldValue.serverTimestamp(),
            });

        _log.info(
          'Notifications ${enabled ? 'enabled' : 'disabled'}',
          tag: _tag,
        );
        return enabled;
      },
      fallback: !enabled, // Return opposite on failure (revert)
      onError: (error) =>
          _log.error('Error toggling notifications: $error', tag: _tag),
    );
  }

  /// Update FCM tokens for push notifications
  @override
  Future<void> updateFcmTokens(List<String> tokens) async {
    await updateField('fcms', tokens);
  }

  /// Add a single FCM token to the user's token list
  /// This replaces any existing tokens to prevent token accumulation
  /// and keeps only the current device's token
  @override
  Future<void> addFcmToken(String token, {String? oldToken}) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          _log.warning('No authenticated user found', tag: _tag);
          throw Exception('No authenticated user');
        }

        final docRef = _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid);

        // Check if document exists first
        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          // Document doesn't exist yet (new user before onboarding completes)
          // Use merge to create document with just the FCM token
          await docRef.set({
            'fcms': [token],
            'platform': _getPlatformString(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          _log.debug('FCM token saved to new document', tag: _tag);
          return;
        }

        // Document exists - use transaction to safely update tokens
        await _firestoreService.db.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          final data = snapshot.data() as Map<String, dynamic>;
          final existingTokens = List<String>.from(data['fcms'] ?? []);

          // Remove old token if provided
          if (oldToken != null && existingTokens.contains(oldToken)) {
            existingTokens.remove(oldToken);
          }

          // Add new token if not already present
          if (!existingTokens.contains(token)) {
            existingTokens.add(token);
          }

          // Keep only the most recent 2 tokens to handle multi-device scenarios
          // while preventing unbounded growth
          if (existingTokens.length > 2) {
            existingTokens.removeRange(0, existingTokens.length - 2);
          }

          transaction.update(docRef, {
            'fcms': existingTokens,
            'platform': _getPlatformString(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        });

        _log.debug('FCM token updated', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error adding FCM token: $error', tag: _tag),
    );
  }

  /// Get platform string for user document
  /// Returns 'ios', 'android', 'web', or 'other'
  String _getPlatformString() {
    if (kIsWeb) {
      return 'web';
    }
    if (PlatformUtils.isIOS) {
      return 'ios';
    }
    if (PlatformUtils.isAndroid) {
      return 'android';
    }
    if (PlatformUtils.isMacOS) {
      return 'macos';
    }
    if (PlatformUtils.isWindows) {
      return 'windows';
    }
    if (PlatformUtils.isLinux) {
      return 'linux';
    }
    return 'other';
  }

  /// Remove a single FCM token from the user's token list
  @override
  Future<void> removeFcmToken(String token) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('No authenticated user');
        }

        await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid)
            .update({
              'fcms': FieldValue.arrayRemove([token]),
              'updated_at': FieldValue.serverTimestamp(),
            });
      },
      onError: (error) =>
          _log.error('Error removing FCM token: $error', tag: _tag),
    );
  }

  /// Update the user's last login timestamp
  ///
  /// This should be called after successful authentication to track
  /// user activity for analytics and admin dashboards.
  @override
  Future<void> updateLastLogin() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('No authenticated user');
        }

        await _firestoreService.db
            .collection(FirestoreInstance.usersCollection)
            .doc(currentUser.uid)
            .update({'last_login': FieldValue.serverTimestamp()});

        _log.debug('Last login updated', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error updating last login: $error', tag: _tag),
    );
  }

  /// Stream user profile changes in real-time
  @override
  Stream<User?> watchCurrentUserProfile() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(null);
    }

    return _firestoreService.db
        .collection(FirestoreInstance.usersCollection)
        .doc(currentUser.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return User.fromJson(data);
        });
  }
}
