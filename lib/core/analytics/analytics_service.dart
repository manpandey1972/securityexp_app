import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Check if Crashlytics is supported on the current platform.
/// Crashlytics is NOT supported on web.
bool get _isCrashlyticsSupported => !kIsWeb;

/// Check if Performance monitoring is supported on the current platform.
/// Performance has issues on web platform.
bool get _isPerformanceSupported => !kIsWeb;

/// Central analytics service for tracking events, performance, and errors.
///
/// This service provides a unified interface for:
/// - Firebase Analytics (user behavior tracking)
/// - Firebase Performance (app performance monitoring)
/// - Firebase Crashlytics (error reporting with context)
///
/// Usage:
/// ```dart
/// final analytics = sl<AnalyticsService>();
/// analytics.logEvent('button_clicked', parameters: {'button_id': 'submit'});
/// ```
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebasePerformance _performance = FirebasePerformance.instance;
  // Crashlytics is only available on mobile platforms, not web
  FirebaseCrashlytics? get _crashlytics =>
      _isCrashlyticsSupported ? FirebaseCrashlytics.instance : null;
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'Analytics';

  // ========================================
  // INITIALIZATION
  // ========================================

  /// Initialize analytics collection.
  /// Call this during app startup after Firebase.initializeApp()
  Future<void> initialize() async {
    try {
      // Enable performance collection (disabled by default in debug)
      await _performance.setPerformanceCollectionEnabled(!kDebugMode);

      // Enable analytics collection
      await _analytics.setAnalyticsCollectionEnabled(true);

      _log.info('Analytics initialized', tag: _tag);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to initialize analytics',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ========================================
  // EVENT TRACKING
  // ========================================

  /// Log a custom analytics event.
  ///
  /// [name] Event name (use snake_case, max 40 chars)
  /// [parameters] Optional event parameters (max 25 params, values max 100 chars)
  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      _log.warning('Failed to log event: $name', tag: _tag);
    }
  }

  /// Log screen view for screen tracking.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      _log.warning('Failed to log screen view: $screenName', tag: _tag);
    }
  }

  // ========================================
  // USER PROPERTIES
  // ========================================

  /// Set a user property for segmentation.
  ///
  /// [name] Property name (max 24 chars, alphanumeric + underscores)
  /// [value] Property value (max 36 chars, null to clear)
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      _log.warning('Failed to set user property: $name', tag: _tag);
    }
  }

  /// Set user ID for cross-device tracking.
  /// Pass null to clear the user ID.
  ///
  /// IMPORTANT: Never pass actual user IDs. Use a hashed/anonymized identifier.
  Future<void> setUserId(String? hashedUserId) async {
    try {
      await _analytics.setUserId(id: hashedUserId);
      // Also set for Crashlytics (only on supported platforms)
      if (hashedUserId != null && _isCrashlyticsSupported) {
        await _crashlytics?.setUserIdentifier(hashedUserId);
      }
    } catch (e) {
      _log.warning('Failed to set user ID', tag: _tag);
    }
  }

  /// Set user context on login for analytics and crash reporting.
  ///
  /// This is a simplified method for common login scenarios.
  /// For more granular control, use [setUserProperty] directly.
  Future<void> setUserOnLogin({
    required String userId,
    required bool isExpert,
    DateTime? accountCreatedAt,
  }) async {
    // Set Firebase Analytics user ID
    await setUserId(userId);

    // Set user properties
    await setUserProperty(name: 'user_type', value: isExpert ? 'expert' : 'regular');
    
    // Calculate account age bucket
    if (accountCreatedAt != null) {
      final daysOld = DateTime.now().difference(accountCreatedAt).inDays;
      String ageBucket;
      if (daysOld < 7) {
        ageBucket = 'new_1_week';
      } else if (daysOld < 30) {
        ageBucket = 'new_1_month';
      } else if (daysOld < 90) {
        ageBucket = 'active_3_months';
      } else if (daysOld < 365) {
        ageBucket = 'active_1_year';
      } else {
        ageBucket = 'veteran';
      }
      await setUserProperty(name: 'account_age', value: ageBucket);
    }

    // Set Crashlytics user identifier (only on supported platforms)
    if (_isCrashlyticsSupported) {
      _crashlytics?.setUserIdentifier(userId);
    }
    await setCrashlyticsKey('is_expert', isExpert.toString());
  }

  /// Set common user properties for segmentation.
  Future<void> setUserContext({
    required String userType, // 'regular' or 'expert'
    required String accountStatus,
    required String platform,
    required String appVersion,
    bool? isExpertVerified,
    String? accountAgeBucket,
  }) async {
    await setUserProperty(name: 'user_type', value: userType);
    await setUserProperty(name: 'account_status', value: accountStatus);
    await setUserProperty(name: 'platform', value: platform);
    await setUserProperty(name: 'app_version', value: appVersion);

    if (isExpertVerified != null) {
      await setUserProperty(
        name: 'expert_verified',
        value: isExpertVerified.toString(),
      );
    }

    if (accountAgeBucket != null) {
      await setUserProperty(name: 'account_age', value: accountAgeBucket);
    }
  }

  // ========================================
  // PERFORMANCE TRACES
  // ========================================

  /// Create a new performance trace.
  ///
  /// Remember to call start() and stop() on the trace.
  /// Use [traceAsync] for automatic handling.
  /// 
  /// Note: Returns a no-op trace on web platform due to Firebase limitations.
  Trace newTrace(String name) {
    if (!_isPerformanceSupported) {
      // Return a no-op trace for web platform
      return _NoOpTrace(name);
    }
    return _performance.newTrace(name);
  }

  /// Create a new HTTP metric for network monitoring.
  /// 
  /// Note: Returns a no-op metric on web platform due to Firebase limitations.
  HttpMetric newHttpMetric(String url, HttpMethod method) {
    if (!_isPerformanceSupported) {
      return _NoOpHttpMetric(url, method);
    }
    return _performance.newHttpMetric(url, method);
  }

  /// Execute an async operation with automatic performance tracing.
  ///
  /// Usage:
  /// ```dart
  /// final result = await analytics.traceAsync(
  ///   'call_setup',
  ///   attributes: {'call_type': 'video'},
  ///   () => callRepository.createCall(...),
  /// );
  /// ```
  Future<T> traceAsync<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
  }) async {
    final trace = _performance.newTrace(traceName);

    // Add attributes before starting
    attributes?.forEach((key, value) {
      trace.putAttribute(key, value);
    });

    await trace.start();

    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      return result;
    } catch (e) {
      trace.putAttribute('status', 'failed');
      trace.putAttribute('error_type', e.runtimeType.toString());
      rethrow;
    } finally {
      await trace.stop();
    }
  }

  // ========================================
  // CRASHLYTICS CONTEXT
  // ========================================

  /// Set custom key for Crashlytics error context.
  Future<void> setCrashlyticsKey(String key, dynamic value) async {
    if (!_isCrashlyticsSupported) return;
    try {
      if (value is String) {
        await _crashlytics?.setCustomKey(key, value);
      } else if (value is int) {
        await _crashlytics?.setCustomKey(key, value);
      } else if (value is double) {
        await _crashlytics?.setCustomKey(key, value);
      } else if (value is bool) {
        await _crashlytics?.setCustomKey(key, value);
      } else {
        await _crashlytics?.setCustomKey(key, value.toString());
      }
    } catch (e) {
      _log.warning('Failed to set Crashlytics key: $key', tag: _tag);
    }
  }

  /// Log a breadcrumb message to Crashlytics.
  /// These appear in crash reports to show user journey.
  void logBreadcrumb(String feature, String action) {
    if (!_isCrashlyticsSupported) return;
    try {
      _crashlytics?.log('[$feature] $action');
    } catch (e) {
      // Ignore breadcrumb failures
    }
  }

  /// Set current screen/feature context for crash reports.
  Future<void> setFeatureContext(String feature, String screen) async {
    await setCrashlyticsKey('current_feature', feature);
    await setCrashlyticsKey('current_screen', screen);
  }

  /// Record a non-fatal error to Crashlytics.
  Future<void> recordError({
    required dynamic error,
    required StackTrace stackTrace,
    required String feature,
    required String operation,
    Map<String, String>? metadata,
    bool fatal = false,
  }) async {
    if (!_isCrashlyticsSupported) return;
    try {
      await _crashlytics?.recordError(
        error,
        stackTrace,
        reason: '[$feature] $operation',
        information: [
          'feature: $feature',
          'operation: $operation',
          ...?metadata?.entries.map((e) => '${e.key}: ${e.value}'),
        ],
        fatal: fatal,
      );
    } catch (e) {
      _log.warning('Failed to record error to Crashlytics', tag: _tag);
    }
  }
}

/// No-op Trace implementation for platforms where Firebase Performance is not supported
class _NoOpTrace implements Trace {
  _NoOpTrace(String name);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void putAttribute(String name, String value) {}

  void putMetric(String name, int value) {}

  @override
  void setMetric(String name, int value) {}

  @override
  void incrementMetric(String name, int value) {}

  @override
  int getMetric(String name) => 0;

  @override
  void removeAttribute(String name) {}

  @override
  String? getAttribute(String name) => null;

  @override
  Map<String, String> getAttributes() => {};
}

/// No-op HttpMetric implementation for platforms where Firebase Performance is not supported
class _NoOpHttpMetric implements HttpMetric {
  final String _url;
  final HttpMethod _method;
  int? _httpResponseCode;
  int? _requestPayloadSize;
  String? _responseContentType;
  int? _responsePayloadSize;
  
  _NoOpHttpMetric(this._url, this._method);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void putAttribute(String name, String value) {}

  @override
  void removeAttribute(String name) {}

  @override
  String? getAttribute(String name) => null;

  @override
  Map<String, String> getAttributes() => {};

  HttpMethod? get httpMethod => _method;

  String? get url => _url;

  @override
  int? get httpResponseCode => _httpResponseCode;

  @override
  set httpResponseCode(int? code) => _httpResponseCode = code;

  @override
  int? get requestPayloadSize => _requestPayloadSize;

  @override
  set requestPayloadSize(int? bytes) => _requestPayloadSize = bytes;

  @override
  String? get responseContentType => _responseContentType;

  @override
  set responseContentType(String? type) => _responseContentType = type;

  @override
  int? get responsePayloadSize => _responsePayloadSize;

  @override
  set responsePayloadSize(int? bytes) => _responsePayloadSize = bytes;
}
