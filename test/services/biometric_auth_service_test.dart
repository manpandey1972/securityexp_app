import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:securityexperts_app/features/profile/services/biometric_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricAuthService', () {
    late BiometricAuthService service;

    setUp(() {
      service = BiometricAuthService();
    });

    group('canUseBiometrics', () {
      test(
        'should return true when device can check biometrics',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );

      test(
        'should return false on web platform',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );
    });

    group('isBiometricAvailable', () {
      test(
        'should return true when biometrics are available',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );

      test(
        'should return false when no biometrics enrolled',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );
    });

    group('getAvailableBiometrics', () {
      test(
        'should return list of available biometric types',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );

      test(
        'should return empty list on web platform',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );
    });

    group('Biometric Settings', () {
      test('isBiometricEnabled should return stored preference', () async {
        SharedPreferences.setMockInitialValues({'biometric_enabled': true});

        final result = await service.isBiometricEnabled();
        expect(result, true);
      });

      test('enableBiometric should save preference', () async {
        SharedPreferences.setMockInitialValues({});

        await service.enableBiometric();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('biometric_enabled'), true);
      });

      test('disableBiometric should save preference', () async {
        SharedPreferences.setMockInitialValues({'biometric_enabled': true});

        await service.disableBiometric();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('biometric_enabled'), false);
      });
    });

    group('authenticate', () {
      test(
        'should return false on web platform',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );

      test(
        'should use default localized reason',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );

      test(
        'should accept custom localized reason',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );

      test(
        'should support biometric only mode',
        () async {
          // Skip - requires platform plugin mocking
        },
        skip: 'Requires local_auth plugin mock',
      );
    });

    group('getBiometricTypeName', () {
      test(
        'should return string for biometric type',
        () async {
          // Skip - requires platform plugin mocking and service locator setup
        },
        skip: 'Requires local_auth plugin mock',
      );
    });
  });
}
