/// @Deprecated('Import AppStrings from package:securityexperts_app/core/constants.dart instead')
///
/// This file re-exports AppStrings from the canonical location.
/// The AppStrings class and all phone-auth constants are now in
/// [lib/core/constants.dart]. Import patterns in existing code
/// (especially phone_auth) continue to work via this re-export.
library;

export 'package:securityexperts_app/core/constants.dart' show AppStrings;

/// Country codes list for phone authentication
class AppCountries {
  static const List<CountryCodeItem> countries = [
    CountryCodeItem(name: 'United States', code: 'US', dialCode: '+1'),
    CountryCodeItem(name: 'Canada', code: 'CA', dialCode: '+1'),
    CountryCodeItem(name: 'India', code: 'IN', dialCode: '+91'),
    CountryCodeItem(name: 'United Kingdom', code: 'GB', dialCode: '+44'),
    CountryCodeItem(name: 'Australia', code: 'AU', dialCode: '+61'),
    CountryCodeItem(name: 'Germany', code: 'DE', dialCode: '+49'),
    CountryCodeItem(name: 'France', code: 'FR', dialCode: '+33'),
    CountryCodeItem(name: 'Japan', code: 'JP', dialCode: '+81'),
    CountryCodeItem(name: 'China', code: 'CN', dialCode: '+86'),
    CountryCodeItem(name: 'Brazil', code: 'BR', dialCode: '+55'),
    CountryCodeItem(name: 'Mexico', code: 'MX', dialCode: '+52'),
    CountryCodeItem(name: 'South Korea', code: 'KR', dialCode: '+82'),
    CountryCodeItem(name: 'Spain', code: 'ES', dialCode: '+34'),
    CountryCodeItem(name: 'Italy', code: 'IT', dialCode: '+39'),
    CountryCodeItem(name: 'Russia', code: 'RU', dialCode: '+7'),
    CountryCodeItem(name: 'Pakistan', code: 'PK', dialCode: '+92'),
    CountryCodeItem(name: 'Bangladesh', code: 'BD', dialCode: '+880'),
    CountryCodeItem(name: 'Nigeria', code: 'NG', dialCode: '+234'),
    CountryCodeItem(name: 'South Africa', code: 'ZA', dialCode: '+27'),
    CountryCodeItem(name: 'Singapore', code: 'SG', dialCode: '+65'),
    CountryCodeItem(name: 'Malaysia', code: 'MY', dialCode: '+60'),
    CountryCodeItem(name: 'Thailand', code: 'TH', dialCode: '+66'),
    CountryCodeItem(name: 'Vietnam', code: 'VN', dialCode: '+84'),
    CountryCodeItem(name: 'Indonesia', code: 'ID', dialCode: '+62'),
    CountryCodeItem(name: 'Philippines', code: 'PH', dialCode: '+63'),
    CountryCodeItem(name: 'UAE', code: 'AE', dialCode: '+971'),
    CountryCodeItem(name: 'Saudi Arabia', code: 'SA', dialCode: '+966'),
    CountryCodeItem(name: 'Egypt', code: 'EG', dialCode: '+20'),
    CountryCodeItem(name: 'Argentina', code: 'AR', dialCode: '+54'),
    CountryCodeItem(name: 'Chile', code: 'CL', dialCode: '+56'),
  ];
}

/// Country code model
class CountryCodeItem {
  final String name;
  final String code;
  final String dialCode;

  const CountryCodeItem({
    required this.name,
    required this.code,
    required this.dialCode,
  });
}
