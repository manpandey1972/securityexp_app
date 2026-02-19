import 'package:flutter/material.dart';
import 'validators.dart';

/// Mixin for form validation state management
///
/// Provides common validation patterns for form state classes.
///
/// Example:
/// ```dart
/// class _MyFormState extends State<MyForm> with FormValidationMixin {
///   late final EmailValidator _emailValidator;
///   late final PasswordValidator _passwordValidator;
///
///   @override
///   void initState() {
///     super.initState();
///     _emailValidator = EmailValidator();
///     _passwordValidator = PasswordValidator();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Form(
///       child: Column(
///         children: [
///           TextFormField(
///             validator: (value) => _emailValidator.validate(value).message,
///           ),
///           TextFormField(
///             validator: (value) => _passwordValidator.validate(value).message,
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
mixin FormValidationMixin {
  /// Stores validation errors for fields
  final Map<String, String?> _errors = {};

  /// Gets error message for a field
  String? getError(String fieldName) => _errors[fieldName];

  /// Sets error message for a field
  void setError(String fieldName, String? error) {
    _errors[fieldName] = error;
  }

  /// Clears error for a field
  void clearError(String fieldName) {
    _errors.remove(fieldName);
  }

  /// Clears all errors
  void clearAllErrors() {
    _errors.clear();
  }

  /// Checks if there are any errors
  bool hasErrors() => _errors.values.any((error) => error != null);

  /// Gets all errors
  Map<String, String?> getAllErrors() => Map.from(_errors);

  /// Validates a field using the provided validator
  bool validateField(String fieldName, String? value, BaseValidator validator) {
    final result = validator.validate(value);
    if (!result.isValid) {
      setError(fieldName, result.message);
      return false;
    } else {
      clearError(fieldName);
      return true;
    }
  }

  /// Validates multiple fields
  bool validateFields(Map<String, dynamic> fieldValidations) {
    bool allValid = true;

    fieldValidations.forEach((fieldName, validation) {
      final value = validation['value'] as String?;
      final validator = validation['validator'] as BaseValidator;

      if (!validateField(fieldName, value, validator)) {
        allValid = false;
      }
    });

    return allValid;
  }
}

/// Extension methods for form validation
extension FormValidationExtension on FormState {
  /// Validates all fields in the form
  bool isValid() => validate();

  /// Gets all validation errors in the form
  List<String> getErrors() {
    final errors = <String>[];
    // This would need to be implemented per form
    return errors;
  }
}

/// Helper class for common validation scenarios
class ValidationHelper {
  /// Validates a login form
  static Map<String, String?> validateLoginForm({
    required String email,
    required String password,
  }) {
    final errors = <String, String?>{};

    final emailValidator = EmailValidator();
    final emailResult = emailValidator.validate(email);
    if (!emailResult.isValid) {
      errors['email'] = emailResult.message;
    }

    final passwordResult = _validatePassword(password);
    if (!passwordResult.isValid) {
      errors['password'] = passwordResult.message;
    }

    return errors;
  }

  /// Validates a signup form
  static Map<String, String?> validateSignupForm({
    required String email,
    required String password,
    required String confirmPassword,
    required String username,
  }) {
    final errors = <String, String?>{};

    // Validate email
    final emailValidator = EmailValidator();
    final emailResult = emailValidator.validate(email);
    if (!emailResult.isValid) {
      errors['email'] = emailResult.message;
    }

    // Validate password
    final passwordResult = _validatePassword(password);
    if (!passwordResult.isValid) {
      errors['password'] = passwordResult.message;
    }

    // Validate password confirmation
    if (password != confirmPassword) {
      errors['confirmPassword'] = 'Passwords do not match';
    }

    // Validate username
    if (username.trim().isEmpty) {
      errors['username'] = 'Username is required';
    } else if (username.trim().length < 3) {
      errors['username'] = 'Username must be at least 3 characters';
    } else if (username.trim().length > 30) {
      errors['username'] = 'Username must not exceed 30 characters';
    }

    return errors;
  }

  /// Validates a profile update form
  static Map<String, String?> validateProfileForm({
    required String name,
    required String bio,
    String? phone,
  }) {
    final errors = <String, String?>{};

    if (name.trim().isEmpty) {
      errors['name'] = 'Name is required';
    } else if (name.trim().length < 2) {
      errors['name'] = 'Name must be at least 2 characters';
    } else if (name.trim().length > 50) {
      errors['name'] = 'Name must not exceed 50 characters';
    }

    if (bio.trim().isEmpty) {
      errors['bio'] = 'Bio is required';
    } else if (bio.trim().length < 10) {
      errors['bio'] = 'Bio must be at least 10 characters';
    } else if (bio.trim().length > 500) {
      errors['bio'] = 'Bio must not exceed 500 characters';
    }

    if (phone != null && phone.trim().isNotEmpty) {
      final phoneValidator = PhoneValidator();
      final phoneResult = phoneValidator.validate(phone);
      if (!phoneResult.isValid) {
        errors['phone'] = phoneResult.message;
      }
    }

    return errors;
  }

  /// Validates a chat message
  static String? validateChatMessage(String message) {
    final validator = MessageValidator();
    final result = validator.validate(message);
    return result.isValid ? null : result.message;
  }

  /// Validates internal password (not exposed externally)
  static ValidationResult _validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult.invalid('Password is required');
    }

    if (password.length < 8) {
      return ValidationResult.invalid('Password must be at least 8 characters');
    }

    if (password.length > 128) {
      return ValidationResult.invalid(
        'Password must not exceed 128 characters',
      );
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      return ValidationResult.invalid(
        'Password must contain at least one lowercase letter',
      );
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return ValidationResult.invalid(
        'Password must contain at least one uppercase letter',
      );
    }

    if (!password.contains(RegExp(r'\d'))) {
      return ValidationResult.invalid(
        'Password must contain at least one number',
      );
    }

    return ValidationResult.valid();
  }
}

/// Custom form field validator builders for easy use with TextFormField
class ValidatorBuilders {
  /// Creates a display name field validator
  static String? displayNameValidator(String? value) {
    return DisplayNameValidator.formValidator(value);
  }

  /// Creates an email field validator
  static String? emailValidator(String? value) {
    final result = EmailValidator().validate(value);
    return result.isValid ? null : result.message;
  }

  /// Creates a phone field validator
  static String? phoneValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is often optional
    }
    final result = PhoneValidator().validate(value);
    return result.isValid ? null : result.message;
  }

  /// Creates a message field validator
  static String? messageValidator(String? value) {
    final result = MessageValidator().validate(value);
    return result.isValid ? null : result.message;
  }

  /// Creates a PII (personal information) field validator
  static String? piiValidator(String? value) {
    return PIIValidator.formValidator(value);
  }

  /// Creates a required field validator
  static String? requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  /// Creates a minimum length validator
  static String? Function(String?) minLengthValidator(int minLength) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      if (value.length < minLength) {
        return 'Must be at least $minLength characters';
      }
      return null;
    };
  }

  /// Creates a maximum length validator
  static String? Function(String?) maxLengthValidator(int maxLength) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      if (value.length > maxLength) {
        return 'Must not exceed $maxLength characters';
      }
      return null;
    };
  }

  /// Creates a custom pattern validator
  static String? Function(String?) patternValidator(
    RegExp pattern,
    String errorMessage,
  ) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      if (!pattern.hasMatch(value)) {
        return errorMessage;
      }
      return null;
    };
  }

  /// Combines multiple validators
  static String? Function(String?) combineValidators(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) {
          return error;
        }
      }
      return null;
    };
  }
}
