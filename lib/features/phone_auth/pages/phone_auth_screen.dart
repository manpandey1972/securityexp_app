import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:securityexperts_app/features/onboarding/pages/user_onboarding_page.dart';
import 'package:securityexperts_app/features/onboarding/pages/eula_page.dart';
import 'package:securityexperts_app/features/home/pages/home_page.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/phone_auth/presentation/view_models/phone_auth_view_model.dart';
import 'package:securityexperts_app/features/phone_auth/presentation/state/phone_auth_state.dart';
import 'package:securityexperts_app/constants/app_strings.dart';

// Phone number formatter for readable input — enforces a per-country digit cap
class PhoneNumberFormatter extends TextInputFormatter {
  final int maxDigits;

  const PhoneNumberFormatter({this.maxDigits = 15});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Keep only digits and clamp to the country's expected length
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final limited = digitsOnly.length > maxDigits
        ? digitsOnly.substring(0, maxDigits)
        : digitsOnly;

    // Format with spaces at positions 3 and 6 for readability
    String formatted = '';
    for (int i = 0; i < limited.length; i++) {
      if (i == 3 || i == 6) {
        formatted += ' ';
      }
      formatted += limited[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PhoneAuthPage extends StatelessWidget {
  const PhoneAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<PhoneAuthViewModel>(),
      child: const _PhoneAuthPageView(),
    );
  }
}

class _PhoneAuthPageView extends StatefulWidget {
  const _PhoneAuthPageView();

  @override
  State<_PhoneAuthPageView> createState() => _PhoneAuthPageViewState();
}

class _PhoneAuthPageViewState extends State<_PhoneAuthPageView> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());
  bool _isAutoSubmitting = false;
  // Prevents re-entrant onChanged calls while _distributeOtp sets controllers
  bool _isDistributing = false;
  // Ensures the first OTP box is focused exactly once when the OTP step loads
  bool _otpStepFocusRequested = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      context.read<PhoneAuthViewModel>().setPhoneNumber(_phoneController.text);
    });
    // Backup listener: catches autofill events on iOS that bypass onChanged
    _otpControllers[0].addListener(_onBox0ControllerChanged);
    // Backspace on an empty box moves focus to the previous box
    for (int i = 0; i < 6; i++) {
      final index = i;
      _otpFocusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _otpControllers[index].text.isEmpty &&
            index > 0) {
          _otpFocusNodes[index - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpControllers[0].removeListener(_onBox0ControllerChanged);
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final viewModel = context.read<PhoneAuthViewModel>();
    await viewModel.sendOtp();
    // Clear OTP boxes and focus first box when OTP step begins
    if (mounted && viewModel.state.inOtpStep) {
      for (final c in _otpControllers) { c.clear(); }
      _isAutoSubmitting = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final viewModel = context.read<PhoneAuthViewModel>();

    // Set OTP code from the 6 boxes
    viewModel.setOtpCode(_otpValue);

    // Verify OTP
    await viewModel.verifyOtp();

    // After verification, check if we need to navigate
    if (!mounted) return;

    final newState = viewModel.state;
    if (newState.error != null) {
      // Clear all boxes and return focus to the first box so the user can retry
      for (final c in _otpControllers) { c.clear(); }
      _isAutoSubmitting = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
      return;
    }
    if (!newState.isLoading && newState.error == null) {
      // Successfully verified - gate EULA acceptance, then route based on profile.
      final profile = UserProfileService().userProfile;
      await EulaPage.showIfNeeded(
        context,
        profileTermsAcceptedAt: profile?.termsAcceptedAt,
        isNewUser: profile == null,
        onAccepted: () {
          if (!mounted) return;
          if (profile != null) {
            // Profile exists - navigate to home
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          } else {
            // No profile - navigate to onboarding
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const UserOnboardingPage()),
              (route) => false,
            );
          }
        },
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final viewModel = context.read<PhoneAuthViewModel>();
    final success = await viewModel.signInWithGoogle();

    if (!mounted || !success) return;

    // Successfully signed in - check if profile exists
    final profile = UserProfileService().userProfile;
    if (profile != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UserOnboardingPage()),
      );
    }
  }

  Future<void> _handleAppleSignIn() async {
    final viewModel = context.read<PhoneAuthViewModel>();
    final success = await viewModel.signInWithApple();

    if (!mounted || !success) return;

    final profile = UserProfileService().userProfile;
    if (profile != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UserOnboardingPage()),
      );
    }
  }

  String _getPhoneNumberHint(String countryCode) {
    switch (countryCode) {
      case 'US':
      case 'CA':
        return '123 456 7890';
      case 'GB':
        return '7400 123456';
      case 'IN':
        return '98765 43210';
      default:
        return 'Phone number';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DefaultTextStyle(
        style: AppTypography.bodyRegular,
        child: Consumer<PhoneAuthViewModel>(
          builder: (context, viewModel, _) {
            final state = viewModel.state;

            // Focus the first OTP box the moment the OTP step becomes visible
            if (state.inOtpStep && !_otpStepFocusRequested) {
              _otpStepFocusRequested = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _otpFocusNodes[0].requestFocus();
              });
            } else if (!state.inOtpStep) {
              _otpStepFocusRequested = false;
            }

            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!state.inOtpStep) ...[
                          // Phone Number Entry Section
                          Text(
                            'Enter Your Phone Number',
                            textAlign: TextAlign.center,
                            style: AppTypography.headingMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: AppSpacing.spacing32),

                          // Country Code Dropdown
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.divider),
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.surface,
                            ),
                            child: DropdownButton<CountryCodeItem>(
                              isExpanded: true,
                              value: _getSelectedCountry(state),
                              underline: const SizedBox(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              dropdownColor: AppColors.surface,
                              items: AppCountries.countries.map((
                                CountryCodeItem country,
                              ) {
                                return DropdownMenuItem<CountryCodeItem>(
                                  value: country,
                                  child: Text(
                                    '${country.name} (${country.dialCode})',
                                    style: AppTypography.bodyRegular,
                                  ),
                                );
                              }).toList(),
                              onChanged: (CountryCodeItem? newValue) {
                                if (newValue != null) {
                                  viewModel.setSelectedCountry(
                                    newValue.code,
                                    newValue.dialCode,
                                  );
                                }
                              },
                            ),
                          ),
                          SizedBox(height: AppSpacing.spacing20),

                          // Phone Number Input
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: AppTypography.headingSmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            inputFormatters: [
                              PhoneNumberFormatter(
                                maxDigits: PhoneAuthViewModel
                                        .phoneLengthsByDialCode[
                                      state.selectedCountryDialCode] ??
                                    10,
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: _getPhoneNumberHint(
                                state.selectedCountryCode,
                              ),
                              prefixText: '${state.selectedCountryDialCode} ',
                              labelStyle: AppTypography.bodyRegular.copyWith(color: AppColors.textSecondary),
                              hintStyle: AppTypography.bodyRegular.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                          if (state.error != null) ...[
                            SizedBox(height: 6),
                            Text(
                              state.error!,
                              style: AppTypography.bodySmall.copyWith(color: Colors.red),
                              maxLines: 5,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                          SizedBox(height: AppSpacing.spacing24),

                          // Send OTP Button — border turns primary green once valid
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: (state.isLoading || !state.isPhoneValid)
                                  ? null
                                  : _handleSendOtp,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: state.isPhoneValid
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  width: 1.5,
                                ),
                                foregroundColor: state.isPhoneValid
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                              child: state.isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Send OTP',
                                      style: AppTypography.bodyEmphasis,
                                    ),
                            ),
                          ),

                          SizedBox(height: AppSpacing.spacing24),

                          // Divider with "OR"
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: AppColors.divider,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'OR',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: AppColors.divider,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: AppSpacing.spacing24),

                          // Google Sign-In Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed:
                                  state.isLoading ? null : _handleGoogleSignIn,
                              icon: Image.network(
                                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.png',
                                height: 24,
                                width: 24,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.g_mobiledata,
                                  size: 28,
                                ),
                              ),
                              label: Text(
                                'Continue with Google',
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

                          SizedBox(height: AppSpacing.spacing12),

                          // Apple Sign-In Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed:
                                  state.isLoading ? null : _handleAppleSignIn,
                              icon: const Icon(
                                Icons.apple,
                                size: 28,
                                color: Colors.white,
                              ),
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
                        ] else ...[
                          // OTP Verification Section
                          Text(
                            'Enter Verification Code',
                            textAlign: TextAlign.center,
                            style: AppTypography.headingMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: AppSpacing.spacing12),
                          Text(
                            'We sent a code to ${state.selectedCountryDialCode} ${state.phoneNumber}',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: AppSpacing.spacing32),

                          // 6-Box OTP Input — auto-submits on last digit
                          _buildOtpBoxes(viewModel, state),
                          if (state.error != null) ...[
                            SizedBox(height: AppSpacing.spacing8),
                            Text(
                              state.error!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                          if (state.isLoading) ...[
                            SizedBox(height: AppSpacing.spacing24),
                            const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  /// Backup listener for SMS autofill on iOS where the QuickType bar tap may
  /// set the controller value without going through onChanged.
  void _onBox0ControllerChanged() {
    final text = _otpControllers[0].text;
    if (text.length > 1 && !_isDistributing) {
      _isDistributing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final viewModel = context.read<PhoneAuthViewModel>();
        final state = viewModel.state;
        _distributeOtp(text, viewModel, state);
      });
    }
  }

  /// Distributes a multi-digit code (from paste or SMS autofill) across the
  /// 6 OTP boxes and auto-submits when all 6 digits are present.
  void _distributeOtp(
    String code,
    PhoneAuthViewModel viewModel,
    PhoneAuthState state,
  ) {
    final digits = code.replaceAll(RegExp(r'[^\d]'), '');
    // Guard against re-entrant onChanged calls while we set each controller
    _isDistributing = true;
    for (int i = 0; i < 6 && i < digits.length; i++) {
      _otpControllers[i].text = digits[i];
    }
    _isDistributing = false;
    final assembled =
        digits.length > 6 ? digits.substring(0, 6) : digits;
    if (assembled.length >= 6) {
      FocusScope.of(context).unfocus();
      viewModel.setOtpCode(assembled);
      if (!state.isLoading && !_isAutoSubmitting) {
        _isAutoSubmitting = true;
        _handleVerifyOtp().then((_) {
          if (mounted) _isAutoSubmitting = false;
        });
      }
    } else {
      final nextIndex = assembled.length < 6 ? assembled.length : 5;
      _otpFocusNodes[nextIndex].requestFocus();
      viewModel.setOtpCode(_otpValue);
    }
  }

  Widget _buildOtpBoxes(PhoneAuthViewModel viewModel, PhoneAuthState state) {
    return AutofillGroup(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          6,
          (index) => _buildSingleOtpBox(index, viewModel, state),
        ),
      ),
    );
  }

  Widget _buildSingleOtpBox(
    int index,
    PhoneAuthViewModel viewModel,
    PhoneAuthState state,
  ) {
    final hasError = state.error != null;
    final hasFill = _otpControllers[index].text.isNotEmpty;
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        enabled: !state.isLoading,
        // Only the first box advertises oneTimeCode so the SMS suggestion bar
        // surfaces once and fills all digits via _distributeOtp.
        autofillHints:
            index == 0 ? const [AutofillHints.oneTimeCode] : null,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTypography.headingSmall.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          fillColor: AppColors.surface,
          filled: true,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError
                  ? AppColors.error
                  : hasFill
                      ? AppColors.primaryLight
                      : AppColors.divider,
              width: hasError ? 1.5 : hasFill ? 2.0 : 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError ? AppColors.error : AppColors.primaryLight,
              width: 2,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.divider.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        onChanged: (value) {
          final digits = value.replaceAll(RegExp(r'[^\d]'), '');
          if (digits.length > 1) {
            // Paste or SMS autofill — defer to next frame to avoid iOS
            // autofill session conflicts and re-entrant controller updates.
            if (!_isDistributing) {
              _isDistributing = true;
              final code = digits;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _distributeOtp(code, viewModel, state);
              });
            }
            return;
          }
          // Skip focus advances triggered by programmatic fills in _distributeOtp
          if (_isDistributing) return;
          viewModel.setOtpCode(_otpValue);
          if (digits.isNotEmpty) {
            if (index < 5) {
              _otpFocusNodes[index + 1].requestFocus();
            } else {
              FocusScope.of(context).unfocus();
              if (!state.isLoading && !_isAutoSubmitting) {
                _isAutoSubmitting = true;
                _handleVerifyOtp().then((_) {
                  if (mounted) _isAutoSubmitting = false;
                });
              }
            }
          }
        },
      ),
    );
  }

  CountryCodeItem _getSelectedCountry(dynamic state) {
    return AppCountries.countries.firstWhere(
      (country) => country.code == state.selectedCountryCode,
      orElse: () => AppCountries.countries.first,
    );
  }
}
