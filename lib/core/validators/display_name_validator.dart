import 'base_validator.dart';

/// Centralized display name validation logic.
///
/// This validator ensures consistent validation rules across the app
/// for display names used in onboarding and profile pages.
///
/// Follows the [BaseValidator] API: instantiate and call [validate].
///
/// ```dart
/// final result = DisplayNameValidator().validate('Alice');
/// if (!result.isValid) print(result.message);
/// ```
///
/// For [TextFormField.validator], use [formValidator]:
/// ```dart
/// TextFormField(validator: DisplayNameValidator.formValidator)
/// ```
class DisplayNameValidator extends BaseValidator {
  /// Maximum allowed length for display names
  static const int maxLength = 32;

  /// Regex pattern for allowed characters: alphanumeric, underscore, hyphen, space
  static final RegExp _allowedCharsPattern = RegExp(r'^[a-zA-Z0-9_\- ]+$');

  /// Validates a display name and returns a [ValidationResult].
  ///
  /// Validation rules:
  /// - Required (cannot be empty)
  /// - Maximum 32 characters
  /// - Only alphanumeric characters, underscores, hyphens, and spaces allowed
  @override
  ValidationResult validate(String? value) {
    final trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return ValidationResult.invalid('Display name is required');
    }

    if (trimmed.length > maxLength) {
      return ValidationResult.invalid(
        'Display name must be at most $maxLength characters',
      );
    }

    if (!_allowedCharsPattern.hasMatch(trimmed)) {
      return ValidationResult.invalid(
        'Only letters, numbers, _, - and space allowed',
      );
    }

    return ValidationResult.valid();
  }

  /// Form-compatible validator for [TextFormField.validator].
  ///
  /// Returns `String?` — `null` if valid, error message if invalid.
  ///
  /// ```dart
  /// TextFormField(validator: DisplayNameValidator.formValidator)
  /// ```
  static String? formValidator(String? value) {
    final result = DisplayNameValidator().validate(value);
    return result.isValid ? null : result.message;
  }
}
