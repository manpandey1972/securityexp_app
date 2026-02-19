import 'package:greenhive_app/core/analytics/analytics_service.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Analytics events for authentication flow.
///
/// Tracks user journey through phone verification and signup.
class AuthAnalytics {
  static AnalyticsService get _analytics => sl<AnalyticsService>();

  /// User entered their phone number
  static Future<void> phoneEntered({
    String? countryCode,
  }) async {
    await _analytics.logEvent(
      'auth_enter_phone',
      parameters: {
        if (countryCode != null) 'country_code': countryCode,
      },
    );
  }

  /// OTP was requested (SMS sent)
  static Future<void> otpRequested({
    String? method, // 'sms', 'whatsapp', etc.
  }) async {
    await _analytics.logEvent(
      'auth_request_otp',
      parameters: {
        if (method != null) 'method': method,
      },
    );
  }

  /// OTP verification completed
  static Future<void> otpVerified({
    required bool success,
    String? errorType,
  }) async {
    await _analytics.logEvent(
      'auth_verify_otp',
      parameters: {
        'success': success,
        if (errorType != null) 'error_type': errorType,
      },
    );
  }

  /// New user completed signup
  static Future<void> signupComplete() async {
    await _analytics.logEvent('auth_signup_complete');
  }

  /// Existing user logged in
  static Future<void> loginComplete({
    String? method, // 'phone', 'biometric', etc.
    bool isNewUser = false,
  }) async {
    await _analytics.logEvent(
      'auth_login_complete',
      parameters: {
        if (method != null) 'method': method,
        'is_new_user': isNewUser,
      },
    );
  }

  /// User logged out
  static Future<void> logout() async {
    await _analytics.logEvent('auth_logout');
  }

  /// Biometric authentication attempted
  static Future<void> biometricAttempted({
    required bool success,
    required String biometricType, // 'fingerprint', 'face', 'iris'
  }) async {
    await _analytics.logEvent(
      'auth_biometric_attempt',
      parameters: {
        'success': success,
        'biometric_type': biometricType,
      },
    );
  }

  /// Session expired or refreshed
  static Future<void> sessionEvent({
    required String event, // 'expired', 'refreshed', 'invalid'
  }) async {
    await _analytics.logEvent(
      'auth_session_event',
      parameters: {'event': event},
    );
  }
}
