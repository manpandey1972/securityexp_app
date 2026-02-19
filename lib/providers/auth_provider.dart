import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:securityexperts_app/shared/services/account_cleanup_service.dart';
import 'package:securityexperts_app/shared/services/firebase_messaging_service.dart';
import 'package:securityexperts_app/features/chat/services/user_presence_service.dart';
import 'package:securityexperts_app/features/calling/infrastructure/repositories/voip_token_repository.dart';
import 'package:securityexperts_app/features/photo_backup/services/photo_backup_service.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

/// Auth Provider for managing authentication state using Provider pattern

class AuthState extends ChangeNotifier {
  final fb.FirebaseAuth _firebaseAuth;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'AuthState';

  // State variables
  fb.User? _user;
  String? _error;
  bool _isLoading = false;
  bool _signOutInitiated = false; // Track if signOut() method was called
  StreamSubscription<fb.User?>?
  _authSubscription; // Store subscription to prevent memory leak

  // Getters
  fb.User? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;

  /// Mark that cleanup is being handled externally (e.g., by deleteAccount)
  /// Prevents the auth state listener from attempting duplicate cleanup
  void markCleanupHandled() {
    _signOutInitiated = true;
  }

  AuthState(this._firebaseAuth) {
    _initializeAuthListener();
    _checkInitialAuthState();
  }

  /// Check initial auth state and initialize FCM/VoIP if user is already logged in
  /// Only initializes tokens if user profile exists (not a new user mid-onboarding)
  Future<void> _checkInitialAuthState() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      _user = currentUser;

      // Check if user profile exists before initializing tokens
      // New users won't have a profile yet - tokens will be initialized after onboarding
      try {
        final userProfile = await sl<UserRepository>().getCurrentUserProfile();
        if (userProfile != null && userProfile.name.isNotEmpty) {
          await initializeTokenServices(currentUser.uid);
        }
      } catch (e) {
        _log.error('Error checking user profile on startup', tag: _tag);
      }
    } else {
      // No user authenticated
    }
  }

  /// Initialize Firebase Auth listener
  void _initializeAuthListener() {
    _authSubscription = _firebaseAuth.authStateChanges().listen((
      fb.User? user,
    ) async {
      final bool wasAuthenticated = _user != null;
      final bool isNowAuthenticated = user != null;

      // Capture old user ID BEFORE updating _user (needed for cleanup on logout)
      final String? oldUserId = _user?.uid;

      _user = user;
      notifyListeners();

      // Note: Token services (FCM/VoIP) are NOT initialized here.
      // For new users: tokens are initialized after onboarding completes (in UserOnboardingPage)
      // For existing users: tokens are initialized after profile is confirmed (in PhoneAuthViewModel)
      // This ensures tokens are only saved when user document exists in Firestore.

      // Clean up FCM and VoIP on logout
      if (wasAuthenticated && !isNowAuthenticated) {
        // Only clean up if signOut() didn't already handle it
        if (!_signOutInitiated) {
          if (oldUserId != null) {
            await sl<AccountCleanupService>().performCleanup(oldUserId);
          }
        } else {
          _signOutInitiated = false; // Reset flag for next logout
        }
      }
    });
  }

  /// Initialize FCM and VoIP token services
  /// Public method - called after user profile is confirmed to exist:
  /// - For existing users: called from PhoneAuthViewModel after OTP verification
  /// - For new users: called from UserOnboardingPage after profile creation
  Future<void> initializeTokenServices(String userId) async {
    // Initialize user presence for push notification suppression
    try {
      await sl<UserPresenceService>().initialize();
    } catch (e) {
      _log.error('Failed to initialize user presence: $e', tag: _tag);
    }

    // Initialize FCM for push notifications
    try {
      await sl<FirebaseMessagingService>().initialize(userId);
      _log.info('FCM initialized', tag: _tag);
    } catch (e) {
      _log.error('Failed to initialize FCM', tag: _tag);
    }

    // Initialize VoIP tokens for iOS CallKit push
    try {
      await sl<VoIPTokenRepository>().initialize(userId);
      _log.info('VoIP token sync initialized', tag: _tag);
    } catch (e) {
      _log.error('Failed to initialize VoIP token sync', tag: _tag);
    }

    // Initialize photo backup service (iOS only)
    try {
      await sl<PhotoBackupService>().initialize(userId);
      _log.info('Photo backup service initialized', tag: _tag);
    } catch (e) {
      _log.error('Failed to initialize photo backup: $e', tag: _tag);
    }
  }

  /// Sign up with email and password
  Future<void> signUp(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
    } on fb.FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
    } on fb.FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Capture userId BEFORE signing out (needed for cleanup)
      final userId = _user?.uid;

      // Mark that signOut() is handling the cleanup
      // Prevents the auth listener from duplicating cleanup
      _signOutInitiated = true;

      if (userId != null) {
        await sl<AccountCleanupService>().performCleanup(userId);
      }

      await _firebaseAuth.signOut();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign out: $e';
      _signOutInitiated = false; // Reset flag on error
      notifyListeners();
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      _isLoading = false;
      notifyListeners();
    } on fb.FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update password
  Future<void> updatePassword(String newPassword) async {
    if (_user == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    try {
      await _user!.updatePassword(newPassword);
      _error = null;
      notifyListeners();
    } on fb.FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Map Firebase auth error codes to user-friendly messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'Wrong password';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email';
      default:
        return 'Authentication error: $code';
    }
  }

  @override
  void dispose() {
    _log.debug(
      'Disposing AuthState, canceling auth listener subscription',
      tag: _tag,
    );
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }
}
