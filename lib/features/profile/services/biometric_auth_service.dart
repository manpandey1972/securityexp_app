import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';

class BiometricAuthService {
  static final BiometricAuthService _instance =
      BiometricAuthService._internal();

  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Check if the device supports biometrics
  Future<bool> canUseBiometrics() async {
    if (kIsWeb) return false;
    return await ErrorHandler.handle<bool>(
      operation: () async {
        final canCheck = await _auth.canCheckBiometrics;
        return canCheck;
      },
      fallback: false,
    );
  }

  /// Check if device is capable and has biometrics enrolled
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    return await ErrorHandler.handle<bool>(
      operation: () async {
        final canCheck = await _auth.canCheckBiometrics;
        if (!canCheck) {
          return false;
        }

        final availableBiometrics = await _auth.getAvailableBiometrics();
        return availableBiometrics.isNotEmpty;
      },
      fallback: false,
    );
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    return await ErrorHandler.handle<List<BiometricType>>(
      operation: () async {
        final biometrics = await _auth.getAvailableBiometrics();
        return biometrics;
      },
      fallback: [],
    );
  }

  /// Check if biometric authentication is enabled in settings
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_biometricEnabledKey) ?? false;
    return enabled;
  }

  /// Enable biometric authentication
  Future<void> enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, true);
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, false);
  }

  /// Authenticate user with biometrics
  ///
  /// Throws [PlatformException] if biometric couldn't be shown (e.g., CallKit active).
  /// Returns true if authenticated, false if user cancelled or failed.
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access Greenhive',
    bool biometricOnly = false,
  }) async {
    if (kIsWeb) return false;

    // Don't use ErrorHandler here - let PlatformException propagate
    // so callers can distinguish between "failed" vs "couldn't show"
    final result = await _auth.authenticate(
      localizedReason: localizedReason,
      options: AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: biometricOnly,
      ),
    );
    return result;
  }

  /// Get biometric type name for display
  Future<String> getBiometricTypeName() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.isEmpty) return 'Biometric';

    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Touch ID';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }
}
