# Observability & Monitoring Design for GreenHive App

## Executive Summary

This document outlines a comprehensive observability strategy for the GreenHive Flutter app using Firebase services. The goal is to enable administrators to:
1. Detect issues proactively before users report them
2. Triage and identify root causes quickly
3. Track key business and performance metrics
4. Understand user behavior and app health

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Crash & Error Monitoring](#2-crash--error-monitoring)
3. [Performance Monitoring](#3-performance-monitoring)
4. [Analytics Strategy](#4-analytics-strategy)
5. [Alerting & Dashboards](#5-alerting--dashboards)
6. [Implementation Guide](#6-implementation-guide)

---

## 1. Architecture Overview

### 1.1 Firebase Services Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                     GreenHive Flutter App                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │  AppLogger  │  │ ErrorHandler │  │  AnalyticsService       │ │
│  │  (existing) │  │  (existing)  │  │  (to implement)         │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
│         │                │                      │                │
└─────────┼────────────────┼──────────────────────┼────────────────┘
          │                │                      │
          ▼                ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Firebase Services                            │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Crashlytics   │   Performance   │      Analytics              │
│   (Errors &     │   Monitoring    │   (Events & User            │
│   Crashes)      │   (APM)         │    Properties)              │
├─────────────────┴─────────────────┴─────────────────────────────┤
│                     BigQuery Export                              │
│              (Advanced Analysis & Custom Dashboards)             │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Current State Assessment

**Already Implemented:**
- ✅ `AppLogger` with debug/production modes
- ✅ Crashlytics integration for error logging
- ✅ Log level filtering (verbose → error)
- ✅ Breadcrumb logging for context

**Needs Implementation:**
- ⏳ Firebase Analytics event tracking
- ⏳ Firebase Performance Monitoring
- ⏳ Custom traces for critical paths
- ⏳ User segmentation properties
- ⏳ Alerting configuration

---

## 2. Crash & Error Monitoring

### 2.1 Crashlytics Configuration

#### Fatal Crashes (Automatic)
```dart
// In main.dart - already configured
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

#### Non-Fatal Errors (Enhanced)
```dart
// Enhanced error recording with context
class CrashlyticsService {
  static void recordError({
    required dynamic error,
    required StackTrace stackTrace,
    required String feature,
    required String operation,
    Map<String, String>? metadata,
  }) {
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: '[$feature] $operation',
      information: [
        'feature: $feature',
        'operation: $operation',
        ...?metadata?.entries.map((e) => '${e.key}: ${e.value}'),
      ],
      fatal: false,
    );
  }
}
```

### 2.2 Error Categories by Feature

| Feature | Error Types to Track | Severity |
|---------|---------------------|----------|
| **Authentication** | OTP failures, session expiry, token refresh failures | Critical |
| **Calling** | WebRTC failures, call drops, token generation errors | Critical |
| **Chat** | Message send failures, media upload failures, sync errors | High |
| **Notifications** | FCM registration failures, VoIP token errors | High |
| **Profile** | Image upload failures, profile update errors | Medium |
| **Ratings** | Rating submission failures | Medium |
| **Support** | Ticket creation failures | Medium |

### 2.3 Custom Keys for Triage

```dart
// Set user context for better triage
void setUserContext(User user) {
  final crashlytics = FirebaseCrashlytics.instance;
  
  // NEVER log actual user ID - use hashed version
  crashlytics.setUserIdentifier(user.id.hashCode.toString());
  
  crashlytics.setCustomKey('user_role', user.role.name);
  crashlytics.setCustomKey('account_age_days', user.accountAgeDays);
  crashlytics.setCustomKey('platform', Platform.isIOS ? 'ios' : 'android');
  crashlytics.setCustomKey('app_version', packageInfo.version);
  crashlytics.setCustomKey('is_expert', user.isExpert);
}

// Set feature context before operations
void setFeatureContext(String feature, String screen) {
  FirebaseCrashlytics.instance.setCustomKey('current_feature', feature);
  FirebaseCrashlytics.instance.setCustomKey('current_screen', screen);
}
```

### 2.4 Breadcrumb Strategy

```dart
// Log breadcrumbs for crash context (last 64 are retained)
void logBreadcrumb(String feature, String action, {Map<String, dynamic>? data}) {
  final message = '[$feature] $action';
  FirebaseCrashlytics.instance.log(message);
}

// Example usage:
logBreadcrumb('Chat', 'opened_conversation');
logBreadcrumb('Chat', 'sending_message', data: {'type': 'text'});
logBreadcrumb('Chat', 'message_sent');
```

---

## 3. Performance Monitoring

### 3.1 Automatic Monitoring (Enable These)

```dart
// In main.dart
await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
```

**Automatically Tracked:**
- App start time (cold/warm)
- Screen rendering time
- HTTP/S network requests
- Screen traces

### 3.2 Custom Traces for Critical Paths

#### Call Flow Traces
```dart
class CallPerformanceTraces {
  static Future<T> traceCallSetup<T>(Future<T> Function() operation) async {
    final trace = FirebasePerformance.instance.newTrace('call_setup');
    await trace.start();
    
    try {
      trace.putAttribute('provider', 'livekit');
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
  
  static Trace startCallDuration(String callType) {
    final trace = FirebasePerformance.instance.newTrace('call_duration');
    trace.putAttribute('call_type', callType); // 'video' or 'audio'
    trace.start();
    return trace;
  }
}
```

#### Chat Performance Traces
```dart
class ChatPerformanceTraces {
  static Future<T> traceMessageSend<T>(
    String messageType,
    Future<T> Function() operation,
  ) async {
    final trace = FirebasePerformance.instance.newTrace('message_send');
    await trace.start();
    trace.putAttribute('message_type', messageType);
    
    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      return result;
    } catch (e) {
      trace.putAttribute('status', 'failed');
      rethrow;
    } finally {
      await trace.stop();
    }
  }
  
  static Future<T> traceMediaUpload<T>(
    String mediaType,
    int sizeBytes,
    Future<T> Function() operation,
  ) async {
    final trace = FirebasePerformance.instance.newTrace('media_upload');
    await trace.start();
    trace.putAttribute('media_type', mediaType);
    trace.putMetric('size_bytes', sizeBytes);
    
    try {
      final result = await operation();
      trace.putAttribute('status', 'success');
      return result;
    } catch (e) {
      trace.putAttribute('status', 'failed');
      rethrow;
    } finally {
      await trace.stop();
    }
  }
}
```

#### Authentication Traces
```dart
class AuthPerformanceTraces {
  static Future<T> traceOTPVerification<T>(Future<T> Function() operation) async {
    final trace = FirebasePerformance.instance.newTrace('otp_verification');
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
}
```

### 3.3 Network Monitoring

```dart
// Custom HTTP metric for API calls
class ApiPerformanceMonitor {
  static HttpMetric startApiCall(String endpoint, HttpMethod method) {
    final metric = FirebasePerformance.instance.newHttpMetric(
      endpoint,
      method,
    );
    metric.start();
    return metric;
  }
  
  static void endApiCall(
    HttpMetric metric, {
    required int responseCode,
    required int responsePayloadSize,
    String? contentType,
  }) {
    metric.httpResponseCode = responseCode;
    metric.responsePayloadSize = responsePayloadSize;
    if (contentType != null) {
      metric.responseContentType = contentType;
    }
    metric.stop();
  }
}
```

### 3.4 Screen Performance

```dart
// Track screen rendering performance
class ScreenTrace {
  Trace? _trace;
  
  void startScreen(String screenName) {
    _trace = FirebasePerformance.instance.newTrace('screen_$screenName');
    _trace?.start();
  }
  
  void screenReady() {
    _trace?.putAttribute('status', 'rendered');
  }
  
  void screenError(String error) {
    _trace?.putAttribute('status', 'error');
    _trace?.putAttribute('error', error);
  }
  
  void endScreen() {
    _trace?.stop();
  }
}
```

---

## 4. Analytics Strategy

### 4.1 Event Taxonomy

#### Naming Convention
```
<feature>_<action>_<object>

Examples:
- chat_send_message
- call_start_video
- profile_update_photo
- auth_complete_verification
```

### 4.2 Core Events by Feature

#### Authentication Events
```dart
class AuthAnalytics {
  static void phoneEntered() {
    FirebaseAnalytics.instance.logEvent(
      name: 'auth_enter_phone',
    );
  }
  
  static void otpRequested() {
    FirebaseAnalytics.instance.logEvent(
      name: 'auth_request_otp',
    );
  }
  
  static void otpVerified({required bool success}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'auth_verify_otp',
      parameters: {'success': success},
    );
  }
  
  static void signupComplete() {
    FirebaseAnalytics.instance.logEvent(name: 'auth_signup_complete');
  }
  
  static void loginComplete() {
    FirebaseAnalytics.instance.logEvent(name: 'auth_login_complete');
  }
  
  static void logout() {
    FirebaseAnalytics.instance.logEvent(name: 'auth_logout');
  }
}
```

#### Calling Events
```dart
class CallAnalytics {
  static void callInitiated({
    required String callType, // 'audio' or 'video'
    required bool isExpertCall,
  }) {
    FirebaseAnalytics.instance.logEvent(
      name: 'call_initiate',
      parameters: {
        'call_type': callType,
        'is_expert_call': isExpertCall,
      },
    );
  }
  
  static void callConnected({
    required String callType,
    required int setupDurationMs,
  }) {
    FirebaseAnalytics.instance.logEvent(
      name: 'call_connected',
      parameters: {
        'call_type': callType,
        'setup_duration_ms': setupDurationMs,
      },
    );
  }
  
  static void callEnded({
    required String callType,
    required int durationSeconds,
    required String endReason, // 'user_hangup', 'remote_hangup', 'error', 'timeout'
  }) {
    FirebaseAnalytics.instance.logEvent(
      name: 'call_ended',
      parameters: {
        'call_type': callType,
        'duration_seconds': durationSeconds,
        'end_reason': endReason,
      },
    );
  }
  
  static void callFailed({
    required String callType,
    required String failureReason,
  }) {
    FirebaseAnalytics.instance.logEvent(
      name: 'call_failed',
      parameters: {
        'call_type': callType,
        'failure_reason': failureReason,
      },
    );
  }
}
```

#### Chat Events
```dart
class ChatAnalytics {
  static void conversationOpened() {
    FirebaseAnalytics.instance.logEvent(name: 'chat_open_conversation');
  }
  
  static void messageSent({required String messageType}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'chat_send_message',
      parameters: {'message_type': messageType}, // 'text', 'image', 'video', 'audio'
    );
  }
  
  static void mediaViewed({required String mediaType}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'chat_view_media',
      parameters: {'media_type': mediaType},
    );
  }
  
  static void chatCleared() {
    FirebaseAnalytics.instance.logEvent(name: 'chat_clear_history');
  }
  
  static void chatDeleted() {
    FirebaseAnalytics.instance.logEvent(name: 'chat_delete_conversation');
  }
}
```

#### Expert & Ratings Events
```dart
class ExpertAnalytics {
  static void expertProfileViewed({required bool isVerified}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'expert_view_profile',
      parameters: {'is_verified': isVerified},
    );
  }
  
  static void expertSearched({required String query}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'expert_search',
      parameters: {'query_length': query.length},
    );
  }
  
  static void expertContacted({required String contactMethod}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'expert_contact',
      parameters: {'method': contactMethod}, // 'chat', 'call'
    );
  }
  
  static void ratingSubmitted({
    required int stars,
    required bool hasComment,
  }) {
    FirebaseAnalytics.instance.logEvent(
      name: 'rating_submit',
      parameters: {
        'stars': stars,
        'has_comment': hasComment,
      },
    );
  }
}
```

#### Support Events
```dart
class SupportAnalytics {
  static void supportTicketCreated({required String category}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'support_create_ticket',
      parameters: {'category': category},
    );
  }
  
  static void faqViewed({required String faqId}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'support_view_faq',
      parameters: {'faq_id': faqId},
    );
  }
}
```

#### Onboarding Events
```dart
class OnboardingAnalytics {
  static void stepCompleted({required int step, required String stepName}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'onboarding_step_complete',
      parameters: {
        'step_number': step,
        'step_name': stepName,
      },
    );
  }
  
  static void onboardingCompleted({required int totalTimeSeconds}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'onboarding_complete',
      parameters: {'total_time_seconds': totalTimeSeconds},
    );
  }
  
  static void onboardingAbandoned({required int lastStep}) {
    FirebaseAnalytics.instance.logEvent(
      name: 'onboarding_abandoned',
      parameters: {'last_step': lastStep},
    );
  }
}
```

### 4.3 User Properties

```dart
class UserProperties {
  static void setUserProperties(User user) {
    final analytics = FirebaseAnalytics.instance;
    
    // User type
    analytics.setUserProperty(name: 'user_type', value: user.isExpert ? 'expert' : 'regular');
    
    // Account status
    analytics.setUserProperty(name: 'account_status', value: user.status.name);
    
    // Verification status (for experts)
    if (user.isExpert) {
      analytics.setUserProperty(name: 'expert_verified', value: user.isVerified.toString());
    }
    
    // Account age bucket
    final ageBucket = _getAgeBucket(user.createdAt);
    analytics.setUserProperty(name: 'account_age', value: ageBucket);
    
    // Platform
    analytics.setUserProperty(
      name: 'platform',
      value: Platform.isIOS ? 'ios' : 'android',
    );
    
    // App version
    analytics.setUserProperty(name: 'app_version', value: packageInfo.version);
  }
  
  static String _getAgeBucket(DateTime createdAt) {
    final days = DateTime.now().difference(createdAt).inDays;
    if (days < 1) return '0_day';
    if (days < 7) return '1_7_days';
    if (days < 30) return '8_30_days';
    if (days < 90) return '31_90_days';
    return '90_plus_days';
  }
}
```

### 4.4 Conversion Funnels

#### User Acquisition Funnel
```
app_open → auth_enter_phone → auth_request_otp → auth_verify_otp → auth_signup_complete
```

#### Expert Engagement Funnel
```
expert_search → expert_view_profile → expert_contact → call_initiate → call_connected
```

#### Chat Engagement Funnel
```
chat_open_conversation → chat_send_message → chat_view_media
```

---

## 5. Alerting & Dashboards

### 5.1 Firebase Console Alerts

Configure these alerts in Firebase Console:

| Alert | Threshold | Priority |
|-------|-----------|----------|
| **Crash-free users drop** | < 99% | Critical |
| **New crash cluster** | Any new | High |
| **Velocity alert** (crash spike) | > 1% in 1 hour | Critical |
| **Regression alert** | New version crashes | High |

### 5.2 Custom Metrics to Monitor

#### Health Metrics Dashboard
```
┌─────────────────────────────────────────────────────────────────┐
│                    App Health Dashboard                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Crash-Free Rate     Call Success Rate    Message Delivery      │
│  ┌────────────┐      ┌────────────┐       ┌────────────┐        │
│  │   99.2%    │      │   94.5%    │       │   99.8%    │        │
│  │   ↑ 0.1%   │      │   ↓ 0.3%   │       │   ─        │        │
│  └────────────┘      └────────────┘       └────────────┘        │
│                                                                  │
│  OTP Success Rate    Avg Call Setup       Media Upload Time     │
│  ┌────────────┐      ┌────────────┐       ┌────────────┐        │
│  │   98.7%    │      │   2.3s     │       │   4.1s     │        │
│  │   ↑ 0.5%   │      │   ↓ 0.2s   │       │   ↑ 0.3s   │        │
│  └────────────┘      └────────────┘       └────────────┘        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Key Metrics to Track

**Reliability Metrics:**
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Crash-free sessions | > 99.5% | < 99% |
| OTP verification success | > 98% | < 95% |
| Call connection success | > 95% | < 90% |
| Message delivery success | > 99.5% | < 99% |
| Media upload success | > 98% | < 95% |

**Performance Metrics:**
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| App cold start | < 3s | > 5s |
| Call setup time | < 3s | > 5s |
| Message send time | < 1s | > 3s |
| Media upload time (image) | < 5s | > 10s |
| Screen TTI (time to interactive) | < 1s | > 2s |

**Engagement Metrics:**
| Metric | Description |
|--------|-------------|
| DAU/MAU | Daily/Monthly active users |
| Calls per user per week | Average calling frequency |
| Messages per user per day | Chat engagement |
| Expert consultation rate | % users contacting experts |
| Session duration | Time spent in app |
| Retention (D1, D7, D30) | User return rate |

### 5.3 BigQuery Export for Advanced Analysis

Enable BigQuery export in Firebase for:
- Custom SQL analysis
- Long-term trend analysis
- Cohort analysis
- A/B test analysis

```sql
-- Example: Call failure analysis
SELECT
  event_date,
  event_params.value.string_value AS failure_reason,
  COUNT(*) as failure_count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY event_date) as failure_pct
FROM `project.analytics_*.events_*`
WHERE event_name = 'call_failed'
  AND _TABLE_SUFFIX BETWEEN '20260101' AND '20260131'
GROUP BY event_date, failure_reason
ORDER BY event_date, failure_count DESC;
```

---

## 6. Implementation Guide

### 6.1 Analytics Service Implementation

```dart
// lib/core/analytics/analytics_service.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebasePerformance _performance = FirebasePerformance.instance;

  // ========== SCREEN TRACKING ==========
  
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
  }

  // ========== GENERIC EVENT LOGGING ==========
  
  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(
      name: name,
      parameters: parameters,
    );
  }

  // ========== USER PROPERTIES ==========
  
  Future<void> setUserProperty(String name, String? value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  // ========== PERFORMANCE TRACES ==========
  
  Trace newTrace(String name) {
    return _performance.newTrace(name);
  }

  HttpMetric newHttpMetric(String url, HttpMethod method) {
    return _performance.newHttpMetric(url, method);
  }
}

// Convenience extension for async trace handling
extension TraceExtension on Trace {
  Future<T> traceAsync<T>(Future<T> Function() operation) async {
    await start();
    try {
      final result = await operation();
      putAttribute('status', 'success');
      return result;
    } catch (e) {
      putAttribute('status', 'failed');
      putAttribute('error_type', e.runtimeType.toString());
      rethrow;
    } finally {
      await stop();
    }
  }
}
```

### 6.2 Integration Points

#### In Feature ViewModels/Blocs
```dart
class CallViewModel extends ChangeNotifier {
  Future<void> initiateCall(String calleeId, bool isVideo) async {
    // Track analytics
    CallAnalytics.callInitiated(
      callType: isVideo ? 'video' : 'audio',
      isExpertCall: _isExpertCall(calleeId),
    );
    
    // Performance trace
    final trace = FirebasePerformance.instance.newTrace('call_setup');
    await trace.start();
    
    try {
      // Actual call logic
      await _callRepository.createCall(...);
      
      trace.putAttribute('status', 'success');
      CallAnalytics.callConnected(
        callType: isVideo ? 'video' : 'audio',
        setupDurationMs: setupTime,
      );
    } catch (e) {
      trace.putAttribute('status', 'failed');
      CallAnalytics.callFailed(
        callType: isVideo ? 'video' : 'audio',
        failureReason: _classifyError(e),
      );
      rethrow;
    } finally {
      await trace.stop();
    }
  }
}
```

### 6.3 Checklist for Implementation

**Phase 1: Foundation (Week 1)**
- [ ] Create `AnalyticsService` singleton
- [ ] Add to service locator
- [ ] Enable Firebase Performance collection
- [ ] Verify Crashlytics is capturing errors

**Phase 2: Core Events (Week 2)**
- [ ] Implement `AuthAnalytics` events
- [ ] Implement `CallAnalytics` events
- [ ] Implement `ChatAnalytics` events
- [ ] Set up user properties on login

**Phase 3: Performance Traces (Week 3)**
- [ ] Add call setup traces
- [ ] Add message send traces
- [ ] Add media upload traces
- [ ] Add screen performance traces

**Phase 4: Advanced (Week 4)**
- [ ] Implement `ExpertAnalytics` events
- [ ] Implement `SupportAnalytics` events
- [ ] Configure Firebase Console alerts
- [ ] Enable BigQuery export
- [ ] Create initial dashboards

---

## 7. Troubleshooting Playbook

### 7.1 Common Issues & Root Cause Analysis

#### High Call Failure Rate
```
1. Check Crashlytics for 'call_' tagged errors
2. Check Performance → call_setup trace durations
3. Filter by:
   - Device model (older devices may struggle)
   - Network type (wifi vs cellular)
   - OS version
4. Check Cloud Functions logs for token generation errors
```

#### Message Delivery Issues
```
1. Check Crashlytics for 'Chat' tagged errors
2. Check FCM delivery reports in Firebase Console
3. Verify Firestore write success rates
4. Check for network connectivity issues (offline mode)
```

#### Authentication Failures
```
1. Check auth_verify_otp success rate in Analytics
2. Check Crashlytics for 'Auth' tagged errors
3. Verify Firebase Auth quotas not exceeded
4. Check for specific error codes (invalid-verification-code, etc.)
```

### 7.2 Quick Reference: Where to Look

| Symptom | Primary Tool | Secondary Tool |
|---------|-------------|----------------|
| App crashes | Crashlytics | - |
| Slow performance | Performance | BigQuery |
| Feature not working | Crashlytics + Logs | Analytics events |
| User complaints | Analytics funnels | Crashlytics breadcrumbs |
| Revenue drop | Analytics | User properties |

---

## 8. Data Privacy Considerations

### 8.1 What NOT to Log

| Data Type | Status | Alternative |
|-----------|--------|-------------|
| User IDs | ❌ Never | Use hashed identifiers |
| Phone numbers | ❌ Never | - |
| Email addresses | ❌ Never | - |
| Chat content | ❌ Never | Log message type only |
| FCM/VoIP tokens | ❌ Never | - |
| Room/Chat IDs | ❌ Never | Use generic labels |
| File paths/URLs | ❌ Never | Log file type only |

### 8.2 Compliant Logging Examples

```dart
// ❌ BAD
_log.info('User abc123 sent message: Hello world');

// ✅ GOOD
_log.info('Message sent', tag: 'Chat', data: {'type': 'text'});


// ❌ BAD
FirebaseAnalytics.instance.logEvent(
  name: 'call_started',
  parameters: {'caller_id': userId, 'room_id': roomId},
);

// ✅ GOOD
FirebaseAnalytics.instance.logEvent(
  name: 'call_started',
  parameters: {'call_type': 'video', 'is_expert_call': true},
);
```

---

## Summary

This observability strategy provides:

1. **Crash & Error Detection** via Crashlytics with proper context
2. **Performance Monitoring** with custom traces for critical paths
3. **Analytics** for user behavior and feature adoption
4. **Alerting** for proactive issue detection
5. **Privacy-compliant** logging practices

Implementing this will enable the admin team to:
- Detect issues before users report them
- Quickly identify root causes with proper context
- Track feature adoption and engagement
- Make data-driven product decisions
