import 'package:securityexperts_app/core/analytics/analytics_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Analytics events for support and help center.
///
/// Tracks support ticket creation, FAQ views, and feedback.
class SupportAnalytics {
  static AnalyticsService get _analytics => sl<AnalyticsService>();

  /// Support ticket created
  static Future<void> ticketCreated({
    required String category,
    required bool hasAttachment,
  }) async {
    await _analytics.logEvent(
      'support_create_ticket',
      parameters: {
        'category': category,
        'has_attachment': hasAttachment,
      },
    );
    _analytics.logBreadcrumb('Support', 'created_ticket');
  }

  /// Support ticket updated (user added comment)
  static Future<void> ticketUpdated() async {
    await _analytics.logEvent('support_update_ticket');
  }

  /// FAQ article viewed
  static Future<void> faqViewed({
    required String faqCategory,
  }) async {
    await _analytics.logEvent(
      'support_view_faq',
      parameters: {'category': faqCategory},
    );
  }

  /// FAQ search performed
  static Future<void> faqSearched({
    required int queryLength,
    required int resultsCount,
  }) async {
    await _analytics.logEvent(
      'support_search_faq',
      parameters: {
        'query_length': queryLength,
        'results_count': resultsCount,
      },
    );
  }

  /// FAQ marked as helpful/not helpful
  static Future<void> faqFeedback({
    required bool helpful,
  }) async {
    await _analytics.logEvent(
      'support_faq_feedback',
      parameters: {'helpful': helpful},
    );
  }

  /// Help center opened
  static Future<void> helpCenterOpened() async {
    await _analytics.logEvent('support_open_help_center');
    _analytics.logBreadcrumb('Support', 'opened_help_center');
  }

  /// Contact support tapped
  static Future<void> contactSupportTapped() async {
    await _analytics.logEvent('support_contact_tapped');
  }
}
