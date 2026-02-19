import 'base_validator.dart';

/// Email validator for validating email addresses
///
/// Checks:
/// - Not empty
/// - Valid email format
/// - Not too long (max 254 characters per RFC 5321)
///
/// Example:
/// ```dart
/// final validator = EmailValidator();
/// final result = validator.validate('user@example.com');
/// if (result.isValid) {
///   print('Email is valid');
/// } else {
///   print('Error: ${result.message}');
/// }
/// ```
class EmailValidator extends BaseValidator {
  /// Maximum email length (RFC 5321)
  static const int maxLength = 254;

  /// Minimum email length
  static const int minLength = 5;

  @override
  ValidationResult validate(String? value) {
    // Check if null or empty
    if (value == null || value.trim().isEmpty) {
      return ValidationResult.invalid('Email is required');
    }

    final trimmed = value.trim();

    // Check minimum length
    if (trimmed.length < minLength) {
      return ValidationResult.invalid(
        'Email must be at least $minLength characters',
      );
    }

    // Check maximum length
    if (trimmed.length > maxLength) {
      return ValidationResult.invalid(
        'Email must not exceed $maxLength characters',
      );
    }

    // Check email format
    if (!trimmed.isValidEmail()) {
      return ValidationResult.invalid('Please enter a valid email address');
    }

    // Check for multiple @ symbols
    if (trimmed.split('@').length != 2) {
      return ValidationResult.invalid(
        'Email must contain exactly one @ symbol',
      );
    }

    // Split email into local and domain parts
    final parts = trimmed.split('@');
    final localPart = parts[0];
    final domainPart = parts[1];

    // Validate local part
    if (!_isValidLocalPart(localPart)) {
      return ValidationResult.invalid('Email address has invalid format');
    }

    // Validate domain part
    if (!_isValidDomain(domainPart)) {
      return ValidationResult.invalid('Email domain is not valid');
    }

    return ValidationResult.valid();
  }

  /// Validates the local part of email (before @)
  bool _isValidLocalPart(String localPart) {
    if (localPart.isEmpty || localPart.length > 64) {
      return false;
    }

    // Local part can contain: letters, numbers, dots, hyphens, underscores, plus signs
    final validCharacters = RegExp(r'^[a-zA-Z0-9._+-]+$');
    if (!validCharacters.hasMatch(localPart)) {
      return false;
    }

    // Can't start or end with dot
    if (localPart.startsWith('.') || localPart.endsWith('.')) {
      return false;
    }

    // Can't have consecutive dots
    if (localPart.contains('..')) {
      return false;
    }

    return true;
  }

  /// Validates the domain part of email (after @)
  bool _isValidDomain(String domain) {
    if (domain.isEmpty) {
      return false;
    }

    // Must have at least one dot
    if (!domain.contains('.')) {
      return false;
    }

    // Split by dot
    final parts = domain.split('.');

    // Each part must be non-empty
    if (parts.any((part) => part.isEmpty)) {
      return false;
    }

    // Each part can only contain letters, numbers, and hyphens
    final validPart = RegExp(r'^[a-zA-Z0-9-]+$');
    if (!parts.every((part) => validPart.hasMatch(part))) {
      return false;
    }

    // TLD (last part) must be at least 2 characters and no hyphens
    final tld = parts.last;
    if (tld.length < 2 || tld.contains('-') || RegExp(r'\d').hasMatch(tld)) {
      return false;
    }

    return true;
  }
}
