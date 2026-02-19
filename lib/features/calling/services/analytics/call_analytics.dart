import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Events that can be tracked by the analytics service
enum CallAnalyticsEvent {
  callStarted,
  callConnected,
  callEnded,
  callFailed,
  callTimeout,
  audioMuted,
  audioUnmuted,
  videoEnabled,
  videoDisabled,
  cameraSwitch,
  speakerToggled,
  networkQualityChange,
  reconnectAttempt,
  reconnectSuccess,
  reconnectFailed,
}

/// Data associated with an analytics event
class CallAnalyticsData {
  final CallAnalyticsEvent event;
  final DateTime timestamp;
  final Map<String, dynamic> properties;

  CallAnalyticsData({required this.event, required this.properties})
    : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
    'event': event.name,
    'timestamp': timestamp.toIso8601String(),
    'properties': properties,
  };
}

/// Call analytics service interface
///
/// Tracks call-related events and metrics for monitoring and improvement.
abstract class CallAnalytics {
  /// Track a call analytics event
  void trackEvent(CallAnalyticsEvent event, {Map<String, dynamic>? properties});

  /// Track call start
  void trackCallStart({
    required String callId,
    required bool isVideo,
    required bool isCaller,
    String? calleeId,
  });

  /// Track successful call connection
  void trackCallConnected({
    required String callId,
    required Duration connectionTime,
  });

  /// Track call end
  void trackCallEnd({
    required String callId,
    required Duration callDuration,
    required String endReason,
  });

  /// Track call failure
  void trackCallFailed({
    required String callId,
    required String errorType,
    required String errorMessage,
    Duration? attemptDuration,
  });

  /// Track user action during call
  void trackUserAction({
    required String callId,
    required CallAnalyticsEvent action,
    Map<String, dynamic>? metadata,
  });

  /// Track network quality change
  void trackNetworkQuality({
    required String callId,
    required String quality,
    Map<String, dynamic>? metrics,
  });

  /// Get analytics summary for reporting
  Map<String, dynamic> getSummary();

  /// Clear analytics data
  void clear();
}

/// Debug implementation of call analytics
///
/// Logs events to console and collects metrics in memory.
class DebugCallAnalytics implements CallAnalytics {
  final List<CallAnalyticsData> _events = [];
  final Map<String, int> _eventCounts = {};
  final Map<String, List<Duration>> _callDurations = {};
  int _totalCalls = 0;
  int _successfulCalls = 0;
  int _failedCalls = 0;

  @override
  void trackEvent(
    CallAnalyticsEvent event, {
    Map<String, dynamic>? properties,
  }) {
    final data = CallAnalyticsData(event: event, properties: properties ?? {});

    _events.add(data);
    _eventCounts[event.name] = (_eventCounts[event.name] ?? 0) + 1;

    sl<AppLogger>().debug('${event.name} - ${properties ?? {}}', tag: 'CallAnalytics');
  }

  @override
  void trackCallStart({
    required String callId,
    required bool isVideo,
    required bool isCaller,
    String? calleeId,
  }) {
    _totalCalls++;
    trackEvent(
      CallAnalyticsEvent.callStarted,
      properties: {
        'callId': callId,
        'isVideo': isVideo,
        'isCaller': isCaller,
        if (calleeId != null) 'calleeId': calleeId,
      },
    );
  }

  @override
  void trackCallConnected({
    required String callId,
    required Duration connectionTime,
  }) {
    trackEvent(
      CallAnalyticsEvent.callConnected,
      properties: {
        'callId': callId,
        'connectionTimeMs': connectionTime.inMilliseconds,
      },
    );
  }

  @override
  void trackCallEnd({
    required String callId,
    required Duration callDuration,
    required String endReason,
  }) {
    _successfulCalls++;

    // Track duration by reason
    _callDurations[endReason] = _callDurations[endReason] ?? [];
    _callDurations[endReason]!.add(callDuration);

    trackEvent(
      CallAnalyticsEvent.callEnded,
      properties: {
        'callId': callId,
        'durationSeconds': callDuration.inSeconds,
        'endReason': endReason,
      },
    );
  }

  @override
  void trackCallFailed({
    required String callId,
    required String errorType,
    required String errorMessage,
    Duration? attemptDuration,
  }) {
    _failedCalls++;

    trackEvent(
      CallAnalyticsEvent.callFailed,
      properties: {
        'callId': callId,
        'errorType': errorType,
        'errorMessage': errorMessage,
        if (attemptDuration != null)
          'attemptDurationMs': attemptDuration.inMilliseconds,
      },
    );
  }

  @override
  void trackUserAction({
    required String callId,
    required CallAnalyticsEvent action,
    Map<String, dynamic>? metadata,
  }) {
    trackEvent(action, properties: {'callId': callId, ...?metadata});
  }

  @override
  void trackNetworkQuality({
    required String callId,
    required String quality,
    Map<String, dynamic>? metrics,
  }) {
    trackEvent(
      CallAnalyticsEvent.networkQualityChange,
      properties: {'callId': callId, 'quality': quality, ...?metrics},
    );
  }

  @override
  Map<String, dynamic> getSummary() {
    final successRate = _totalCalls > 0
        ? (_successfulCalls / _totalCalls * 100).toStringAsFixed(1)
        : '0.0';

    // Calculate average call duration
    final allDurations = _callDurations.values.expand((d) => d).toList();
    final avgDuration = allDurations.isNotEmpty
        ? allDurations.reduce((a, b) => a + b) ~/ allDurations.length
        : Duration.zero;

    return {
      'totalCalls': _totalCalls,
      'successfulCalls': _successfulCalls,
      'failedCalls': _failedCalls,
      'successRate': '$successRate%',
      'averageCallDuration': avgDuration.inSeconds,
      'totalEvents': _events.length,
      'eventCounts': Map.from(_eventCounts),
      'callDurationsByReason': _callDurations.map(
        (key, value) => MapEntry(key, {
          'count': value.length,
          'avgSeconds': value.isEmpty
              ? 0
              : (value.reduce((a, b) => a + b).inSeconds / value.length)
                    .round(),
        }),
      ),
    };
  }

  @override
  void clear() {
    _events.clear();
    _eventCounts.clear();
    _callDurations.clear();
    _totalCalls = 0;
    _successfulCalls = 0;
    _failedCalls = 0;

    sl<AppLogger>().debug('Cleared all data', tag: 'CallAnalytics');
  }

  /// Get all tracked events (for testing)
  List<CallAnalyticsData> get events => List.unmodifiable(_events);

  /// Get event counts (for testing)
  Map<String, int> get eventCounts => Map.unmodifiable(_eventCounts);
}

/// Production implementation with Firebase Analytics
///
/// Sends analytics to Firebase for aggregation and reporting.
class ProductionCallAnalytics implements CallAnalytics {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final bool _enableLogging;

  ProductionCallAnalytics({bool enableLogging = false})
    : _enableLogging = enableLogging;

  @override
  void trackEvent(
    CallAnalyticsEvent event, {
    Map<String, dynamic>? properties,
  }) {
    // Convert properties to Firebase-compatible format (only String values)
    final params = <String, Object>{};
    if (properties != null) {
      for (final entry in properties.entries) {
        final value = entry.value;
        if (value is String ||
            value is int ||
            value is double ||
            value is bool) {
          params[entry.key] = value;
        } else if (value != null) {
          params[entry.key] = value.toString();
        }
      }
    }

    // Send to Firebase Analytics
    _analytics.logEvent(name: 'call_${event.name}', parameters: params);

    if (_enableLogging) {
      sl<AppLogger>().debug(
        'Production: ${event.name} - ${properties ?? {}}',
        tag: 'CallAnalytics',
      );
    }
  }

  @override
  void trackCallStart({
    required String callId,
    required bool isVideo,
    required bool isCaller,
    String? calleeId,
  }) {
    trackEvent(
      CallAnalyticsEvent.callStarted,
      properties: {
        'call_id': callId,
        'is_video': isVideo,
        'is_caller': isCaller,
      },
    );
  }

  @override
  void trackCallConnected({
    required String callId,
    required Duration connectionTime,
  }) {
    trackEvent(
      CallAnalyticsEvent.callConnected,
      properties: {
        'call_id': callId,
        'connection_time_ms': connectionTime.inMilliseconds,
      },
    );
  }

  @override
  void trackCallEnd({
    required String callId,
    required Duration callDuration,
    required String endReason,
  }) {
    trackEvent(
      CallAnalyticsEvent.callEnded,
      properties: {
        'call_id': callId,
        'duration_seconds': callDuration.inSeconds,
        'end_reason': endReason,
      },
    );
  }

  @override
  void trackCallFailed({
    required String callId,
    required String errorType,
    required String errorMessage,
    Duration? attemptDuration,
  }) {
    trackEvent(
      CallAnalyticsEvent.callFailed,
      properties: {
        'call_id': callId,
        'error_type': errorType,
        'error_message': errorMessage,
        if (attemptDuration != null)
          'attempt_duration_ms': attemptDuration.inMilliseconds,
      },
    );
  }

  @override
  void trackUserAction({
    required String callId,
    required CallAnalyticsEvent action,
    Map<String, dynamic>? metadata,
  }) {
    trackEvent(action, properties: {'call_id': callId, ...?metadata});
  }

  @override
  void trackNetworkQuality({
    required String callId,
    required String quality,
    Map<String, dynamic>? metrics,
  }) {
    trackEvent(
      CallAnalyticsEvent.networkQualityChange,
      properties: {'call_id': callId, 'quality': quality, ...?metrics},
    );
  }

  @override
  Map<String, dynamic> getSummary() {
    // In production, this would query from analytics backend
    return {
      'note': 'Production analytics - check Firebase console for details',
    };
  }

  @override
  void clear() {
    // No-op in production - data is remote
    if (_enableLogging) {
      sl<AppLogger>().debug('Production: Clear requested (no-op)', tag: 'CallAnalytics');
    }
  }
}
