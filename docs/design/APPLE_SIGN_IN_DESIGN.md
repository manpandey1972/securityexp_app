# Apple Sign-In Authentication — Design Document

## Overview

Add "Sign in with Apple" as an authentication option alongside the existing Phone OTP and Google Sign-In methods. Apple Sign-In is **required by App Store policy** for any iOS app that offers third-party social login (e.g. Google). It uses Apple's OAuth 2.0 flow to generate an identity token, which is exchanged for a Firebase Auth credential.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        phone_auth_screen.dart                   │
│   [Phone OTP]   ──── OR ────   [Google]   [Apple]               │
└────────┬──────────────────────────┬──────────┬──────────────────┘
         │                          │          │
         ▼                          ▼          ▼
   PhoneAuthViewModel        GoogleAuth    AppleAuthService
         │                   Service       (NEW)
         ▼                          │          │
   Firebase Auth  ◄─────────────────┘──────────┘
         │
         ▼
   User Profile Check → Home or Onboarding
```

### New Files

| File | Purpose |
|------|---------|
| `lib/features/phone_auth/services/apple_auth_service.dart` | Handles Sign in with Apple flow + Firebase credential exchange |

### Modified Files

| File | Change |
|------|--------|
| `phone_auth_view_model.dart` | Add `signInWithApple()` method (mirrors `signInWithGoogle()`) |
| `phone_auth_screen.dart` | Add "Continue with Apple" button below Google button |
| `service_locator.dart` | Register `AppleAuthService` as lazy singleton |
| `auth_provider.dart` | Call `AppleAuthService.signOut()` on logout (no-op, but for consistency) |
| `pubspec.yaml` | Add `sign_in_with_apple` and `crypto` dependencies |

---

## Setup Steps

### Step 1: Apple Developer Console

1. **Sign in** to [Apple Developer](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles → Identifiers**
3. Select your **App ID** (`com.example.securityexpertsApp`)
4. Under **Capabilities**, enable **"Sign In with Apple"**
5. Click **Save**

#### For Web Support (optional, if web login is needed)

6. Create a **Services ID** (type: Services IDs):
   - Description: `Security Experts Web`
   - Identifier: `com.example.securityexpertsApp.web` (or similar)
   - Enable **"Sign In with Apple"**
   - Configure **Domains and Subdomains**: your Firebase Auth domain (e.g. `securityexp-app.firebaseapp.com`)
   - Configure **Return URLs**: `https://securityexp-app.firebaseapp.com/__/auth/handler`
7. Create a **Key** with **Sign In with Apple** enabled:
   - Download the `.p8` key file (needed for Firebase web flow)
   - Note the **Key ID**
8. Note your **Team ID** (shown at top right of developer portal)

---

### Step 2: Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com) → **securityexp-app**
2. Navigate to **Authentication → Sign-in method**
3. Click **Add new provider → Apple**
4. Toggle **Enable**

#### For iOS (native) — no extra config needed
Firebase handles iOS natively using the App ID capability you enabled in Step 1.

#### For Web/Android (optional)
5. Fill in:
   - **Service ID**: `com.example.securityexpertsApp.web` (from Step 1.6)
   - **Apple Team ID**: your team ID
   - **Key ID**: from the `.p8` key you created
   - **Private Key**: paste the contents of the `.p8` file
6. Click **Save**

---

### Step 3: Xcode / iOS Configuration

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target → **Signing & Capabilities**
3. Click **+ Capability** → add **"Sign In with Apple"**
   - This adds the `com.apple.developer.applesignin` entitlement automatically
4. Ensure your provisioning profile is regenerated (Xcode handles this with automatic signing)

> **Note**: No changes to `Info.plist` are needed for Apple Sign-In (unlike Google which requires URL schemes).

---

### Step 4: Android Configuration (optional)

Apple Sign-In on Android requires the web-based OAuth flow through Firebase. The setup from Step 2 (Service ID + Key) handles this. No additional Android-specific configuration is needed — the `sign_in_with_apple` package falls back to a web-based flow on Android.

---

### Step 5: Flutter Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  sign_in_with_apple: ^6.1.4
  crypto: ^3.0.6
```

Run `flutter pub get`.

---

### Step 6: Implement `AppleAuthService`

Create `lib/features/phone_auth/services/apple_auth_service.dart`:

```dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

class AppleAuthService {
  static const String _tag = 'AppleAuthService';
  final FirebaseAuth _auth;

  AppLogger? get _log =>
      sl.isRegistered<AppLogger>() ? sl<AppLogger>() : null;

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

  /// SHA-256 hash of a string (used for nonce).
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in with Apple and return the Firebase [UserCredential].
  ///
  /// Returns `null` if the user cancels.
  /// Throws on auth failure.
  Future<UserCredential?> signInWithApple() async {
    try {
      if (kIsWeb) {
        return await _signInWithAppleWeb();
      } else {
        return await _signInWithAppleNative();
      }
    } catch (e) {
      _log?.error('Apple Sign-In failed: $e', tag: _tag);
      rethrow;
    }
  }

  /// Native Apple Sign-In (iOS primarily)
  Future<UserCredential?> _signInWithAppleNative() async {
    // 1. Generate a nonce
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    try {
      // 2. Request Apple credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      // 3. Create OAuth credential for Firebase
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      // 4. Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // 5. Apple only sends display name on FIRST sign-in — persist it
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

  /// Web-based Apple Sign-In via Firebase popup
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

  /// No-op sign out (Apple doesn't maintain a local session like Google)
  Future<void> signOut() async {
    _log?.debug('Apple Sign-Out (no-op)', tag: _tag);
  }
}
```

---

### Step 7: Update `PhoneAuthViewModel`

Add `AppleAuthService` dependency and `signInWithApple()` method — identical pattern to `signInWithGoogle()`:

```dart
// Add import
import 'package:securityexperts_app/features/phone_auth/services/apple_auth_service.dart';

// Add field
final AppleAuthService _appleAuthService;

// In constructor, add:
AppleAuthService? appleAuthService,
// ... and assign:
_appleAuthService = appleAuthService ?? sl<AppleAuthService>();

/// Sign in with Apple identity
Future<bool> signInWithApple() async {
  _state = _state.copyWith(isLoading: true, clearError: true);
  notifyListeners();

  final trace = sl<AnalyticsService>().newTrace('auth_apple_signin');
  await trace.start();

  try {
    final userCredential = await _appleAuthService.signInWithApple();

    if (userCredential == null) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      await trace.stop();
      return false;
    }

    final user = userCredential.user;
    if (user == null) {
      _state = _state.copyWith(isLoading: false, error: 'Apple authentication failed.');
      notifyListeners();
      await trace.stop();
      return false;
    }

    // Same profile check flow as Google sign-in
    bool success = false;
    await ErrorHandler.handle<void>(
      operation: () async {
        final userProfile = await _userRepository.getCurrentUserProfile();
        if (userProfile != null) {
          UserProfileService().setUserProfile(userProfile);
          // ... analytics, token init (same as Google)
          trace.putAttribute('user_type', 'existing');
          AuthAnalytics.loginComplete(method: 'apple', isNewUser: false);
          await _initializeTokenServices(user.uid);
        } else {
          trace.putAttribute('user_type', 'new');
          AuthAnalytics.loginComplete(method: 'apple', isNewUser: true);
        }
        _state = _state.copyWith(isLoading: false, error: null);
        notifyListeners();
        success = true;
      },
    );

    await trace.stop();
    return success;
  } catch (e) {
    _log?.error('Apple Sign-In error: $e', tag: _tag);
    await trace.stop();
    _state = _state.copyWith(isLoading: false, error: 'Apple sign-in failed. Please try again.');
    notifyListeners();
    return false;
  }
}
```

---

### Step 8: Update `phone_auth_screen.dart` UI

Add "Continue with Apple" button directly below the Google button (only show on iOS at minimum — Apple requires it):

```dart
SizedBox(height: AppSpacing.spacing12),

// Apple Sign-In Button
SizedBox(
  width: double.infinity,
  height: 50,
  child: OutlinedButton.icon(
    onPressed: state.isLoading ? null : _handleAppleSignIn,
    icon: const Icon(Icons.apple, size: 28),
    label: Text(
      'Continue with Apple',
      style: AppTypography.bodyRegular.copyWith(
        color: AppColors.textPrimary,
      ),
    ),
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: AppColors.surface,
    ),
  ),
),
```

Add handler method (same pattern as `_handleGoogleSignIn`):

```dart
Future<void> _handleAppleSignIn() async {
  final viewModel = context.read<PhoneAuthViewModel>();
  final success = await viewModel.signInWithApple();

  if (!mounted || !success) return;

  final profile = UserProfileService().userProfile;
  if (profile != null) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  } else {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UserOnboardingPage()),
    );
  }
}
```

---

### Step 9: Register in Service Locator

In `lib/core/service_locator.dart`:

```dart
// Import
import 'package:securityexperts_app/features/phone_auth/services/apple_auth_service.dart';

// Register (alongside GoogleAuthService)
sl.registerLazySingleton<AppleAuthService>(() => AppleAuthService());
```

---

### Step 10: Update `auth_provider.dart` Sign-Out

Add Apple sign-out alongside Google:

```dart
import 'package:securityexperts_app/features/phone_auth/services/apple_auth_service.dart';

// In signOut() method, after Google sign-out:
if (sl.isRegistered<AppleAuthService>()) {
  await sl<AppleAuthService>().signOut();
}
```

---

## Key Differences from Google Sign-In

| Aspect | Google | Apple |
|--------|--------|-------|
| **Package** | `google_sign_in` | `sign_in_with_apple` + `crypto` |
| **Native SDK config** | OAuth client IDs, URL schemes | Xcode capability + App ID entitlement |
| **Nonce** | Handled by SDK | Must generate + SHA-256 hash manually |
| **Display name** | Always available | Only sent on **first** sign-in ever |
| **Email** | Always available | User can choose to **hide** email (relay address) |
| **Local session** | `GoogleSignIn.instance.signOut()` | No local session to clear |
| **Android** | Native SDK | Falls back to web-based OAuth |
| **App Store requirement** | Optional | **Mandatory** if any social login is offered |
| **Firebase config** | OAuth client IDs | Service ID + `.p8` key (for web/Android only) |

---

## Apple-Specific Considerations

### 1. Display Name Only on First Sign-In
Apple sends `givenName` and `familyName` only the **very first time** a user authorizes the app. On repeat sign-ins, these fields are `null`. The service captures and persists the name to `FirebaseAuth.user.displayName` on first sign-in.

### 2. Email Privacy Relay
Users can choose "Hide My Email", giving your app a relay address like `abc123@privaterelay.appleid.com`. This still works for authentication but the email is not the user's real one. The onboarding flow should not assume the email is reachable for direct contact.

### 3. App Store Review Requirement
Per [App Store Review Guideline 4.8](https://developer.apple.com/app-store/review/guidelines/#sign-in-with-apple): any app that offers Google Sign-In (or any third-party social login) **must** also offer Sign in with Apple. This is a hard requirement for App Store approval.

### 4. Account Deletion Compliance
Apple requires apps supporting Sign in with Apple to also support [account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/). The existing `AccountCleanupService` and `deleteAccount` flow should cover this, but verify the Apple token is revoked via `FirebaseAuth.revokeTokenWithAuthorizationCode()` if needed.

---

## Testing Checklist

- [ ] iOS: Apple Sign-In button appears, opens native Apple sheet
- [ ] iOS: Cancel returns to login screen (no error)
- [ ] iOS: Successful sign-in → new user goes to onboarding
- [ ] iOS: Successful sign-in → existing user goes to home
- [ ] iOS: Display name captured on first sign-in
- [ ] iOS: Repeat sign-in works (name fields nil)
- [ ] iOS: Hidden email relay works correctly
- [ ] Web: Apple Sign-In popup flow works (if web enabled)
- [ ] Android: Apple Sign-In web fallback works (if Android enabled)
- [ ] Sign out clears Firebase session
- [ ] Analytics events fire with `method: 'apple'`
- [ ] Account deletion works for Apple-authenticated users

---

## Estimated Effort

| Task | Time |
|------|------|
| Apple Developer Console + Firebase setup | 30 min |
| Xcode capability | 5 min |
| `AppleAuthService` implementation | 1 hour |
| ViewModel + UI updates | 30 min |
| Service locator + auth provider | 10 min |
| Testing (iOS + web) | 1 hour |
| **Total** | **~3 hours** |
