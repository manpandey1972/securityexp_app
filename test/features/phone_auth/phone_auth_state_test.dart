import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/features/phone_auth/presentation/state/phone_auth_state.dart';

void main() {
  group('PhoneAuthState', () {
    test('default constructor has expected defaults', () {
      const state = PhoneAuthState();
      expect(state.phoneNumber, '');
      expect(state.selectedCountryCode, 'US');
      expect(state.selectedCountryDialCode, '+1');
      expect(state.verificationId, '');
      expect(state.codeSent, false);
      expect(state.isLoading, false);
      expect(state.isPhoneValid, false);
      expect(state.otpCode, '');
      expect(state.error, isNull);
      expect(state.inOtpStep, false);
    });

    test('constructor accepts custom values', () {
      const state = PhoneAuthState(
        phoneNumber: '1234567890',
        selectedCountryCode: 'IN',
        selectedCountryDialCode: '+91',
        verificationId: 'vid-123',
        codeSent: true,
        isLoading: true,
        isPhoneValid: true,
        otpCode: '654321',
        error: 'Some error',
        inOtpStep: true,
      );

      expect(state.phoneNumber, '1234567890');
      expect(state.selectedCountryCode, 'IN');
      expect(state.selectedCountryDialCode, '+91');
      expect(state.verificationId, 'vid-123');
      expect(state.codeSent, true);
      expect(state.isLoading, true);
      expect(state.isPhoneValid, true);
      expect(state.otpCode, '654321');
      expect(state.error, 'Some error');
      expect(state.inOtpStep, true);
    });

    group('copyWith', () {
      test('returns identical state when no arguments given', () {
        const original = PhoneAuthState(
          phoneNumber: '555',
          selectedCountryCode: 'GB',
          selectedCountryDialCode: '+44',
          verificationId: 'v1',
          codeSent: true,
          isLoading: true,
          isPhoneValid: true,
          otpCode: '123456',
          error: 'err',
          inOtpStep: true,
        );

        final copy = original.copyWith();
        expect(copy.phoneNumber, original.phoneNumber);
        expect(copy.selectedCountryCode, original.selectedCountryCode);
        expect(copy.selectedCountryDialCode, original.selectedCountryDialCode);
        expect(copy.verificationId, original.verificationId);
        expect(copy.codeSent, original.codeSent);
        expect(copy.isLoading, original.isLoading);
        expect(copy.isPhoneValid, original.isPhoneValid);
        expect(copy.otpCode, original.otpCode);
        expect(copy.error, original.error);
        expect(copy.inOtpStep, original.inOtpStep);
      });

      test('overrides individual fields', () {
        const original = PhoneAuthState();
        final updated = original.copyWith(
          phoneNumber: '9876543210',
          isLoading: true,
        );

        expect(updated.phoneNumber, '9876543210');
        expect(updated.isLoading, true);
        // Unchanged fields remain default
        expect(updated.selectedCountryCode, 'US');
        expect(updated.codeSent, false);
      });

      test('clearError sets error to null', () {
        const state = PhoneAuthState(error: 'something went wrong');
        final cleared = state.copyWith(clearError: true);
        expect(cleared.error, isNull);
      });

      test('clearError takes precedence over new error value', () {
        const state = PhoneAuthState(error: 'old');
        final cleared = state.copyWith(error: 'new', clearError: true);
        expect(cleared.error, isNull);
      });

      test('setting error without clearError preserves new error', () {
        const state = PhoneAuthState(error: 'old');
        final updated = state.copyWith(error: 'new');
        expect(updated.error, 'new');
      });
    });

    test('toString contains key fields', () {
      const state = PhoneAuthState(
        phoneNumber: '555',
        selectedCountryCode: 'US',
        codeSent: true,
        isLoading: false,
        isPhoneValid: true,
        inOtpStep: false,
        error: null,
      );

      final str = state.toString();
      expect(str, contains('phone: 555'));
      expect(str, contains('country: US'));
      expect(str, contains('codeSent: true'));
      expect(str, contains('isLoading: false'));
      expect(str, contains('valid: true'));
      expect(str, contains('inOtpStep: false'));
    });
  });
}
