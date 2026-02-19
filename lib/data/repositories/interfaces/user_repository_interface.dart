import 'package:securityexperts_app/data/models/models.dart';

/// Abstract interface for user repository operations.
/// 
/// This interface defines the contract for user-related data operations,
/// enabling dependency injection and easier testing through mocking.
abstract class IUserRepository {
  /// Get the current authenticated user's ID
  String? get currentUserId;

  /// Get current user profile from data source
  Future<User?> getCurrentUserProfile();

  /// Get a user by their ID
  Future<User?> getUserById(String userId);

  /// Create a new user profile
  Future<User> createUser(User user);

  /// Update an existing user profile
  Future<User> updateUser(User user);

  /// Update a single field on the user profile
  Future<void> updateField(String field, dynamic value);

  /// Toggle notification settings
  Future<bool> toggleNotifications(bool enabled);

  /// Update FCM tokens for push notifications
  Future<void> updateFcmTokens(List<String> tokens);

  /// Add a new FCM token
  Future<void> addFcmToken(String token, {String? oldToken});

  /// Remove an FCM token
  Future<void> removeFcmToken(String token);

  /// Update the user's last login timestamp
  Future<void> updateLastLogin();

  /// Delete the current user's account
  Future<void> deleteAccount();

  /// Stream user profile changes in real-time
  Stream<User?> watchCurrentUserProfile();
}
