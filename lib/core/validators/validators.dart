/// Validators module for input validation across the application
///
/// This file exports all validators and sanitizers used throughout the app.
///
/// Example:
/// ```dart
/// import 'package:greenhive_app/core/validators/validators.dart';
///
/// // Validate email
/// final emailResult = EmailValidator().validate('user@example.com');
///
/// // Validate phone
/// final phoneResult = PhoneValidator().validate('+1-234-567-8900');
///
/// // Validate message
/// final messageResult = MessageValidator().validate('Hello world');
///
/// // Sanitize input
/// final sanitizer = InputSanitizer();
/// final cleanMessage = sanitizer.sanitizeMessage('hello  world');
/// ```

library;

export 'base_validator.dart';
export 'display_name_validator.dart';
export 'email_validator.dart';
export 'message_validator.dart';
export 'phone_validator.dart';
export 'pii_validator.dart';
export 'form_validation_mixin.dart';
