import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:securityexperts_app/features/onboarding/pages/user_onboarding_page.dart';
import 'package:securityexperts_app/features/home/pages/home_page.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/phone_auth/presentation/view_models/phone_auth_view_model.dart';
import 'package:securityexperts_app/constants/app_strings.dart';

// Phone number formatter for readable input
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Keep only digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Format based on digit count
    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 3 || i == 6) {
        formatted += ' ';
      }
      formatted += digitsOnly[i];
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
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      context.read<PhoneAuthViewModel>().setPhoneNumber(_phoneController.text);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final viewModel = context.read<PhoneAuthViewModel>();
    await viewModel.sendOtp();
  }

  Future<void> _handleVerifyOtp() async {
    final viewModel = context.read<PhoneAuthViewModel>();

    // Set OTP code from controller
    viewModel.setOtpCode(_otpController.text);

    // Verify OTP
    await viewModel.verifyOtp();

    // After verification, check if we need to navigate
    if (!mounted) return;

    final newState = viewModel.state;
    if (!newState.isLoading && newState.error == null) {
      // Successfully verified - check if profile exists
      final profile = UserProfileService().userProfile;
      if (profile != null) {
        // Profile exists - navigate to home
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        // No profile - navigate to onboarding
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserOnboardingPage()),
        );
      }
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
                            inputFormatters: [PhoneNumberFormatter()],
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: _getPhoneNumberHint(
                                state.selectedCountryCode,
                              ),
                              prefixText: '${state.selectedCountryDialCode} ',
                              labelStyle: AppTypography.bodyRegular.copyWith(color: AppColors.textSecondary),
                              hintStyle: AppTypography.bodyRegular.copyWith(color: AppColors.textMuted),
                              errorText: state.error,
                            ),
                          ),
                          SizedBox(height: AppSpacing.spacing24),

                          // Send OTP Button
                          AppButtonVariants.secondary(
                            onPressed: (state.isLoading || !state.isPhoneValid)
                                ? null
                                : _handleSendOtp,
                            label: 'Send OTP',
                            isLoading: state.isLoading,
                            isEnabled: state.isPhoneValid,
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

                          // OTP Input
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: AppTypography.headingSmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Enter OTP',
                              labelStyle: AppTypography.bodyRegular.copyWith(color: AppColors.textSecondary),
                              errorText: state.error,
                            ),
                          ),
                          SizedBox(height: AppSpacing.spacing24),

                          // Verify OTP Button
                          AppButtonVariants.secondary(
                            onPressed: state.isLoading
                                ? null
                                : _handleVerifyOtp,
                            label: 'Verify OTP',
                            isLoading: state.isLoading,
                          ),
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

  CountryCodeItem _getSelectedCountry(dynamic state) {
    return AppCountries.countries.firstWhere(
      (country) => country.code == state.selectedCountryCode,
      orElse: () => AppCountries.countries.first,
    );
  }
}
