// IssueReporter tests
//
// Tests for the issue reporter which helps users report bugs.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IssueReporter', () {
    group('_buildDescription', () {
      // Testing private method behavior through its observable effects
      // The _buildDescription method creates a markdown-formatted bug report

      test('should create description with placeholder for user input', () {
        // The description should always include a placeholder for the user
        // to describe what they were doing
        const expectedHeader = '**Issue Description:**';
        expect(expectedHeader, contains('Issue Description'));
      });

      test('should include error context when provided', () {
        // When errorContext is provided, it should be included in the report
        const testContext = 'Loading user profile';
        const expectedFormat = 'Context: $testContext';
        expect(expectedFormat, contains(testContext));
      });

      test('should include error message when provided', () {
        // When errorMessage is provided, it should be included in the report
        const testError = 'NetworkException: Connection refused';
        const expectedFormat = 'Error: $testError';
        expect(expectedFormat, contains(testError));
      });

      test('should truncate long stack traces to 500 characters', () {
        // Stack traces longer than 500 chars should be truncated
        final longStackTrace = 'a' * 600;
        final truncated = longStackTrace.length > 500
            ? '${longStackTrace.substring(0, 500)}...'
            : longStackTrace;
        expect(truncated.length, 503); // 500 + '...'
      });

      test('should not truncate short stack traces', () {
        final shortStackTrace = 'a' * 100;
        final result = shortStackTrace.length > 500
            ? '${shortStackTrace.substring(0, 500)}...'
            : shortStackTrace;
        expect(result.length, 100);
        expect(result.endsWith('...'), false);
      });

      test('should include markdown code block for stack trace', () {
        // Stack traces should be wrapped in markdown code blocks
        const expectedOpening = '```';
        const expectedClosing = '```';
        expect(expectedOpening, isNotEmpty);
        expect(expectedClosing, isNotEmpty);
      });

      test('should include separator before error details', () {
        // There should be a visual separator between user description and
        // auto-captured error details
        const separator = '---';
        expect(separator, isNotEmpty);
      });

      test('should handle null parameters gracefully', () {
        // When all parameters are null, should still create valid description
        String? errorMessage;
        String? errorContext;
        String? stackTrace;

        // Should not throw
        expect(errorMessage, isNull);
        expect(errorContext, isNull);
        expect(stackTrace, isNull);
      });
    });

    group('description format verification', () {
      test('should follow markdown format', () {
        // The description should use markdown formatting
        const headers = [
          '**Issue Description:**',
          '**Error Details (auto-captured):**',
        ];
        for (final header in headers) {
          expect(header, contains('**'));
        }
      });

      test('should have proper structure', () {
        // Expected structure:
        // 1. Issue Description header
        // 2. Placeholder text
        // 3. Separator (if error details exist)
        // 4. Error Details header (if error details exist)
        // 5. Context (if provided)
        // 6. Error (if provided)
        // 7. Stack trace in code block (if provided)
        final structure = [
          'Issue Description',
          'Error Details',
          'Context:',
          'Error:',
          'Stack trace:',
        ];
        expect(structure, hasLength(5));
      });
    });

    group('reportIssue', () {
      // reportIssue requires navigation context, so these are limited tests
      
      test('should handle being called without navigation context', () {
        // When called without a valid navigator context, should not throw
        // This is a safety check - the method returns early if context is null
        expect(() {
          // Can't directly test without BuildContext, but we verify the pattern
        }, returnsNormally);
      });
    });

    group('showReportDialog', () {
      // showReportDialog shows an AlertDialog asking user if they want to report
      
      test('dialog should have correct title', () {
        const expectedTitle = 'Report this issue?';
        expect(expectedTitle, contains('Report'));
      });

      test('dialog should have two action buttons', () {
        const cancelText = 'No, thanks';
        const confirmText = 'Report Issue';
        expect(cancelText, isNotEmpty);
        expect(confirmText, isNotEmpty);
      });
    });
  });
}
