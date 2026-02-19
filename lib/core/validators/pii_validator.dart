import 'base_validator.dart';

/// Centralized PII (Personal Identifiable Information) validation logic.
///
/// This validator detects and blocks phone numbers and email addresses
/// to protect user privacy in public-facing inputs like chat, reviews,
/// and support tickets.
///
/// Follows the [BaseValidator] API: instantiate and call [validate].
///
/// ```dart
/// final result = PIIValidator().validate(text);
/// if (!result.isValid) print(result.message);
/// ```
///
/// Static helper methods [containsEmail], [containsPhoneNumber], and
/// [containsPII] are available for boolean checks without a full
/// [ValidationResult].
class PIIValidator extends BaseValidator {
  /// Regex pattern for detecting email addresses
  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  /// Regex pattern for detecting phone numbers (various formats)
  /// Matches:
  /// - International: +1234567890, +1 234 567 890
  /// - With country code: 001234567890
  /// - Standard: 1234567890, 123-456-7890, 123.456.7890
  /// - With parentheses: (123) 456-7890
  /// - With spaces: 123 456 7890
  static final RegExp _phonePattern = RegExp(
    r'(?:\+?\d{1,3}[-.\s]?)?' // Optional country code
    r'(?:\(?\d{2,4}\)?[-.\s]?)?' // Optional area code
    r'\d{3,4}[-.\s]?\d{3,4}' // Main number
    r'(?:[-.\s]?\d{1,4})?', // Optional extension
  );

  /// Minimum digits required to consider it a phone number (reduces false positives)
  static const int _minPhoneDigits = 7;

  /// Error message for email detection
  static const String emailErrorMessage =
      'Please do not share email addresses for your privacy';

  /// Error message for phone detection
  static const String phoneErrorMessage =
      'Please do not share phone numbers for your privacy';

  /// Error message for both email and phone detection
  static const String piiErrorMessage =
      'Please do not share personal contact information for your privacy';

  /// Checks if the text contains an email address.
  static bool containsEmail(String? text) {
    if (text == null || text.isEmpty) return false;
    return _emailPattern.hasMatch(text);
  }

  /// Checks if the text contains a phone number.
  static bool containsPhoneNumber(String? text) {
    if (text == null || text.isEmpty) return false;

    final match = _phonePattern.firstMatch(text);
    if (match == null) return false;

    // Count digits in the match to reduce false positives
    final matchedText = match.group(0) ?? '';
    final digitCount = matchedText.replaceAll(RegExp(r'\D'), '').length;

    return digitCount >= _minPhoneDigits;
  }

  /// Checks if the text contains any PII (email or phone).
  static bool containsPII(String? text) {
    return containsEmail(text) || containsPhoneNumber(text);
  }

  /// Validates text and returns a [ValidationResult] if PII is detected.
  ///
  /// Returns [ValidationResult.valid] if no PII is found, or
  /// [ValidationResult.invalid] with a descriptive message.
  @override
  ValidationResult validate(String? text) {
    if (text == null || text.isEmpty) return ValidationResult.valid();

    final hasEmail = containsEmail(text);
    final hasPhone = containsPhoneNumber(text);

    if (hasEmail && hasPhone) {
      return ValidationResult.invalid(piiErrorMessage);
    } else if (hasEmail) {
      return ValidationResult.invalid(emailErrorMessage);
    } else if (hasPhone) {
      return ValidationResult.invalid(phoneErrorMessage);
    }

    return ValidationResult.valid();
  }

  /// Form-compatible validator for [TextFormField.validator].
  ///
  /// Returns `String?` — `null` if valid, error message if invalid.
  static String? formValidator(String? text) {
    final result = PIIValidator().validate(text);
    return result.isValid ? null : result.message;
  }

  /// Validates text and returns a specific error message if PII is detected.
  ///
  /// This version allows combining with other validators:
  /// ```dart
  /// validator: (v) {
  ///   final piiResult = PIIValidator().validate(v);
  ///   if (!piiResult.isValid) return piiResult.message;
  ///   // Other validation...
  ///   return null;
  /// }
  /// ```
  static String? validateWithCustomMessage(String? text, String errorMessage) {
    if (containsPII(text)) {
      return errorMessage;
    }
    return null;
  }
}
