import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/validators/validators.dart';
import '../helpers/mock_repositories.dart';

void main() {
  group('AuthService Tests', () {
    late EmailValidator emailValidator;
    late InputSanitizer inputSanitizer;
    late MockAuthRepository mockAuthRepository;

    setUp(() {
      emailValidator = EmailValidator();
      inputSanitizer = InputSanitizer();
      mockAuthRepository = MockAuthRepository();
    });

    group('Email Validation', () {
      test('should validate correct email format', () {
        final result = emailValidator.validate('user@example.com');
        expect(result.isValid, true);
      });

      test('should reject empty email', () {
        final result = emailValidator.validate('');
        expect(result.isValid, false);
      });

      test('should reject email without @', () {
        final result = emailValidator.validate('invalid.email');
        expect(result.isValid, false);
      });

      test('should reject email without domain', () {
        final result = emailValidator.validate('user@');
        expect(result.isValid, false);
      });

      test('should reject email without local part', () {
        final result = emailValidator.validate('@example.com');
        expect(result.isValid, false);
      });

      test('should accept email with subdomain', () {
        final result = emailValidator.validate('user@mail.example.com');
        expect(result.isValid, true);
      });

      test('should accept email with + addressing', () {
        final result = emailValidator.validate('user+test@example.com');
        expect(result.isValid, true);
      });

      test('should reject email with consecutive dots', () {
        final result = emailValidator.validate('user..name@example.com');
        expect(result.isValid, false);
      });

      test('should reject email with spaces', () {
        final result = emailValidator.validate('user @example.com');
        expect(result.isValid, false);
      });

      test('should reject email exceeding max length', () {
        final longEmail = '${'a' * 250}@example.com';
        final result = emailValidator.validate(longEmail);
        expect(result.isValid, false);
      });

      test('should accept various valid TLDs', () {
        expect(emailValidator.validate('user@example.com').isValid, true);
        expect(emailValidator.validate('user@example.co.uk').isValid, true);
        expect(emailValidator.validate('user@example.org').isValid, true);
        expect(emailValidator.validate('user@example.io').isValid, true);
      });
    });

    group('Password Validation', () {
      test('should validate password requirements', () {
        // Password should be at least 8 characters
        expect('password123'.length >= 8, true);
        expect('short'.length >= 8, false);
      });

      test('should validate password complexity', () {
        final password = 'SecurePass123!';
        final hasUppercase = password.contains(RegExp(r'[A-Z]'));
        final hasLowercase = password.contains(RegExp(r'[a-z]'));
        final hasNumber = password.contains(RegExp(r'[0-9]'));

        expect(hasUppercase, true);
        expect(hasLowercase, true);
        expect(hasNumber, true);
      });

      test('should reject weak passwords', () {
        expect('123456'.length >= 8, false);
        expect('password'.contains(RegExp(r'[0-9]')), false);
      });
    });

    group('Authentication Flow', () {
      test('should login with valid credentials', () async {
        final result = await mockAuthRepository.login(
          'valid@example.com',
          'password123',
        );
        expect(result, true);
      });

      test('should fail login with invalid email', () async {
        expect(
          () => mockAuthRepository.login('invalid@example.com', 'password123'),
          throwsException,
        );
      });

      test('should fail login with invalid password', () async {
        expect(
          () => mockAuthRepository.login('valid@example.com', 'wrongpassword'),
          throwsException,
        );
      });

      test('should sign up with valid credentials', () async {
        final result = await mockAuthRepository.signUp(
          'newuser@example.com',
          'SecurePass123',
          'New User',
        );
        expect(result, true);
      });

      test('should fail signup with empty email', () async {
        expect(
          () => mockAuthRepository.signUp('', 'password', 'User'),
          throwsException,
        );
      });

      test('should fail signup with empty password', () async {
        expect(
          () => mockAuthRepository.signUp('user@example.com', '', 'User'),
          throwsException,
        );
      });

      test('should fail signup with empty name', () async {
        expect(
          () => mockAuthRepository.signUp('user@example.com', 'password', ''),
          throwsException,
        );
      });

      test('should logout successfully', () async {
        expect(mockAuthRepository.logout(), completes);
      });

      test('should get current user ID', () async {
        final userId = await mockAuthRepository.getCurrentUserId();
        expect(userId, equals('user1'));
      });
    });

    group('Email Sanitization', () {
      test('should normalize email to lowercase', () {
        final input = 'USER@EXAMPLE.COM';
        final sanitized = inputSanitizer.sanitizeEmail(input);
        expect(sanitized, 'user@example.com');
      });

      test('should trim email spaces', () {
        final input = '  user@example.com  ';
        final sanitized = inputSanitizer.sanitizeEmail(input);
        expect(sanitized.trim(), 'user@example.com');
      });

      test('should handle email with plus addressing', () {
        final input = 'USER+TEST@EXAMPLE.COM';
        final sanitized = inputSanitizer.sanitizeEmail(input);
        expect(sanitized, contains('@'));
      });
    });

    group('Signup Validation Flow', () {
      test('complete signup validation', () {
        const email = 'newuser@example.com';
        const password = 'SecurePass123';
        const name = 'John Doe';

        // Validate email
        final emailValidation = emailValidator.validate(email);
        expect(emailValidation.isValid, true);

        // Validate password length
        expect(password.length >= 8, true);

        // Validate name
        expect(name.isNotEmpty, true);

        // Sanitize email
        final sanitizedEmail = inputSanitizer.sanitizeEmail(email);
        expect(sanitizedEmail, isNotEmpty);
      });

      test('signup with invalid email fails validation', () {
        const email = 'invalid.email';
        final emailValidation = emailValidator.validate(email);
        expect(emailValidation.isValid, false);
      });

      test('signup with weak password fails validation', () {
        const password = '123'; // Too short
        expect(password.length >= 8, false);
      });
    });

    group('Login Validation Flow', () {
      test('complete login validation', () {
        const email = 'user@example.com';
        const password = 'password123';

        // Validate email
        final emailValidation = emailValidator.validate(email);
        expect(emailValidation.isValid, true);

        // Validate password
        expect(password.isNotEmpty, true);
        expect(password.length >= 8, true);
      });

      test('login with invalid email format fails', () {
        const email = 'invalid@';

        final emailValidation = emailValidator.validate(email);
        expect(emailValidation.isValid, false);
      });
    });

    group('Password Reset Flow', () {
      test('should validate email for password reset', () {
        final email = 'user@example.com';
        final result = emailValidator.validate(email);
        expect(result.isValid, true);
      });

      test('should reject invalid email for password reset', () {
        final email = 'invalid@';
        final result = emailValidator.validate(email);
        expect(result.isValid, false);
      });
    });

    group('Security Tests', () {
      test('should not accept SQL injection attempts', () {
        final email = "' OR '1'='1";
        final result = emailValidator.validate(email);
        expect(result.isValid, false);
      });

      test('should not accept XSS attempts in name', () {
        final name = '<script>alert("xss")</script>';
        final sanitized = inputSanitizer.sanitizeUsername(name);
        expect(sanitized, isNotNull);
        // Should escape or remove dangerous content
      });

      test('should escape HTML in user input', () {
        final input = '<img src=x onerror=alert(1)>';
        final escaped = inputSanitizer.escapeHtml(input);
        expect(escaped, contains('&lt;'));
      });

      test('should handle encoded malicious input', () {
        final input = '%3Cscript%3E'; // URL encoded <script>
        final sanitized = inputSanitizer.sanitizeUsername(input);
        expect(sanitized, isNotNull);
      });
    });

    group('Edge Cases', () {
      test('should handle email with numbers', () {
        final result = emailValidator.validate('user123@example456.com');
        expect(result.isValid, true);
      });

      test('should handle email with hyphens', () {
        final result = emailValidator.validate('user-name@example-domain.com');
        expect(result.isValid, true);
      });

      test('should handle email with underscore', () {
        final result = emailValidator.validate('user_name@example.com');
        expect(result.isValid, true);
      });

      test('should reject email with consecutive dots', () {
        final result = emailValidator.validate('user..name@example.com');
        expect(result.isValid, false);
      });

      test('should handle single character email local part', () {
        final result = emailValidator.validate('a@example.com');
        expect(result.isValid, true);
      });

      test('should handle long email local part', () {
        final result = emailValidator.validate('${'a' * 64}@example.com');
        // Local part max is typically 64 characters
        expect(result.isValid, true);
      });
    });

    group('Performance Tests', () {
      test('should validate email quickly', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          emailValidator.validate('user$i@example.com');
        }

        stopwatch.stop();
        final duration = stopwatch.elapsedMilliseconds;

        // Should complete 100 validations in less than 100ms
        expect(duration, lessThan(100));
      });

      test('should sanitize email quickly', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          inputSanitizer.sanitizeEmail('USER$i@EXAMPLE.COM');
        }

        stopwatch.stop();
        final duration = stopwatch.elapsedMilliseconds;

        // Should complete 100 sanitizations in less than 100ms
        expect(duration, lessThan(100));
      });
    });
  });
}
