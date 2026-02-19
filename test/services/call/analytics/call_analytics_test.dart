import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/calling/services/analytics/call_analytics.dart';

@GenerateMocks([AppLogger])
import 'call_analytics_test.mocks.dart';

void main() {
  late MockAppLogger mockAppLogger;

  setUp(() {
    mockAppLogger = MockAppLogger();
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('CallAnalytics - DebugImplementation', () {
    late DebugCallAnalytics analytics;

    setUp(() {
      analytics = DebugCallAnalytics();
    });

    tearDown(() {
      analytics.clear();
    });

    test('tracks call start event', () {
      analytics.trackCallStart(
        callId: 'test-call-1',
        isVideo: true,
        isCaller: true,
        calleeId: 'user-123',
      );

      expect(analytics.events.length, 1);
      expect(analytics.events.first.event, CallAnalyticsEvent.callStarted);
      expect(analytics.events.first.properties['callId'], 'test-call-1');
      expect(analytics.events.first.properties['isVideo'], true);
      expect(analytics.eventCounts['callStarted'], 1);
    });

    test('tracks call connected event', () {
      analytics.trackCallConnected(
        callId: 'test-call-1',
        connectionTime: const Duration(seconds: 2),
      );

      expect(analytics.events.length, 1);
      expect(analytics.events.first.event, CallAnalyticsEvent.callConnected);
      expect(analytics.events.first.properties['callId'], 'test-call-1');
      expect(analytics.events.first.properties['connectionTimeMs'], 2000);
    });

    test('tracks call end event', () {
      analytics.trackCallEnd(
        callId: 'test-call-1',
        callDuration: const Duration(minutes: 5, seconds: 30),
        endReason: 'user_ended',
      );

      expect(analytics.events.length, 1);
      expect(analytics.events.first.event, CallAnalyticsEvent.callEnded);
      expect(analytics.events.first.properties['durationSeconds'], 330);
      expect(analytics.events.first.properties['endReason'], 'user_ended');
    });

    test('tracks call failure', () {
      analytics.trackCallFailed(
        callId: 'test-call-1',
        errorType: 'CallNetworkError',
        errorMessage: 'Connection failed',
        attemptDuration: const Duration(seconds: 5),
      );

      expect(analytics.events.length, 1);
      expect(analytics.events.first.event, CallAnalyticsEvent.callFailed);
      expect(
        analytics.events.first.properties['errorType'],
        'CallNetworkError',
      );
    });

    test('tracks user actions', () {
      analytics.trackUserAction(
        callId: 'test-call-1',
        action: CallAnalyticsEvent.audioMuted,
      );

      analytics.trackUserAction(
        callId: 'test-call-1',
        action: CallAnalyticsEvent.videoDisabled,
      );

      expect(analytics.events.length, 2);
      expect(analytics.events[0].event, CallAnalyticsEvent.audioMuted);
      expect(analytics.events[1].event, CallAnalyticsEvent.videoDisabled);
    });

    test('tracks network quality changes', () {
      analytics.trackNetworkQuality(
        callId: 'test-call-1',
        quality: 'good',
        metrics: {'packetLoss': 1.5, 'latency': 45},
      );

      expect(analytics.events.length, 1);
      expect(
        analytics.events.first.event,
        CallAnalyticsEvent.networkQualityChange,
      );
      expect(analytics.events.first.properties['quality'], 'good');
    });

    test('maintains event counts', () {
      analytics.trackCallStart(callId: 'call-1', isVideo: true, isCaller: true);
      analytics.trackCallStart(
        callId: 'call-2',
        isVideo: false,
        isCaller: false,
      );
      analytics.trackUserAction(
        callId: 'call-1',
        action: CallAnalyticsEvent.audioMuted,
      );
      analytics.trackUserAction(
        callId: 'call-1',
        action: CallAnalyticsEvent.audioMuted,
      );

      expect(analytics.eventCounts['callStarted'], 2);
      expect(analytics.eventCounts['audioMuted'], 2);
    });

    test('calculates success metrics in summary', () {
      // Start 3 calls
      analytics.trackCallStart(callId: 'call-1', isVideo: true, isCaller: true);
      analytics.trackCallStart(callId: 'call-2', isVideo: true, isCaller: true);
      analytics.trackCallStart(callId: 'call-3', isVideo: true, isCaller: true);

      // 2 succeed
      analytics.trackCallEnd(
        callId: 'call-1',
        callDuration: const Duration(minutes: 5),
        endReason: 'user_ended',
      );
      analytics.trackCallEnd(
        callId: 'call-2',
        callDuration: const Duration(minutes: 3),
        endReason: 'user_ended',
      );

      // 1 fails
      analytics.trackCallFailed(
        callId: 'call-3',
        errorType: 'NetworkError',
        errorMessage: 'Failed',
      );

      final summary = analytics.getSummary();

      expect(summary['totalCalls'], 3);
      expect(summary['successfulCalls'], 2);
      expect(summary['failedCalls'], 1);
      expect(summary['successRate'], '66.7%');
      expect(
        summary['averageCallDuration'],
        240,
      ); // (300 + 180) / 2 = 240 seconds
    });

    test('tracks call durations by end reason', () {
      analytics.trackCallEnd(
        callId: 'call-1',
        callDuration: const Duration(minutes: 5),
        endReason: 'user_ended',
      );
      analytics.trackCallEnd(
        callId: 'call-2',
        callDuration: const Duration(minutes: 3),
        endReason: 'user_ended',
      );
      analytics.trackCallEnd(
        callId: 'call-3',
        callDuration: const Duration(seconds: 30),
        endReason: 'remote_ended',
      );

      final summary = analytics.getSummary();
      final durations = summary['callDurationsByReason'] as Map;

      expect(durations['user_ended']['count'], 2);
      expect(durations['user_ended']['avgSeconds'], 240); // (300 + 180) / 2
      expect(durations['remote_ended']['count'], 1);
      expect(durations['remote_ended']['avgSeconds'], 30);
    });

    test('clears all data', () {
      analytics.trackCallStart(callId: 'call-1', isVideo: true, isCaller: true);
      analytics.trackCallEnd(
        callId: 'call-1',
        callDuration: const Duration(minutes: 1),
        endReason: 'ended',
      );

      expect(analytics.events.length, 2);

      analytics.clear();

      expect(analytics.events.length, 0);
      expect(analytics.eventCounts.length, 0);

      final summary = analytics.getSummary();
      expect(summary['totalCalls'], 0);
      expect(summary['successfulCalls'], 0);
    });
  });

  group('CallAnalyticsData', () {
    test('creates with timestamp', () {
      final data = CallAnalyticsData(
        event: CallAnalyticsEvent.callStarted,
        properties: {'callId': 'test'},
      );

      expect(data.event, CallAnalyticsEvent.callStarted);
      expect(data.properties['callId'], 'test');
      expect(data.timestamp, isA<DateTime>());
    });

    test('converts to JSON', () {
      final data = CallAnalyticsData(
        event: CallAnalyticsEvent.callConnected,
        properties: {'callId': 'test', 'duration': 123},
      );

      final json = data.toJson();

      expect(json['event'], 'callConnected');
      expect(json['timestamp'], isA<String>());
      expect(json['properties']['callId'], 'test');
      expect(json['properties']['duration'], 123);
    });
  });
}
