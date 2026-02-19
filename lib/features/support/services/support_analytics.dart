import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

import '../data/models/models.dart';

/// Events that can be tracked by the support analytics service
enum SupportAnalyticsEvent {
  hubOpened,
  ticketStarted,
  ticketSubmitted,
  ticketViewed,
  messageSent,
  satisfactionRated,
  attachmentAdded,
  ticketFiltered,
}

/// Support analytics service for tracking user interactions with the support feature.
///
/// Access via service locator: `sl<SupportAnalytics>()`
class SupportAnalytics {
  final FirebaseAnalytics _analytics;
  final AppLogger _log;

  static const String _tag = 'SupportAnalytics';

  SupportAnalytics({
    FirebaseAnalytics? analytics,
    AppLogger? log,
  })  : _analytics = analytics ?? FirebaseAnalytics.instance,
        _log = log ?? sl<AppLogger>();

  /// Track support hub opened
  Future<void> trackHubOpened() async {
    await _logEvent(
      SupportAnalyticsEvent.hubOpened,
      eventName: 'support_hub_opened',
    );
  }

  /// Track ticket creation started
  Future<void> trackTicketStarted({
    required TicketType type,
  }) async {
    await _logEvent(
      SupportAnalyticsEvent.ticketStarted,
      eventName: 'support_ticket_started',
      parameters: {
        'ticket_type': type.name,
      },
    );
  }

  /// Track ticket submitted successfully
  Future<void> trackTicketSubmitted({
    required String ticketId,
    required TicketType type,
    required TicketCategory category,
    required TicketPriority priority,
    required int attachmentCount,
  }) async {
    await _logEvent(
      SupportAnalyticsEvent.ticketSubmitted,
      eventName: 'support_ticket_submitted',
      parameters: {
        'ticket_id': ticketId,
        'ticket_type': type.name,
        'ticket_category': category.name,
        'ticket_priority': priority.name,
        'attachment_count': attachmentCount,
      },
    );
  }

  /// Track ticket viewed
  Future<void> trackTicketViewed({
    required String ticketId,
    required TicketStatus status,
  }) async {
    await _logEvent(
      SupportAnalyticsEvent.ticketViewed,
      eventName: 'support_ticket_viewed',
      parameters: {
        'ticket_id': ticketId,
        'ticket_status': status.name,
      },
    );
  }

  /// Track message sent in ticket conversation
  Future<void> trackMessageSent({
    required String ticketId,
    required int attachmentCount,
  }) async {
    await _logEvent(
      SupportAnalyticsEvent.messageSent,
      eventName: 'support_message_sent',
      parameters: {
        'ticket_id': ticketId,
        'attachment_count': attachmentCount,
      },
    );
  }

  /// Track satisfaction rating submitted
  Future<void> trackSatisfactionRated({
    required String ticketId,
    required int rating,
    required bool hasComment,
  }) async {
    await _logEvent(
      SupportAnalyticsEvent.satisfactionRated,
      eventName: 'support_satisfaction_rated',
      parameters: {
        'ticket_id': ticketId,
        'rating': rating,
        'has_comment': hasComment ? 1 : 0,
      },
    );
  }

  /// Track attachment added to ticket or message
  Future<void> trackAttachmentAdded({
    required String ticketId,
    required String mimeType,
  }) async {
    await _logEvent(
      SupportAnalyticsEvent.attachmentAdded,
      eventName: 'support_attachment_added',
      parameters: {
        'ticket_id': ticketId,
        'mime_type': mimeType,
      },
    );
  }

  /// Track ticket list filtered
  Future<void> trackTicketFiltered({
    required TicketStatus? statusFilter,
  }) async {
    await _logEvent(
      SupportAnalyticsEvent.ticketFiltered,
      eventName: 'support_ticket_filtered',
      parameters: {
        'status_filter': statusFilter?.name ?? 'all',
      },
    );
  }

  /// Internal method to log events
  Future<void> _logEvent(
    SupportAnalyticsEvent event, {
    required String eventName,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters,
      );

      _log.debug(
        'Analytics: $eventName - ${parameters ?? {}}',
        tag: _tag,
      );
    } catch (e) {
      _log.error('Failed to log analytics event: $eventName - $e', tag: _tag);
    }
  }
}
