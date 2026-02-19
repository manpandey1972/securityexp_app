/// Phone authentication state model
///
/// Immutable state container for phone authentication page
class PhoneAuthState {
  /// The phone number entered by user (without formatting)
  final String phoneNumber;

  /// Selected country code
  final String selectedCountryCode;

  /// Selected country dial code (e.g., +1, +91)
  final String selectedCountryDialCode;

  /// Verification ID from Firebase
  final String verificationId;

  /// Whether OTP has been sent
  final bool codeSent;

  /// Whether currently loading (sending OTP or verifying)
  final bool isLoading;

  /// Whether the entered phone number is valid
  final bool isPhoneValid;

  /// OTP code entered by user
  final String otpCode;

  /// Error message, if any
  final String? error;

  /// Whether in the OTP verification step
  final bool inOtpStep;

  const PhoneAuthState({
    this.phoneNumber = '',
    this.selectedCountryCode = 'US',
    this.selectedCountryDialCode = '+1',
    this.verificationId = '',
    this.codeSent = false,
    this.isLoading = false,
    this.isPhoneValid = false,
    this.otpCode = '',
    this.error,
    this.inOtpStep = false,
  });

  /// Create a copy of this state with optional new values
  PhoneAuthState copyWith({
    String? phoneNumber,
    String? selectedCountryCode,
    String? selectedCountryDialCode,
    String? verificationId,
    bool? codeSent,
    bool? isLoading,
    bool? isPhoneValid,
    String? otpCode,
    String? error,
    bool? inOtpStep,
    bool clearError = false,
  }) {
    return PhoneAuthState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      selectedCountryCode: selectedCountryCode ?? this.selectedCountryCode,
      selectedCountryDialCode:
          selectedCountryDialCode ?? this.selectedCountryDialCode,
      verificationId: verificationId ?? this.verificationId,
      codeSent: codeSent ?? this.codeSent,
      isLoading: isLoading ?? this.isLoading,
      isPhoneValid: isPhoneValid ?? this.isPhoneValid,
      otpCode: otpCode ?? this.otpCode,
      error: clearError ? null : (error ?? this.error),
      inOtpStep: inOtpStep ?? this.inOtpStep,
    );
  }

  @override
  String toString() {
    return 'PhoneAuthState(phone: $phoneNumber, country: $selectedCountryCode, '
        'codeSent: $codeSent, isLoading: $isLoading, valid: $isPhoneValid, '
        'inOtpStep: $inOtpStep, error: $error)';
  }
}
