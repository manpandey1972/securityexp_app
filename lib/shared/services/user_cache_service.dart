import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Centralized service for caching user objects
/// Stores user data in memory to avoid redundant Firestore queries
///
/// Access via service locator: `sl<UserCacheService>()`
class UserCacheService {
  UserCacheService();

  static const String _tag = 'UserCacheService';
  AppLogger get _log => sl<AppLogger>();

  final Map<String, models.User> _cache = {};
  final Map<String, StreamSubscription<DocumentSnapshot>> _listeners = {};
  final Map<String, StreamController<models.User>> _userStreamControllers = {};
  final FirebaseFirestore _firestore = FirestoreInstance().db;

  /// Get a user from cache
  /// Returns null if user is not in cache
  models.User? get(String userId) {
    return _cache[userId];
  }

  /// Get a stream of user updates
  /// This stream will emit whenever the user's cached data changes
  Stream<models.User> getUserStream(String userId) {
    // Validate userId
    if (userId.isEmpty) {
      return const Stream.empty();
    }

    // Create a stream controller for this user if it doesn't exist
    if (!_userStreamControllers.containsKey(userId)) {
      _userStreamControllers[userId] =
          StreamController<models.User>.broadcast();
    }

    // Emit current cached value if available, otherwise fetch it
    final currentUser = _cache[userId];
    if (currentUser != null) {
      Future.microtask(() {
        if (!_userStreamControllers[userId]!.isClosed) {
          _userStreamControllers[userId]!.add(currentUser);
        }
      });
    } else {
      // User not in cache, fetch it immediately and emit
      getOrFetch(userId).then((user) {
        if (user != null && !_userStreamControllers[userId]!.isClosed) {
          _userStreamControllers[userId]!.add(user);
        }
      });
    }

    // Start listening for real-time updates if not already listening
    _startListeningToUser(userId);

    return _userStreamControllers[userId]!.stream;
  }

  /// Notify listeners that a user has been updated
  void _notifyUserUpdate(String userId, models.User user) {
    if (_userStreamControllers.containsKey(userId)) {
      if (!_userStreamControllers[userId]!.isClosed) {
        _userStreamControllers[userId]!.add(user);
      }
    }
  }

  /// Get user name from cache
  /// Returns null if user is not in cache
  String? getUserName(String userId) {
    final user = _cache[userId];
    if (user == null) return null;
    return user.name;
  }

  /// Get user profile picture URL from cache
  /// Returns null if user is not in cache or has no profile picture
  String? getProfilePictureUrl(String userId) {
    final user = _cache[userId];
    if (user == null) return null;
    return user.profilePictureUrl;
  }

  /// Check if user has a profile picture
  /// Returns false if user is not in cache
  bool hasProfilePicture(String userId) {
    final user = _cache[userId];
    if (user == null) return false;
    return user.hasProfilePicture ?? false;
  }

  /// Get a user from cache or fetch from Firestore if not cached
  Future<models.User?> getOrFetch(String userId) async {
    // Validate userId
    if (userId.isEmpty) {
      return null;
    }

    // Check cache first
    if (_cache.containsKey(userId)) {
      return _cache[userId];
    }

    // Fetch from Firestore
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      final user = models.User.fromJson(data);
      _cache[userId] = user;
      // Start listening for updates to this user
      _startListeningToUser(userId);
      return user;
    } catch (e) {
      _log.error('getOrFetch failed for userId: $userId', tag: _tag, error: e);
      return null;
    }
  }

  /// Set/update a user in cache
  void set(String userId, models.User user) {
    _cache[userId] = user;
    // Start listening for updates if not already listening
    _startListeningToUser(userId);
  }

  /// Bulk load users into cache
  void setAll(Map<String, models.User> users) {
    _cache.addAll(users);
  }

  /// Load users from a list of user objects
  void loadUsers(List<models.User> users) {
    for (final user in users) {
      _cache[user.id] = user;
    }
  }

  /// Check if a user exists in cache
  bool contains(String userId) {
    return _cache.containsKey(userId);
  }

  /// Get all cached users
  Map<String, models.User> getAll() {
    return Map.unmodifiable(_cache);
  }

  /// Get a map of userId -> displayName for all cached users
  Map<String, String> getUserNameMap() {
    final map = <String, String>{};
    _cache.forEach((userId, user) {
      map[userId] = user.name;
    });
    return map;
  }

  /// Remove a user from cache
  void remove(String userId) {
    _cache.remove(userId);
    _stopListeningToUser(userId);
  }

  /// Clear all cached users
  void clear() {
    _cache.clear();
    // Stop all listeners
    for (final userId in _listeners.keys.toList()) {
      _stopListeningToUser(userId);
    }
  }

  /// Get cache size
  int get size => _cache.length;

  /// Fetch and cache multiple users by their IDs
  Future<Map<String, models.User>> fetchMultiple(List<String> userIds) async {
    final result = <String, models.User>{};
    final toFetch = <String>[];

    // Check which users are already cached
    for (final userId in userIds) {
      if (_cache.containsKey(userId)) {
        result[userId] = _cache[userId]!;
      } else {
        toFetch.add(userId);
      }
    }

    if (toFetch.isEmpty) {
      return result;
    }

    // Fetch missing users in batches of 10 (Firestore 'in' query limit)
    for (var i = 0; i < toFetch.length; i += 10) {
      final batch = toFetch.skip(i).take(10).toList();

      try {
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        // Track which IDs were actually fetched (some may be deleted users)
        for (final doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          final user = models.User.fromJson(data);
          _cache[doc.id] = user;
          result[doc.id] = user;
          // Start listening for updates to this user
          _startListeningToUser(doc.id);
        }
      } catch (e) {
        _log.error('fetchMultiple failed for batch: $batch', tag: _tag, error: e);
      }
    }

    return result;
  }

  /// Start listening for real-time updates to a user
  void _startListeningToUser(String userId) {
    // Validate userId
    if (userId.isEmpty) {
      return;
    }

    // Don't create duplicate listeners
    if (_listeners.containsKey(userId)) {
      return;
    }

    // ignore: cancel_subscriptions - subscription is stored in _listeners and cancelled via _stopListeningToUser
    final subscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) {
              _cache.remove(userId);
              _stopListeningToUser(userId);
              return;
            }

            try {
              final data = snapshot.data()!;
              data['id'] = userId;
              final updatedUser = models.User.fromJson(data);
              final oldUser = _cache[userId];

              // Check if profile picture was updated
              if (oldUser != null &&
                  oldUser.profilePictureUpdatedAt !=
                      updatedUser.profilePictureUpdatedAt) {
              }

              _cache[userId] = updatedUser;
              _notifyUserUpdate(userId, updatedUser);
            } catch (e) {
              _log.error('Error parsing user snapshot for $userId', tag: _tag, error: e);
            }
          },
          onError: (error) {
            _log.error('Firestore listener error for $userId', tag: _tag, error: error);
            _stopListeningToUser(userId);
          },
        );

    _listeners[userId] = subscription;
  }

  /// Stop listening for updates to a user
  void _stopListeningToUser(String userId) {
    final subscription = _listeners.remove(userId);
    subscription?.cancel();
  }

  /// Dispose of all listeners (call this when app closes)
  void dispose() {
    for (final subscription in _listeners.values) {
      subscription.cancel();
    }
    _listeners.clear();

    // Close all stream controllers
    for (final controller in _userStreamControllers.values) {
      controller.close();
    }
    _userStreamControllers.clear();

    _cache.clear();
  }
}
