import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Service for Google Sign-In authentication.
///
/// Handles the Google Sign-In flow and creates Firebase credentials
/// for seamless cross-platform (web + mobile) authentication.
class GoogleAuthService {
  static const String _tag = 'GoogleAuthService';

  final FirebaseAuth _auth;
  bool _initialized = false;

  AppLogger? get _log => sl.isRegistered<AppLogger>() ? sl<AppLogger>() : null;

  GoogleAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  /// Ensure GoogleSignIn is initialized (call once).
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '1015827376061-pq974q830ni388rcvsu1s99rdivgm09a.apps.googleusercontent.com',
    );
    _initialized = true;
  }

  /// Sign in with Google and return the Firebase [UserCredential].
  ///
  /// On web, uses popup-based sign-in via Firebase Auth directly.
  /// On mobile, uses the native Google Sign-In SDK flow.
  ///
  /// Returns `null` if the user cancels the sign-in flow.
  /// Throws [FirebaseAuthException] if authentication fails.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      } else {
        return await _signInWithGoogleNative();
      }
    } catch (e) {
      _log?.error('Google Sign-In failed: $e', tag: _tag);
      rethrow;
    }
  }

  /// Native (iOS/Android) Google Sign-In flow using google_sign_in v7 API
  Future<UserCredential?> _signInWithGoogleNative() async {
    await _ensureInitialized();

    try {
      // Trigger the interactive Google Sign-In flow
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      _log?.debug('Google user: ${googleUser.email}', tag: _tag);

      // Get the ID token from authentication
      final idToken = googleUser.authentication.idToken;

      // For Firebase Auth we need the idToken. accessToken is obtained
      // separately via authorization if needed, but Firebase only needs
      // the idToken for credential creation.
      final credential = GoogleAuthProvider.credential(idToken: idToken);

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      _log?.info(
          'Google Sign-In successful: ${userCredential.user?.uid}', tag: _tag);

      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _log?.info('Google Sign-In cancelled by user', tag: _tag);
        return null;
      }
      rethrow;
    }
  }

  /// Web Google Sign-In flow using Firebase Auth popup
  Future<UserCredential?> _signInWithGoogleWeb() async {
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');

    final userCredential = await _auth.signInWithPopup(googleProvider);
    _log?.info(
        'Google Sign-In (web) successful: ${userCredential.user?.uid}',
        tag: _tag);

    return userCredential;
  }

  /// Sign out from Google (clears cached account)
  Future<void> signOut() async {
    try {
      if (!kIsWeb && _initialized) {
        await GoogleSignIn.instance.signOut();
      }
      _log?.debug('Google Sign-Out completed', tag: _tag);
    } catch (e) {
      _log?.error('Google Sign-Out error: $e', tag: _tag);
    }
  }
}
