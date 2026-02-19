import 'base_validator.dart';

/// Message validator for validating chat and text messages
///
/// Checks:
/// - Not empty
/// - Not too long
/// - Valid characters
/// - No spam patterns
///
/// Example:
/// ```dart
/// final validator = MessageValidator();
/// final result = validator.validate('Hello, how are you?');
/// if (result.isValid) {
///   print('Message is valid');
/// } else {
///   print('Error: ${result.message}');
/// }
/// ```
class MessageValidator extends BaseValidator {
  /// Minimum message length
  static const int minLength = 1;

  /// Maximum message length
  static const int maxLength = 5000;

  @override
  ValidationResult validate(String? value) {
    // Check if null or empty
    if (value == null) {
      return ValidationResult.invalid('Message cannot be empty');
    }

    // Don't trim here - preserve intentional whitespace
    if (value.isEmpty) {
      return ValidationResult.invalid('Message cannot be empty');
    }

    // Check minimum length (after trim for validation purposes)
    if (value.trim().isEmpty) {
      return ValidationResult.invalid('Message cannot be only whitespace');
    }

    // Check maximum length
    if (value.length > maxLength) {
      return ValidationResult.invalid(
        'Message must not exceed $maxLength characters (current: ${value.length})',
      );
    }

    // Check for spam patterns
    final spamCheck = _checkSpamPatterns(value);
    if (spamCheck != null) {
      return ValidationResult.invalid(spamCheck);
    }

    return ValidationResult.valid();
  }

  /// Checks for common spam patterns and returns error message if found
  String? _checkSpamPatterns(String message) {
    // Check for excessive repetition
    if (_hasExcessiveRepetition(message)) {
      return 'Message contains excessive character repetition';
    }

    // Check for excessive capitalization (more than 70% uppercase)
    if (_hasExcessiveCapitalization(message)) {
      return 'Message is too much in UPPERCASE';
    }

    // Check for suspicious URL patterns
    if (_hasSuspiciousUrls(message)) {
      return 'Message contains suspicious URLs or links';
    }

    // Check for excessive special characters
    if (_hasExcessiveSpecialChars(message)) {
      return 'Message contains too many special characters';
    }

    return null;
  }

  /// Checks for excessive character repetition (e.g., "hellooooooo")
  bool _hasExcessiveRepetition(String message) {
    // Check if any character is repeated more than 4 times consecutively
    return RegExp(r'(.)\1{4,}').hasMatch(message);
  }

  /// Checks if more than 70% of letters are uppercase
  bool _hasExcessiveCapitalization(String message) {
    final letters = message.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (letters.isEmpty) return false;

    final uppercase = letters.replaceAll(RegExp(r'[^A-Z]'), '');
    final ratio = uppercase.length / letters.length;

    return ratio > 0.7;
  }

  /// Checks for suspicious URL patterns
  bool _hasSuspiciousUrls(String message) {
    // Check for URL patterns
    final urlPattern = RegExp(
      r'https?://|www\.|\.com|\.io|\.xyz|\.xyz|bit\.ly|tinyurl|short\.link',
      caseSensitive: false,
    );

    return urlPattern.hasMatch(message);
  }

  /// Checks for excessive special characters (more than 20%)
  bool _hasExcessiveSpecialChars(String message) {
    if (message.isEmpty) return false;

    final specialChars = message.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '');
    final ratio = specialChars.length / message.length;

    return ratio > 0.2;
  }
}

/// Input sanitizer for chat messages
///
/// Removes potentially harmful content and normalizes input.
///
/// Example:
/// ```dart
/// final sanitizer = InputSanitizer();
/// final cleanMessage = sanitizer.sanitizeMessage('hello  world');
/// print(cleanMessage); // 'hello world'
/// ```
class InputSanitizer {
  /// Sanitizes a chat message by removing harmful content and normalizing
  String sanitizeMessage(String message) {
    var sanitized = message;

    // Remove leading/trailing whitespace
    sanitized = sanitized.trim();

    // Replace multiple spaces with single space
    sanitized = sanitized.replaceAll(RegExp(r' +'), ' ');

    // Remove control characters (except newlines and tabs)
    sanitized = sanitized.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );

    // Normalize newlines (replace \r\n with \n, then \r with \n)
    sanitized = sanitized.replaceAll('\r\n', '\n');
    sanitized = sanitized.replaceAll('\r', '\n');

    // Limit consecutive newlines to 2
    sanitized = sanitized.replaceAll(RegExp(r'\n\n\n+'), '\n\n');

    return sanitized;
  }

  /// Sanitizes a username/display name
  String sanitizeUsername(String username) {
    var sanitized = username;

    // Remove leading/trailing whitespace
    sanitized = sanitized.trim();

    // Replace multiple spaces with single space
    sanitized = sanitized.replaceAll(RegExp(r' +'), ' ');

    // Remove special characters except hyphens and underscores
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-_]'), '');

    // Limit to reasonable length
    if (sanitized.length > 50) {
      sanitized = sanitized.substring(0, 50);
    }

    return sanitized;
  }

  /// Sanitizes an email by normalizing and validating format
  String sanitizeEmail(String email) {
    var sanitized = email;

    // Remove leading/trailing whitespace
    sanitized = sanitized.trim();

    // Convert to lowercase
    sanitized = sanitized.toLowerCase();

    // Remove any special Unicode characters (keep only ASCII)
    sanitized = sanitized.replaceAll(RegExp(r'[^\x00-\x7F]'), '');

    return sanitized;
  }

  /// Sanitizes a phone number by removing non-digit characters except +
  String sanitizePhone(String phone) {
    var sanitized = phone;

    // Remove leading/trailing whitespace
    sanitized = sanitized.trim();

    // Keep only digits, +, -, (), and spaces
    sanitized = sanitized.replaceAll(RegExp(r'[^\d+\-() ]'), '');

    // Remove multiple spaces
    sanitized = sanitized.replaceAll(RegExp(r' +'), ' ');

    return sanitized;
  }

  /// Sanitizes user input for search queries
  String sanitizeSearchQuery(String query) {
    var sanitized = query;

    // Remove leading/trailing whitespace
    sanitized = sanitized.trim();

    // Replace multiple spaces with single space
    sanitized = sanitized.replaceAll(RegExp(r' +'), ' ');

    // Remove control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Limit length
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }

    return sanitized;
  }

  /// Escapes HTML special characters to prevent injection
  String escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// Unescapes HTML special characters
  String unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'");
  }

  /// Checks if text contains profanity (basic list)
  bool containsProfanity(String text) {
    // Basic profanity list - extend as needed
    final profanities = [
      'badword1',
      'badword2',
      // Add more as needed
    ];

    final lowerText = text.toLowerCase();
    return profanities.any((word) => lowerText.contains(word));
  }

  /// Removes or masks profanity
  String maskProfanity(String text) {
    final profanities = [
      'badword1',
      'badword2',
      // Add more as needed
    ];

    var masked = text;
    for (final word in profanities) {
      masked = masked.replaceAll(
        RegExp(word, caseSensitive: false),
        '*' * word.length,
      );
    }

    return masked;
  }
}
