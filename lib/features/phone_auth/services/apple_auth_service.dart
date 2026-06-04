import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Service for Sign in with Apple authentication.
///
/// Handles the Apple Sign-In flow and creates Firebase credentials
/// for seamless cross-platform (iOS, web, Android) authentication.
///
/// - iOS: native Apple Sign-In sheet via `FirebaseAuth.signInWithProvider`.
/// - Web: Firebase popup via `signInWithPopup`.
/// - Android: `FirebaseAuth.signInWithProvider`, which opens Apple's OAuth
///   page in a Chrome Custom Tab and exchanges the result via Firebase's
///   hosted handler at `*.firebaseapp.com/__/auth/handler`.
class AppleAuthService {
  static const String _tag = 'AppleAuthService';

  static const _oauthChannel =
      MethodChannel('com.goaegent.securityexperts/oauth');

  final FirebaseAuth _auth;

  AppLogger? get _log => sl.isRegistered<AppLogger>() ? sl<AppLogger>() : null;

  AppleAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

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

  /// Native Apple Sign-In on iOS via Firebase's built-in provider.
  ///
  /// Uses [FirebaseAuth.signInWithProvider] with [AppleAuthProvider], which
  /// triggers the native ASAuthorizationAppleIDProvider sheet and handles the
  /// nonce + token exchange entirely inside the Firebase iOS SDK.
  /// This avoids the sign_in_with_apple plugin's credential path which can
  /// cause "Invalid OAuth response from apple.com" on some Firebase SDK
  /// versions due to the authorization code being included in the request.
  Future<UserCredential?> _signInWithAppleNative() async {
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      final userCredential = await _auth.signInWithProvider(provider);

      await _persistDisplayName(userCredential);

      _log?.info(
        'Apple Sign-In successful: ${userCredential.user?.uid}',
        tag: _tag,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // User-cancelled sign-in — not an error
      if (e.code == 'cancelled' ||
          e.code == 'web-context-cancelled' ||
          e.code == 'user-cancelled') {
        _log?.info('Apple Sign-In cancelled by user', tag: _tag);
        return null;
      }
      _log?.error(
        'Firebase rejected Apple credential: code=${e.code} message=${e.message}',
        tag: _tag,
      );
      rethrow;
    } on PlatformException catch (e) {
      // ASAuthorizationError.canceled (code 1001) on iOS
      if (e.code == '1001' || (e.message ?? '').contains('cancel')) {
        _log?.info('Apple Sign-In cancelled by user (platform)', tag: _tag);
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
  ///
  /// Common failure modes on Android:
  /// - "missing initial state": Chrome Custom Tab session was interrupted, OR
  ///   Firebase Console Apple provider is missing Service ID / .p8 key config,
  ///   causing Firebase's handler to reject Apple's token and loop back to Apple.
  /// - Loop back to Apple login: Same root cause — Firebase can't validate the
  ///   Apple identity token because the Apple provider isn't fully configured in
  ///   Firebase Console (Authentication → Sign-in method → Apple → Service ID,
  ///   Team ID, Key ID, Private Key).
  Future<UserCredential?> _signInWithAppleAndroid() async {
    try {
      final provider = AppleAuthProvider();
      provider.addScope('email');
      provider.addScope('name');

      _log?.debug(
        'Starting Apple Sign-In on Android via Chrome Custom Tab.',
        tag: _tag,
      );

      final userCredential = await _auth.signInWithProvider(provider);

      // Bring the app to front immediately after signInWithProvider resolves,
      // before profile loading begins. This eliminates the delay caused by
      // Android leaving Chrome's Custom Tab task in the foreground while all
      // post-auth work (profile load, token init) runs in the background.
      try {
        await _oauthChannel.invokeMethod<void>('bringToFront');
      } catch (_) {
        // Non-fatal — user can still switch to the app manually.
      }

      await _persistDisplayName(userCredential);

      _log?.info(
        'Apple Sign-In (Android) successful: ${userCredential.user?.uid}',
        tag: _tag,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'cancelled' ||
          e.code == 'web-context-cancelled' ||
          e.code == 'user-cancelled') {
        _log?.info('Apple Sign-In (Android) cancelled by user', tag: _tag);
        return null;
      }
      _log?.error(
        'Firebase rejected Apple credential (Android): code=${e.code} message=${e.message}. '
        'If code is "invalid-credential" or "web-context-failed", the Apple provider '
        'in Firebase Console is likely missing Service ID / private key configuration.',
        tag: _tag,
      );
      rethrow;
    }
  }

  /// Apple only sends the display name on the FIRST sign-in ever.
  /// Persist it to Firebase Auth so it's available on subsequent logins.
  Future<void> _persistDisplayName(UserCredential userCredential) async {
    final profile = userCredential.additionalUserInfo?.profile;
    if (profile == null) return;

    final givenName = profile['given_name'] as String?;
    final familyName = profile['family_name'] as String?;
    final displayName = [givenName, familyName]
        .where((n) => n != null && n.isNotEmpty)
        .join(' ');

    if (displayName.isEmpty) return;

    final existing = userCredential.user?.displayName;
    if (existing == null || existing.isEmpty) {
      await userCredential.user?.updateDisplayName(displayName);
    }
  }

  /// No-op sign out — Apple doesn't maintain a local session like Google.
  Future<void> signOut() async {
    _log?.debug('Apple Sign-Out (no-op)', tag: _tag);
  }
}
