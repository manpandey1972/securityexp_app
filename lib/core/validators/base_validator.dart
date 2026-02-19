/// Base abstract class for all validators
///
/// Provides a common interface for validation across the application.
/// Each validator should extend this class and implement the [validate] method.
///
/// Example:
/// ```dart
/// class MyValidator extends BaseValidator {
///   @override
///   ValidationResult validate(String? value) {
///     if (value == null || value.isEmpty) {
///       return ValidationResult.invalid('Field is required');
///     }
///     return ValidationResult.valid();
///   }
/// }
/// ```
abstract class BaseValidator {
  /// Validates the given value and returns a [ValidationResult]
  ///
  /// Returns [ValidationResult.valid()] if validation passes,
  /// or [ValidationResult.invalid(message)] if validation fails.
  ValidationResult validate(String? value);
}

/// Represents the result of a validation operation
///
/// Can be used to check if validation passed and retrieve error message if needed.
class ValidationResult {
  /// Whether the validation passed
  final bool isValid;

  /// Error message if validation failed, null if validation passed
  final String? message;

  ValidationResult({required this.isValid, this.message});

  /// Creates a valid result
  factory ValidationResult.valid() {
    return ValidationResult(isValid: true, message: null);
  }

  /// Creates an invalid result with error message
  factory ValidationResult.invalid(String message) {
    return ValidationResult(isValid: false, message: message);
  }

  /// String representation for debugging
  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $message';
}

/// Extension on String to provide validation methods
extension ValidationExtension on String {
  /// Check if string is a valid email
  bool isValidEmail() {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  /// Check if string is a valid phone number (basic check)
  bool isValidPhone() {
    final phoneRegex = RegExp(r'^\+?1?\d{9,15}$');
    return phoneRegex.hasMatch(replaceAll(RegExp(r'[^\d+]'), ''));
  }

  /// Check if string is not empty
  bool isNotEmpty() => trim().isNotEmpty;

  /// Check if string has minimum length
  bool hasMinLength(int length) => trim().length >= length;

  /// Check if string has maximum length
  bool hasMaxLength(int length) => trim().length <= length;

  /// Check if string contains only alphanumeric characters
  bool isAlphanumeric() => RegExp(r'^[a-zA-Z0-9]+$').hasMatch(this);

  /// Check if string contains at least one number
  bool hasNumber() => RegExp(r'\d').hasMatch(this);

  /// Check if string contains at least one special character
  bool hasSpecialChar() => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(this);

  /// Check if string is all uppercase
  bool isAllUppercase() => this == toUpperCase();

  /// Check if string is all lowercase
  bool isAllLowercase() => this == toLowerCase();
}
