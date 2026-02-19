import 'package:securityexperts_app/core/analytics/analytics_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Analytics events for expert discovery and ratings.
///
/// Tracks expert search, profile views, and rating submissions.
class ExpertAnalytics {
  static AnalyticsService get _analytics => sl<AnalyticsService>();

  /// Expert search performed
  static Future<void> expertSearched({
    required int queryLength,
    required int resultsCount,
  }) async {
    await _analytics.logEvent(
      'expert_search',
      parameters: {
        'query_length': queryLength,
        'results_count': resultsCount,
      },
    );
  }

  /// Expert profile viewed
  static Future<void> expertProfileViewed({
    required bool isVerified,
  }) async {
    await _analytics.logEvent(
      'expert_view_profile',
      parameters: {'is_verified': isVerified},
    );
    _analytics.logBreadcrumb('Expert', 'viewed_profile');
  }

  /// Expert contacted (via chat or call)
  static Future<void> expertContacted({
    required String contactMethod, // 'chat' or 'call'
  }) async {
    await _analytics.logEvent(
      'expert_contact',
      parameters: {'method': contactMethod},
    );
    _analytics.logBreadcrumb('Expert', 'contacted_via_$contactMethod');
  }

  /// Expert list filtered
  static Future<void> expertFiltered({
    required String filterType, // 'skill', 'rating', 'availability'
  }) async {
    await _analytics.logEvent(
      'expert_filter',
      parameters: {'filter_type': filterType},
    );
  }
}

/// Analytics events for ratings.
class RatingAnalytics {
  static AnalyticsService get _analytics => sl<AnalyticsService>();

  /// Rating prompt shown to user
  static Future<void> ratingPromptShown() async {
    await _analytics.logEvent('rating_prompt_shown');
  }

  /// Rating submitted
  static Future<void> ratingSubmitted({
    required int stars,
    required bool hasComment,
  }) async {
    await _analytics.logEvent(
      'rating_submit',
      parameters: {
        'stars': stars,
        'has_comment': hasComment,
      },
    );
  }

  /// Rating prompt dismissed
  static Future<void> ratingPromptDismissed() async {
    await _analytics.logEvent('rating_prompt_dismissed');
  }

  /// Rating edited/updated
  static Future<void> ratingUpdated({
    required int oldStars,
    required int newStars,
  }) async {
    await _analytics.logEvent(
      'rating_update',
      parameters: {
        'old_stars': oldStars,
        'new_stars': newStars,
      },
    );
  }
}
