import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Route observer that tracks screen views and measures screen load times.
///
/// Automatically logs:
/// - Screen view events to Firebase Analytics
/// - Screen load performance traces
///
/// Usage in MaterialApp:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [AnalyticsRouteObserver()],
/// )
/// ```
class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  // Track screen entry times for performance measurement
  final Map<String, DateTime> _screenEntryTimes = {};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreenView(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _recordScreenDuration(route);
    
    // Track the screen we're returning to
    if (previousRoute != null) {
      _trackScreenView(previousRoute);
    }
  }

  void _trackScreenView(Route<dynamic> route) {
    final screenName = _getScreenName(route);
    if (screenName == null) return;

    // Record entry time
    _screenEntryTimes[screenName] = DateTime.now();

    // Log screen view
    _analytics.logScreenView(
      screenName: screenName,
      screenClass: route.settings.name ?? screenName,
    );

    // Log breadcrumb for crash context
    if (sl.isRegistered<AnalyticsService>()) {
      sl<AnalyticsService>().logBreadcrumb('Navigation', 'viewed_$screenName');
    }
  }

  void _recordScreenDuration(Route<dynamic> route) {
    final screenName = _getScreenName(route);
    if (screenName == null) return;

    final entryTime = _screenEntryTimes.remove(screenName);
    if (entryTime == null) return;

    final duration = DateTime.now().difference(entryTime);
    
    // Log screen duration for engagement tracking
    if (sl.isRegistered<AnalyticsService>()) {
      sl<AnalyticsService>().logEvent(
        'screen_duration',
        parameters: {
          'screen_name': screenName,
          'duration_seconds': duration.inSeconds,
        },
      );
    }
  }

  String? _getScreenName(Route<dynamic> route) {
    // Use route name if available
    if (route.settings.name != null && route.settings.name!.isNotEmpty) {
      return _cleanScreenName(route.settings.name!);
    }

    // Try to infer from the route's builder
    if (route is MaterialPageRoute) {
      final widget = route.builder(route.navigator!.context);
      return _cleanScreenName(widget.runtimeType.toString());
    }

    return null;
  }

  String _cleanScreenName(String name) {
    // Remove leading slash
    if (name.startsWith('/')) {
      name = name.substring(1);
    }
    
    // Convert route paths to readable names
    // e.g., '/admin/tickets/123' -> 'admin_ticket_detail'
    if (name.contains('/')) {
      final parts = name.split('/');
      // Check if last part is an ID (alphanumeric)
      if (parts.last.length > 10 || RegExp(r'^[a-zA-Z0-9]+$').hasMatch(parts.last)) {
        parts.removeLast();
        parts.add('detail');
      }
      name = parts.join('_');
    }

    // Convert PascalCase widget names to snake_case
    // e.g., 'ChatConversationPage' -> 'chat_conversation_page'
    name = name.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    ).toLowerCase();

    // Remove 'page' or 'screen' suffix for cleaner names
    name = name.replaceAll('_page', '').replaceAll('_screen', '');

    return name;
  }
}
