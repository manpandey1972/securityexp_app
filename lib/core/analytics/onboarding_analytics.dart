import 'package:greenhive_app/core/analytics/analytics_service.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Analytics events for user onboarding funnel.
///
/// Tracks onboarding progression, completion, and drop-offs.
class OnboardingAnalytics {
  static AnalyticsService get _analytics => sl<AnalyticsService>();

  /// Onboarding started
  static Future<void> started() async {
    await _analytics.logEvent('onboarding_start');
    _analytics.logBreadcrumb('Onboarding', 'started');
  }

  /// Onboarding step viewed
  static Future<void> stepViewed({
    required int stepNumber,
    required String stepName,
  }) async {
    await _analytics.logEvent(
      'onboarding_view_step',
      parameters: {
        'step_number': stepNumber,
        'step_name': stepName,
      },
    );
  }

  /// Onboarding step completed
  static Future<void> stepCompleted({
    required int stepNumber,
    required String stepName,
    int? durationSeconds,
  }) async {
    await _analytics.logEvent(
      'onboarding_complete_step',
      parameters: {
        'step_number': stepNumber,
        'step_name': stepName,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
      },
    );
  }

  /// Onboarding completed successfully
  static Future<void> completed({
    required int totalSteps,
    required int durationSeconds,
  }) async {
    await _analytics.logEvent(
      'onboarding_complete',
      parameters: {
        'total_steps': totalSteps,
        'duration_seconds': durationSeconds,
      },
    );
    _analytics.logBreadcrumb('Onboarding', 'completed');
  }

  /// Onboarding skipped
  static Future<void> skipped({
    required int stepNumber,
    required String stepName,
  }) async {
    await _analytics.logEvent(
      'onboarding_skip',
      parameters: {
        'skipped_at_step': stepNumber,
        'step_name': stepName,
      },
    );
    _analytics.logBreadcrumb('Onboarding', 'skipped_at_step_$stepNumber');
  }

  /// Permission requested during onboarding
  static Future<void> permissionRequested({
    required String permissionType,
  }) async {
    await _analytics.logEvent(
      'onboarding_permission_requested',
      parameters: {'permission_type': permissionType},
    );
  }

  /// Permission granted/denied during onboarding
  static Future<void> permissionResult({
    required String permissionType,
    required bool granted,
  }) async {
    await _analytics.logEvent(
      'onboarding_permission_result',
      parameters: {
        'permission_type': permissionType,
        'granted': granted,
      },
    );
  }

  /// Profile setup started
  static Future<void> profileSetupStarted() async {
    await _analytics.logEvent('onboarding_profile_setup_start');
  }

  /// Profile setup completed
  static Future<void> profileSetupCompleted({
    required bool hasAvatar,
    required bool hasDisplayName,
    required bool hasBio,
  }) async {
    await _analytics.logEvent(
      'onboarding_profile_setup_complete',
      parameters: {
        'has_avatar': hasAvatar,
        'has_display_name': hasDisplayName,
        'has_bio': hasBio,
      },
    );
  }

  /// Interests/topics selected during onboarding
  static Future<void> interestsSelected({
    required int interestsCount,
  }) async {
    await _analytics.logEvent(
      'onboarding_interests_selected',
      parameters: {'interests_count': interestsCount},
    );
  }
}
