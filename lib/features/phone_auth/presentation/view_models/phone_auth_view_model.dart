import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/firebase_messaging_service.dart';
import 'package:securityexperts_app/features/chat/services/user_presence_service.dart';
import 'package:securityexperts_app/features/calling/infrastructure/repositories/voip_token_repository.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/features/phone_auth/presentation/state/phone_auth_state.dart';
import 'package:securityexperts_app/features/phone_auth/services/google_auth_service.dart';
import 'package:securityexperts_app/features/phone_auth/services/apple_auth_service.dart';
import 'package:securityexperts_app/constants/app_strings.dart';
import 'package:securityexperts_app/core/analytics/auth_analytics.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';

/// Phone authentication view model
///
/// Manages all business logic for phone authentication:
/// - Phone number validation
/// - OTP sending and verification
/// - State management
class PhoneAuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth;
  final UserRepository _userRepository;
  final GoogleAuthService _googleAuthService;
  final AppleAuthService _appleAuthService;

  PhoneAuthState _state = const PhoneAuthState();
  PhoneAuthState get state => _state;

  // Phone validation lengths by country code
  static const Map<String, int> phoneLengthsByDialCode = {
    '+1': 10, // US, Canada
    '+44': 10, // UK
    '+61': 9, // Australia
    '+81': 10, // Japan
    '+86': 11, // China
    '+91': 10, // India
    '+55': 11, // Brazil
    '+33': 9, // France
    '+49': 11, // Germany
    '+39': 10, // Italy
    '+34': 9, // Spain
    '+82': 10, // South Korea
    '+7': 10, // Russia
    '+92': 10, // Pakistan
    '+880': 10, // Bangladesh
    '+234': 10, // Nigeria
    '+27': 9, // South Africa
    '+65': 8, // Singapore
    '+60': 9, // Malaysia
    '+66': 9, // Thailand
    '+84': 9, // Vietnam
    '+62': 9, // Indonesia
    '+63': 10, // Philippines
    '+971': 9, // UAE
    '+966': 9, // Saudi Arabia
    '+20': 10, // Egypt
    '+54': 10, // Argentina
    '+56': 9, // Chile
  };

  AppLogger? get _log => sl.isRegistered<AppLogger>() ? sl<AppLogger>() : null;
  static const String _tag = 'PhoneAuthViewModel';

  PhoneAuthViewModel({
    required FirebaseAuth auth,
    required UserRepository userRepository,
    GoogleAuthService? googleAuthService,
    AppleAuthService? appleAuthService,
  }) : _auth = auth,
       _userRepository = userRepository,
       _googleAuthService = googleAuthService ?? sl<GoogleAuthService>(),
       _appleAuthService = appleAuthService ?? sl<AppleAuthService>();

  /// Initialize FCM and VoIP token services for existing users
  Future<void> _initializeTokenServices(String userId) async {
    // Initialize user presence for push notification suppression
    try {
      await sl<UserPresenceService>().initialize();
    } catch (e) {
      _log?.error('Failed to initialize user presence: $e', tag: _tag);
    }
    
    // Initialize FCM for push notifications
    try {
      await sl<FirebaseMessagingService>().initialize(userId);
      _log?.debug('FCM initialized successfully for user: $userId', tag: _tag);
    } catch (e) {
      _log?.error('Failed to initialize FCM: $e', tag: _tag);
    }
    
    // Initialize VoIP tokens for iOS CallKit push
    try {
      await sl<VoIPTokenRepository>().initialize(userId);
      _log?.debug('VoIP token sync initialized for user: $userId', tag: _tag);
    } catch (e) {
      _log?.error('Failed to initialize VoIP token sync: $e', tag: _tag);
    }
  }

  /// Update phone number and validate
  void setPhoneNumber(String phone) {
    _state = _state.copyWith(
      phoneNumber: phone,
      isPhoneValid: _validatePhoneNumber(phone),
    );
    notifyListeners();
  }

  /// Update selected country
  void setSelectedCountry(String countryCode, String dialCode) {
    _state = _state.copyWith(
      selectedCountryCode: countryCode,
      selectedCountryDialCode: dialCode,
      isPhoneValid: _validatePhoneNumber(_state.phoneNumber),
    );
    notifyListeners();
  }

  /// Update OTP code
  void setOtpCode(String otp) {
    _state = _state.copyWith(otpCode: otp, clearError: true);
    notifyListeners();
  }

  /// Validate phone number format based on country
  bool _validatePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;

    // Remove all non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Get expected length for selected country
    final expectedLength =
        phoneLengthsByDialCode[_state.selectedCountryDialCode] ?? 10;

    // Must have correct digit length
    if (digitsOnly.length != expectedLength) return false;

    // Must only contain digits
    if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) return false;

    return true;
  }

  /// Get phone number hint text based on country
  String getPhoneNumberHint() {
    return AppStrings.enterPhoneNumber;
  }

  /// Send OTP to phone number
  Future<void> sendOtp() async {
    // Validate phone number
    if (_state.phoneNumber.isEmpty) {
      _state = _state.copyWith(error: AppStrings.phoneRequired);
      notifyListeners();
      return;
    }

    if (!_state.isPhoneValid) {
      final expectedLength =
          phoneLengthsByDialCode[_state.selectedCountryDialCode] ?? 10;
      _state = _state.copyWith(
        error:
            'Enter a valid ${_state.selectedCountryCode} number ($expectedLength digits)',
      );
      notifyListeners();
      return;
    }

    // Track phone number entered
    AuthAnalytics.phoneEntered(
      countryCode: _state.selectedCountryCode,
    );

    // Set loading state
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final fullPhoneNumber =
          _state.selectedCountryDialCode +
          _state.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Track OTP request
      AuthAnalytics.otpRequested(method: 'sms');

      // Add timeout to prevent infinite hanging
      final verifyPhoneNumberFuture = _auth.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _handleVerificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _handleVerificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _state = _state.copyWith(
            verificationId: verificationId,
            codeSent: true,
            isLoading: false,
            inOtpStep: true,
            clearError: true,
          );
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _state = _state.copyWith(
            verificationId: verificationId,
            isLoading: false,
          );
          notifyListeners();
        },
        timeout: const Duration(seconds: 120),
      );

      // Wait for verification with timeout
      await verifyPhoneNumberFuture.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          _log?.warning('Phone verification timeout', tag: _tag);
          _state = _state.copyWith(
            isLoading: false,
            error: 'Phone verification timed out. Please try again.',
          );
          notifyListeners();
        },
      );
    } catch (e) {
      _log?.error('Error sending OTP: $e', tag: _tag);
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to send OTP. Please try again.',
      );
      notifyListeners();
    }
  }

  /// Verify OTP code
  Future<void> verifyOtp() async {
    if (_state.otpCode.isEmpty) {
      _state = _state.copyWith(error: AppStrings.otpRequired);
      notifyListeners();
      return;
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final trace = sl<AnalyticsService>().newTrace('auth_otp_verification');
    await trace.start();

    // ── Step 1: OTP credential verification ─────────────────────────────
    // Keep this in its own try-catch so we can show "Invalid OTP" ONLY for
    // actual credential failures, not for post-auth network/Firestore errors.
    //
    // RACE NOTE: On Android with Play Integrity working (typical outside the
    // US too — Play Integrity validates silently with no reCAPTCHA), the
    // SMS Retriever API can fire `verificationCompleted` automatically the
    // moment the SMS arrives. That callback calls `signInWithCredential` and
    // persists the session BEFORE the user finishes tapping Verify. When
    // the user then taps Verify, this manual `signInWithCredential` runs
    // with a verificationId that has already been consumed and Firebase
    // throws `FirebaseAuthException` — even though the user is already
    // signed in. We detect that by re-checking `_auth.currentUser` and
    // continue with the post-auth setup instead of showing "Invalid OTP".
    User? signedInUser;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _state.verificationId,
        smsCode: _state.otpCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      signedInUser = userCredential.user;
    } on FirebaseAuthException catch (e) {
      // If the concurrent auto-verification path already signed the user in,
      // honour that and don't surface a misleading "Invalid OTP".
      final existing = _auth.currentUser;
      if (existing != null) {
        _log?.warning(
          'signInWithCredential threw ${e.code} but currentUser is set '
          '(uid=${existing.uid}); treating as success',
          tag: _tag,
        );
        signedInUser = existing;
      } else {
        _log?.error('OTP credential failed: code=${e.code}', tag: _tag);
        await trace.stop();
        AuthAnalytics.otpVerified(success: false, errorType: e.code);
        _state = _state.copyWith(
          isLoading: false,
          error: 'Invalid OTP. Please try again.',
        );
        notifyListeners();
        return;
      }
    } catch (e) {
      // Same defensive check for non-Firebase exceptions: if the parallel
      // path already authenticated us, run the post-auth flow.
      final existing = _auth.currentUser;
      if (existing != null) {
        _log?.warning(
          'signInWithCredential threw $e but currentUser is set; '
          'treating as success',
          tag: _tag,
        );
        signedInUser = existing;
      } else {
        _log?.error('Unexpected error during sign-in: $e', tag: _tag);
        await trace.stop();
        _state = _state.copyWith(
          isLoading: false,
          error: 'Sign-in failed. Please try again.',
        );
        notifyListeners();
        return;
      }
    }

    if (signedInUser == null) {
      await trace.stop();
      _state = _state.copyWith(
        isLoading: false,
        error: 'Authentication failed',
      );
      notifyListeners();
      return;
    }

    // ── Step 2: Post-auth setup ──────────────────────────────────────────
    await _completePostAuthSetup(signedInUser, trace);
  }

  /// Run the post-authentication setup that's shared between the manual
  /// `verifyOtp` path and the Android auto-verification path
  /// (`_handleVerificationCompleted`).
  ///
  /// Failures here do NOT roll back the auth state — the session is already
  /// persisted by Firebase Auth, so we show a clear "setup failed" message
  /// rather than a misleading "Invalid OTP".
  Future<void> _completePostAuthSetup(User user, dynamic trace) async {
    try {
      final idToken = await user.getIdToken();
      if (idToken == null) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Could not get authentication token',
        );
        notifyListeners();
        return;
      }

      final userProfile = await _userRepository.getCurrentUserProfile();

      if (userProfile != null) {
        // Existing user — store profile and finalize login.
        sl<UserProfileService>().setUserProfile(userProfile);

        if (sl.isRegistered<AnalyticsService>()) {
          sl<AnalyticsService>().setUserOnLogin(
            userId: user.uid,
            isExpert: userProfile.roles.contains('Expert'),
            accountCreatedAt: userProfile.createdTime?.toDate(),
          );
        }

        await _userRepository.updateLastLogin();

        trace.putAttribute('user_type', 'existing');
        await trace.stop();

        AuthAnalytics.loginComplete(method: 'phone', isNewUser: false);

        // Initialize FCM and VoIP tokens for existing user.
        await _initializeTokenServices(user.uid);
      } else {
        // New user — navigate to onboarding.
        trace.putAttribute('user_type', 'new');
        await trace.stop();

        AuthAnalytics.otpVerified(success: true);
      }

      _state = _state.copyWith(isLoading: false, error: null);
      notifyListeners();
    } catch (e) {
      _log?.error('Post-auth setup failed: $e', tag: _tag);
      try {
        await trace.stop();
      } catch (_) {}
      // Auth DID succeed — session is already persisted to disk.
      // Don't say "Invalid OTP"; the user can kill+reopen the app and
      // will land in the correct screen automatically.
      _state = _state.copyWith(
        isLoading: false,
        error: 'Sign-in succeeded but setup failed. Please try again.',
      );
      notifyListeners();
    }
  }

  /// Reset to phone entry step
  void resetToPhoneEntry() {
    _state = const PhoneAuthState();
    notifyListeners();
  }

  /// Sign in with Google identity
  ///
  /// Handles the full Google Sign-In → Firebase Auth → profile check flow.
  /// Returns `true` if sign-in was successful, `false` if cancelled/failed.
  Future<bool> signInWithGoogle() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final trace = sl<AnalyticsService>().newTrace('auth_google_signin');
    await trace.start();

    try {
      final userCredential = await _googleAuthService.signInWithGoogle();

      if (userCredential == null) {
        // User cancelled
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
        await trace.stop();
        return false;
      }

      final user = userCredential.user;
      if (user == null) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Google authentication failed.',
        );
        notifyListeners();
        await trace.stop();
        return false;
      }

      // Fetch user profile to check if exists
      bool success = false;
      await ErrorHandler.handle<void>(
        operation: () async {
          final userProfile = await _userRepository.getCurrentUserProfile();

          if (userProfile != null) {
            sl<UserProfileService>().setUserProfile(userProfile);

            if (sl.isRegistered<AnalyticsService>()) {
              sl<AnalyticsService>().setUserOnLogin(
                userId: user.uid,
                isExpert: userProfile.roles.contains('Expert'),
                accountCreatedAt: userProfile.createdTime?.toDate(),
              );
            }

            await _userRepository.updateLastLogin();

            trace.putAttribute('user_type', 'existing');
            AuthAnalytics.loginComplete(method: 'google', isNewUser: false);

            await _initializeTokenServices(user.uid);
          } else {
            trace.putAttribute('user_type', 'new');
            AuthAnalytics.loginComplete(method: 'google', isNewUser: true);
          }

          _state = _state.copyWith(isLoading: false, error: null);
          notifyListeners();
          success = true;
        },
      );

      await trace.stop();
      return success;
    } catch (e) {
      _log?.error('Google Sign-In error: $e', tag: _tag);
      await trace.stop();

      String errorMessage = 'Google sign-in failed. Please try again.';
      if (e is FirebaseAuthException) {
        errorMessage = e.message ?? errorMessage;
      }

      _state = _state.copyWith(isLoading: false, error: errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Apple identity
  ///
  /// Handles the full Apple Sign-In → Firebase Auth → profile check flow.
  /// Returns `true` if sign-in was successful, `false` if cancelled/failed.
  Future<bool> signInWithApple() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final trace = sl<AnalyticsService>().newTrace('auth_apple_signin');
    await trace.start();

    try {
      final userCredential = await _appleAuthService.signInWithApple();

      if (userCredential == null) {
        // User cancelled
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
        await trace.stop();
        return false;
      }

      final user = userCredential.user;
      if (user == null) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Apple authentication failed.',
        );
        notifyListeners();
        await trace.stop();
        return false;
      }

      // Fetch user profile to check if exists
      bool success = false;
      await ErrorHandler.handle<void>(
        operation: () async {
          final userProfile = await _userRepository.getCurrentUserProfile();

          if (userProfile != null) {
            sl<UserProfileService>().setUserProfile(userProfile);

            if (sl.isRegistered<AnalyticsService>()) {
              sl<AnalyticsService>().setUserOnLogin(
                userId: user.uid,
                isExpert: userProfile.roles.contains('Expert'),
                accountCreatedAt: userProfile.createdTime?.toDate(),
              );
            }

            await _userRepository.updateLastLogin();

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
        onError: (error) {
          _log?.error('Apple Sign-In post-auth error: $error', tag: _tag);
          _state = _state.copyWith(isLoading: false, error: error);
          notifyListeners();
        },
      );

      await trace.stop();
      return success;
    } catch (e) {
      _log?.error('Apple Sign-In error: $e', tag: _tag);
      await trace.stop();

      String errorMessage = 'Apple sign-in failed. Please try again.';
      if (e is FirebaseAuthException) {
        errorMessage = e.message ?? errorMessage;
      }

      _state = _state.copyWith(isLoading: false, error: errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Handle auto-verification completion
  ///
  /// On Android with Play Integrity working, this fires automatically as
  /// soon as the SMS arrives — without the user having to tap Verify. We
  /// run the same post-auth setup as the manual path so the screen can
  /// navigate (the screen widget observes the same `error == null` +
  /// `isLoading == false` transition).
  Future<void> _handleVerificationCompleted(
    PhoneAuthCredential credential,
  ) async {
    final trace = sl<AnalyticsService>().newTrace('auth_otp_verification');
    await trace.start();
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        await trace.stop();
        _state = _state.copyWith(
          error: 'Authentication failed',
          isLoading: false,
        );
        notifyListeners();
        return;
      }
      SnackbarService.show('Phone verified automatically');
      await _completePostAuthSetup(user, trace);
    } catch (e) {
      _log?.error('Error in verification completed: $e', tag: _tag);
      try {
        await trace.stop();
      } catch (_) {}
      _state = _state.copyWith(
        error: 'Verification failed: $e',
        isLoading: false,
      );
      notifyListeners();
    }
  }

  /// Handle verification failure
  void _handleVerificationFailed(FirebaseAuthException e) {
    _log?.error('Verification failed: code=${e.code} message=${e.message}', tag: _tag);
    _state = _state.copyWith(
      isLoading: false,
      error: '[${e.code}] ${e.message ?? 'Verification failed. Please try again.'}',
      inOtpStep: false,
    );
    notifyListeners();
  }
}
