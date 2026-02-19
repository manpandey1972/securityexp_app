import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:greenhive_app/data/repositories/user/user_repository.dart';
import 'package:greenhive_app/shared/services/user_profile_service.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/shared/services/firebase_messaging_service.dart';
import 'package:greenhive_app/features/chat/services/user_presence_service.dart';
import 'package:greenhive_app/features/calling/infrastructure/repositories/voip_token_repository.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/features/phone_auth/presentation/state/phone_auth_state.dart';
import 'package:greenhive_app/constants/app_strings.dart';
import 'package:greenhive_app/core/analytics/auth_analytics.dart';
import 'package:greenhive_app/core/analytics/analytics_service.dart';

/// Phone authentication view model
///
/// Manages all business logic for phone authentication:
/// - Phone number validation
/// - OTP sending and verification
/// - State management
class PhoneAuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth;
  final UserRepository _userRepository;

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
  }) : _auth = auth,
       _userRepository = userRepository;

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

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _state.verificationId,
        smsCode: _state.otpCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Authentication failed',
        );
        notifyListeners();
        return;
      }

      // Get ID token
      final idToken = await user.getIdToken();
      if (idToken == null) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Could not get authentication token',
        );
        notifyListeners();
        return;
      }

      // Fetch user profile to check if exists
      await ErrorHandler.handle<void>(
        operation: () async {
          final userProfile = await _userRepository.getCurrentUserProfile();

          if (userProfile != null) {
            // Profile exists - store and signal success
            UserProfileService().setUserProfile(userProfile);
            
            // Set user context for analytics (user properties + Crashlytics)
            if (sl.isRegistered<AnalyticsService>()) {
              sl<AnalyticsService>().setUserOnLogin(
                userId: user.uid,
                isExpert: userProfile.roles.contains('Expert'),
                accountCreatedAt: userProfile.createdTime?.toDate(),
              );
            }
            
            // Update last login timestamp
            await _userRepository.updateLastLogin();
            
            // Track login success
            trace.putAttribute('user_type', 'existing');
            await trace.stop();
            
            AuthAnalytics.loginComplete(
              method: 'phone',
              isNewUser: false,
            );
            
            // Initialize FCM and VoIP tokens for existing user
            // This is safe because we confirmed the user document exists
            await _initializeTokenServices(user.uid);
            
            _state = _state.copyWith(isLoading: false, error: null);
          } else {
            // Profile doesn't exist yet - will navigate to onboarding
            // Track as new user signup start
            trace.putAttribute('user_type', 'new');
            await trace.stop();
            
            AuthAnalytics.otpVerified(success: true);
            _state = _state.copyWith(isLoading: false, error: null);
          }
          notifyListeners();
        },
      );
    } catch (e) {
      _log?.error('Error verifying OTP: $e', tag: _tag);
      // Track OTP verification failure
      await trace.stop();
      AuthAnalytics.otpVerified(
        success: false,
        errorType: e.runtimeType.toString(),
      );
      _state = _state.copyWith(
        isLoading: false,
        error: 'Invalid OTP. Please try again.',
      );
      notifyListeners();
    }
  }

  /// Reset to phone entry step
  void resetToPhoneEntry() {
    _state = const PhoneAuthState();
    notifyListeners();
  }

  /// Handle auto-verification completion
  Future<void> _handleVerificationCompleted(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        _state = _state.copyWith(
          error: 'Authentication failed',
          isLoading: false,
        );
        notifyListeners();
        return;
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        _state = _state.copyWith(
          error: 'Could not get authentication token',
          isLoading: false,
        );
        notifyListeners();
        return;
      }

      SnackbarService.show('Phone verified automatically');

      // Fetch user profile
      await ErrorHandler.handle<void>(
        operation: () async {
          final userProfile = await _userRepository.getCurrentUserProfile();

          if (userProfile != null) {
            UserProfileService().setUserProfile(userProfile);
            _state = _state.copyWith(isLoading: false, error: null);
          } else {
            _state = _state.copyWith(isLoading: false, error: null);
          }
          notifyListeners();
        },
      );
    } catch (e) {
      _log?.error('Error in verification completed: $e', tag: _tag);
      _state = _state.copyWith(
        error: 'Verification failed: $e',
        isLoading: false,
      );
      notifyListeners();
    }
  }

  /// Handle verification failure
  void _handleVerificationFailed(FirebaseAuthException e) {
    _log?.error('Verification failed: ${e.message}', tag: _tag);
    _state = _state.copyWith(
      isLoading: false,
      error: e.message ?? 'Verification failed. Please try again.',
      inOtpStep: false,
    );
    notifyListeners();
  }
}
