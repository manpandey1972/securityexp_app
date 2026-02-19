import 'package:flutter/material.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';
import 'package:greenhive_app/features/support/pages/new_ticket_page.dart';
import 'package:greenhive_app/shared/services/pending_notification_handler.dart';

/// Helper class for reporting issues from error states.
///
/// Provides convenient methods to navigate to the support ticket creation
/// with pre-filled bug report information.
class IssueReporter {
  /// Navigate to new ticket page with pre-filled bug report.
  ///
  /// Can optionally include error details to be added to the description.
  static void reportIssue({
    String? errorMessage,
    String? errorContext,
    String? stackTrace,
  }) {
    final context = PendingNotificationHandler.navigatorKey.currentContext;
    if (context == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewTicketPage(
          initialType: TicketType.bug,
          initialDescription: _buildDescription(
            errorMessage: errorMessage,
            errorContext: errorContext,
            stackTrace: stackTrace,
          ),
        ),
      ),
    );
  }

  /// Build a description with error details.
  static String _buildDescription({
    String? errorMessage,
    String? errorContext,
    String? stackTrace,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('**Issue Description:**');
    buffer.writeln('[Please describe what you were doing when the error occurred]');
    buffer.writeln();
    
    if (errorMessage != null || errorContext != null) {
      buffer.writeln('---');
      buffer.writeln('**Error Details (auto-captured):**');
      
      if (errorContext != null) {
        buffer.writeln('Context: $errorContext');
      }
      
      if (errorMessage != null) {
        buffer.writeln('Error: $errorMessage');
      }
      
      if (stackTrace != null) {
        buffer.writeln();
        buffer.writeln('Stack trace:');
        buffer.writeln('```');
        // Only include first 500 chars of stack trace
        final truncatedStack = stackTrace.length > 500
            ? '${stackTrace.substring(0, 500)}...'
            : stackTrace;
        buffer.writeln(truncatedStack);
        buffer.writeln('```');
      }
    }
    
    return buffer.toString();
  }

  /// Show a dialog asking if user wants to report the issue.
  static void showReportDialog(
    BuildContext context, {
    String? errorMessage,
    String? errorContext,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report this issue?'),
        content: const Text(
          'Would you like to report this issue to help us improve the app?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No, thanks'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              reportIssue(
                errorMessage: errorMessage,
                errorContext: errorContext,
              );
            },
            child: const Text('Report Issue'),
          ),
        ],
      ),
    );
  }
}
