import 'package:flutter/material.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/features/support/data/models/support_enums.dart';
import 'package:securityexperts_app/features/support/services/support_service.dart';
import 'package:securityexperts_app/shared/services/hidden_messages_service.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';

/// Provides a bottom-sheet UI to report a user or a specific message.
///
/// Usage:
/// ```dart
/// await ReportService.showReportDialog(
///   context,
///   reportedUserId: message.senderId,
///   reportedMessageId: message.id,   // optional
///   reportedUserName: partnerName,   // optional
/// );
/// ```
class ReportService {
  static const _tag = 'ReportService';

  static const _reasons = [
    'Harassment or bullying',
    'Spam or unwanted messages',
    'Inappropriate or sexual content',
    'Hate speech or discrimination',
    'Threats or violence',
    'Impersonation',
    'Other',
  ];

  /// Shows a bottom-sheet letting the current user submit a report.
  static Future<void> showReportDialog(
    BuildContext context, {
    required String reportedUserId,
    String? reportedMessageId,
    String? reportedUserName,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReportSheet(
        reportedUserId: reportedUserId,
        reportedMessageId: reportedMessageId,
        reportedUserName: reportedUserName,
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final String reportedUserId;
  final String? reportedMessageId;
  final String? reportedUserName;

  const _ReportSheet({
    required this.reportedUserId,
    this.reportedMessageId,
    this.reportedUserName,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  int? _selectedIndex;
  bool _submitting = false;
  final _log = sl<AppLogger>();

  Future<void> _submit() async {
    if (_selectedIndex == null || _submitting) return;
    setState(() => _submitting = true);

    final reason = ReportService._reasons[_selectedIndex!];
    final isContentReport = widget.reportedMessageId != null;
    final type = isContentReport
        ? TicketType.reportContent
        : TicketType.reportUser;
    final targetName = widget.reportedUserName ?? 'Unknown user';
    final subject = isContentReport
        ? 'Report: Inappropriate message from $targetName'
        : 'Report: Abusive user $targetName';
    // Capture reporter identity explicitly in the description so a
    // moderator viewing the ticket has full context without needing to
    // cross-reference the ticket's `userId`/`userName` fields. Mirrors
    // the block-user ticket format for consistency.
    final reporterProfile = UserProfileService().userProfile;
    final reporterId = reporterProfile?.id ?? 'unknown';
    final reporterName = reporterProfile?.name ?? 'Unknown';
    final description =
        'Reason: $reason\n'
        'Reporter user ID: $reporterId\n'
        'Reporter user name: $reporterName\n'
        'Reported user ID: ${widget.reportedUserId}\n'
        'Reported user name: $targetName'
        '${widget.reportedMessageId != null ? '\nMessage ID: ${widget.reportedMessageId}' : ''}';

    await ErrorHandler.handle<void>(
      operation: () async {
        final result = await sl<SupportService>().createTicket(
          type: type,
          category: TicketCategory.safety,
          subject: subject,
          description: description,
        );
        if (!result.isSuccess) {
          throw Exception('Failed to submit report: ${result.error?.message}');
        }
        // Apple 1.2: hide the reported message immediately for the
        // reporter (per-user hide). Other participants still see the
        // message until/unless an admin removes it via moderation.
        // Best-effort: failure to hide must not surface as a report
        // failure since the ticket has already been created.
        if (widget.reportedMessageId != null) {
          try {
            await sl<HiddenMessagesService>()
                .hideMessage(widget.reportedMessageId!);
          } catch (e) {
            _log.warning(
              'Hide-on-report failed for messageId='
              '${widget.reportedMessageId}: $e',
              tag: ReportService._tag,
            );
          }
        }
      },
      onError: (e) => _log.error('Report submission error: $e', tag: ReportService._tag),
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you for helping keep GreenHive safe.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              widget.reportedMessageId != null
                  ? 'Report Message'
                  : 'Report User',
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Why are you reporting this'
              '${widget.reportedMessageId != null ? ' message' : ' user'}?',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<int>(
            groupValue: _selectedIndex,
            onChanged: (v) => setState(() => _selectedIndex = v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(ReportService._reasons.length, (i) {
                return RadioListTile<int>(
                  value: i,
                  activeColor: AppColors.primary,
                  title: Text(
                    ReportService._reasons[i],
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedIndex != null && !_submitting
                    ? _submit
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  disabledBackgroundColor:
                      AppColors.error.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Submit Report',
                        style: AppTypography.bodyEmphasis.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
