import 'package:flutter/foundation.dart';
import 'package:securityexperts_app/data/models/models.dart';

/// Global user profile service that maintains the current user's profile
/// across the entire application. Uses the ChangeNotifier pattern for reactive updates.
class UserProfileService extends ChangeNotifier {
  static final UserProfileService _instance = UserProfileService._internal();

  User? _userProfile;
  bool _isLoading = false;
  String? _error;

  UserProfileService._internal();

  /// Get the singleton instance
  factory UserProfileService() {
    return _instance;
  }

  /// Get the current user profile (nullable if not loaded)
  User? get userProfile => _userProfile;

  /// Get the current user profile or throw if not available
  User get requireUserProfile {
    if (_userProfile == null) {
      throw Exception('User profile not loaded. Call setUserProfile first.');
    }
    return _userProfile!;
  }

  /// Check if user profile is loaded
  bool get isProfileLoaded => _userProfile != null;

  /// Check if currently loading profile
  bool get isLoading => _isLoading;

  /// Get last error message if any
  String? get error => _error;

  /// Set the user profile and notify listeners
  void setUserProfile(User profile) {
    _userProfile = profile;
    _error = null;
    notifyListeners();
  }

  /// Update the user profile (for partial updates)
  void updateUserProfile(User profile) {
    _userProfile = profile;
    _error = null;
    notifyListeners();
  }

  /// Clear the user profile (on logout)
  void clearUserProfile() {
    _userProfile = null;
    _error = null;
    notifyListeners();
  }

  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void setError(String? errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  /// Reset the service to initial state
  void reset() {
    _userProfile = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
