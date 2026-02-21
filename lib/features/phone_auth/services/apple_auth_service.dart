import 'dart:convert';
import 'dart:math';

import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Service for Sign in with Apple authentication.
///
/// Handles the Apple Sign-In flow and creates Firebase credentials
/// for seamless cross-platform (iOS, web, Android) authentication.
///
/// On iOS, uses the native Apple Sign-In sheet.
/// On web/Android, falls back to Firebase OAuth popup.
class AppleAuthService {
  static const String _tag = 'AppleAuthService';

  final FirebaseAuth _auth;

  AppLogger? get _log => sl.isRegistered<AppLogger>() ? sl<AppLogger>() : null;

  AppleAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  /// Generate a cryptographically-secure random nonce.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// SHA-256 hash of a string (used to hash the nonce).
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in with Apple and return the Firebase [UserCredential].
  ///
  /// Returns `null` if the user cancels the sign-in flow.
  /// Throws on authentication failure.
  Future<UserCredential?> signInWithApple() async {
    try {
      if (kIsWeb) {
        // Web: Firebase popup flow
        return await _signInWithAppleWeb();
      } else if (Platform.isIOS) {
        // iOS: native Apple Sign-In sheet
        return await _signInWithAppleNative();
      } else {
        // Android: Firebase provider flow (opens Chrome Custom Tab)
        return await _signInWithAppleAndroid();
      }
    } catch (e) {
      _log?.error('Apple Sign-In failed: $e', tag: _tag);
      rethrow;
    }
  }

  /// Native Apple Sign-In (iOS primarily, fallback on Android).
  Future<UserCredential?> _signInWithAppleNative() async {
    // 1. Generate a nonce to prevent replay attacks
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    try {
      // 2. Request Apple credential via native sheet
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      // 3. Create an OAuth credential for Firebase
      //    Only pass idToken + rawNonce on native. Passing the authorization
      //    code as accessToken triggers a server-side token exchange that
      //    requires a Service ID + .p8 key configured in Firebase — not
      //    needed for native iOS/Android sign-in.
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // 4. Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // 5. Apple only sends the display name on the FIRST sign-in ever.
      //    Persist it to Firebase Auth so it's available on subsequent logins.
      final displayName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((n) => n != null && n.isNotEmpty).join(' ');

      if (displayName.isNotEmpty &&
          (userCredential.user?.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        await userCredential.user?.updateDisplayName(displayName);
      }

      _log?.info(
        'Apple Sign-In successful: ${userCredential.user?.uid}',
        tag: _tag,
      );
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        _log?.info('Apple Sign-In cancelled by user', tag: _tag);
        return null;
      }
      rethrow;
    }
  }

  /// Web-based Apple Sign-In via Firebase popup.
  Future<UserCredential?> _signInWithAppleWeb() async {
    final provider = OAuthProvider('apple.com');
    provider.addScope('email');
    provider.addScope('name');

    final userCredential = await _auth.signInWithPopup(provider);
    _log?.info(
      'Apple Sign-In (web) successful: ${userCredential.user?.uid}',
      tag: _tag,
    );
    return userCredential;
  }

  /// Android Apple Sign-In via Firebase provider (Chrome Custom Tab).
  ///
  /// Uses `signInWithProvider` which opens Apple's OAuth page in a
  /// Chrome Custom Tab — `signInWithPopup` is web-only.
  Future<UserCredential?> _signInWithAppleAndroid() async {
    final provider = AppleAuthProvider();
    provider.addScope('email');
    provider.addScope('name');

    final userCredential = await _auth.signInWithProvider(provider);
    _log?.info(
      'Apple Sign-In (Android) successful: ${userCredential.user?.uid}',
      tag: _tag,
    );
    return userCredential;
  }

  /// No-op sign out — Apple doesn't maintain a local session like Google.
  Future<void> signOut() async {
    _log?.debug('Apple Sign-Out (no-op)', tag: _tag);
  }
}
