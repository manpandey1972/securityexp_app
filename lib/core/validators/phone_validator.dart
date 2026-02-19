import 'base_validator.dart';

/// Phone number validator for validating phone numbers
///
/// Supports:
/// - International format (+1-234-567-8900)
/// - US format (234-567-8900)
/// - Simple format (2345678900)
/// - Formats with spaces and parentheses
///
/// Example:
/// ```dart
/// final validator = PhoneValidator();
/// final result = validator.validate('+1-234-567-8900');
/// if (result.isValid) {
///   print('Phone is valid');
/// } else {
///   print('Error: ${result.message}');
/// }
/// ```
class PhoneValidator extends BaseValidator {
  /// Minimum digits required in phone number
  static const int minDigits = 9;

  /// Maximum digits allowed in phone number
  static const int maxDigits = 15;

  @override
  ValidationResult validate(String? value) {
    // Check if null or empty
    if (value == null || value.trim().isEmpty) {
      return ValidationResult.invalid('Phone number is required');
    }

    final trimmed = value.trim();

    // Extract only digits and + sign
    final cleanedPhone = _extractDigits(trimmed);

    // Check if empty after cleaning
    if (cleanedPhone.isEmpty) {
      return ValidationResult.invalid(
        'Phone number must contain at least some digits',
      );
    }

    // Count digits only
    final digitCount = cleanedPhone.replaceAll(RegExp(r'[^\d]'), '').length;

    // Check minimum digits
    if (digitCount < minDigits) {
      return ValidationResult.invalid(
        'Phone number must have at least $minDigits digits',
      );
    }

    // Check maximum digits
    if (digitCount > maxDigits) {
      return ValidationResult.invalid(
        'Phone number must not exceed $maxDigits digits',
      );
    }

    // Validate format
    if (!_isValidFormat(trimmed)) {
      return ValidationResult.invalid(
        'Please enter a valid phone number format',
      );
    }

    return ValidationResult.valid();
  }

  /// Extracts and validates phone number format
  String _extractDigits(String phone) {
    // Allow digits, +, -, (), space
    return phone.replaceAll(RegExp(r'[^\d+\-() ]'), '');
  }

  /// Validates phone number format
  bool _isValidFormat(String phone) {
    // Pattern for valid phone formats
    // Supports: +1 234-567-8900, (234) 567-8900, 234-567-8900, 2345678900, +12345678900, etc.
    final patterns = [
      // International format: +1-234-567-8900
      RegExp(r'^\+\d{1,3}[-.\s]?\d{1,14}$'),

      // US with parentheses: (234) 567-8900
      RegExp(r'^\(\d{3}\)\s?\d{3}[-.\s]?\d{4}$'),

      // US format: 234-567-8900
      RegExp(r'^\d{3}[-.\s]?\d{3}[-.\s]?\d{4}$'),

      // Simple format: 2345678900
      RegExp(r'^\d{10,15}$'),

      // With spaces: 234 567 8900
      RegExp(r'^\d{3}\s\d{3}\s\d{4}$'),
    ];

    return patterns.any((pattern) => pattern.hasMatch(phone));
  }

  /// Formats a valid phone number to standard format
  ///
  /// Example: '2345678900' -> '(234) 567-8900'
  String formatPhone(String phone) {
    // Extract only digits
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length == 10) {
      // US format: (XXX) XXX-XXXX
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      // US with country code: +1 (XXX) XXX-XXXX
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    } else if (digits.startsWith('+')) {
      // International format: keep as is with some formatting
      return '+${digits.replaceAll('+', '')}';
    }

    // Return as is if no specific format applies
    return phone;
  }

  /// Removes all formatting from phone number
  ///
  /// Example: '(234) 567-8900' -> '2345678900'
  String removeFormatting(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }
}
