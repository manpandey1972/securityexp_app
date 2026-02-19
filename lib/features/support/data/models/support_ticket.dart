import 'package:cloud_firestore/cloud_firestore.dart';

import 'device_context.dart';
import 'support_enums.dart';
import 'ticket_attachment.dart';

/// Represents a customer support ticket.
///
/// A support ticket is created when a user submits a bug report,
/// feature request, feedback, or support request.
class SupportTicket {
  // ============= Identifiers =============

  /// Unique identifier for the ticket
  final String id;

  /// Human-readable ticket number (e.g., "GH-2026-00042")
  final String ticketNumber;

  // ============= User Info =============

  /// Firebase Auth UID of the user (nullable for anonymous)
  final String? userId;

  /// User's email for contact
  final String userEmail;

  /// User's display name
  final String? userName;

  // ============= Content =============

  /// Type of the ticket (bug, feature_request, etc.)
  final TicketType type;

  /// Category for organizing tickets
  final TicketCategory category;

  /// Brief summary of the issue
  final String subject;

  /// Detailed description
  final String description;

  /// Attached files (screenshots, etc.)
  final List<TicketAttachment> attachments;

  // ============= Context =============

  /// Device and app information
  final DeviceContext deviceContext;

  // ============= Status =============

  /// Current status of the ticket
  final TicketStatus status;

  /// Priority level
  final TicketPriority priority;

  /// ID of the assigned support agent (nullable)
  final String? assignedTo;

  /// Tags for filtering/searching
  final List<String> tags;

  // ============= Timestamps =============

  /// When the ticket was created
  final DateTime createdAt;

  /// When the ticket was last updated
  final DateTime updatedAt;

  /// When the ticket was resolved (nullable)
  final DateTime? resolvedAt;

  /// When the ticket was closed (nullable)
  final DateTime? closedAt;

  /// Last activity (message or status change)
  final DateTime lastActivityAt;

  // ============= Metadata =============

  /// Number of messages in the conversation
  final int messageCount;

  /// Whether there are unread messages from support
  final bool hasUnreadSupportMessages;

  /// Whether the ticket was auto-created (e.g., from crash report)
  final bool isAutoCreated;

  // ============= Resolution =============

  /// Resolution summary when closed
  final String? resolution;

  /// Type of resolution
  final ResolutionType? resolutionType;

  /// User's satisfaction rating (1-5)
  final int? userSatisfactionRating;

  /// User's feedback on support experience
  final String? userSatisfactionComment;

  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    this.userId,
    required this.userEmail,
    this.userName,
    required this.type,
    required this.category,
    required this.subject,
    required this.description,
    this.attachments = const [],
    required this.deviceContext,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedAt,
    required this.lastActivityAt,
    this.messageCount = 0,
    this.hasUnreadSupportMessages = false,
    this.isAutoCreated = false,
    this.resolution,
    this.resolutionType,
    this.userSatisfactionRating,
    this.userSatisfactionComment,
  });

  // ============= Computed Properties =============

  /// Whether the ticket is still open (not resolved or closed)
  bool get isOpen =>
      status == TicketStatus.open ||
      status == TicketStatus.inReview ||
      status == TicketStatus.inProgress;

  /// Whether the user can reply to this ticket
  bool get canReply => status != TicketStatus.closed;

  /// Whether the user can rate this ticket
  bool get canRate =>
      (status == TicketStatus.resolved || status == TicketStatus.closed) &&
      userSatisfactionRating == null;

  /// Get the time since last activity
  Duration get timeSinceLastActivity =>
      DateTime.now().difference(lastActivityAt);

  /// Get the age of the ticket
  Duration get age => DateTime.now().difference(createdAt);

  // ============= Factory Methods =============

  /// Create from a Firestore document
  factory SupportTicket.fromJson(Map<String, dynamic> json, {String? docId}) {
    return SupportTicket(
      id: docId ?? json['id'] as String? ?? '',
      ticketNumber: json['ticketNumber'] as String? ?? '',
      userId: json['userId'] as String?,
      userEmail: json['userEmail'] as String? ?? '',
      userName: json['userName'] as String?,
      type: TicketType.fromJson(json['type'] as String? ?? 'support'),
      category: TicketCategory.fromJson(json['category'] as String? ?? 'other'),
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      attachments: _parseAttachments(json['attachments']),
      deviceContext: json['deviceContext'] != null
          ? DeviceContext.fromJson(
              json['deviceContext'] as Map<String, dynamic>,
            )
          : DeviceContext(
              platform: 'Unknown',
              osVersion: 'Unknown',
              appVersion: 'Unknown',
              buildNumber: '0',
              locale: 'en_US',
              timezone: 'UTC',
            ),
      status: TicketStatus.fromJson(json['status'] as String? ?? 'open'),
      priority: TicketPriority.fromJson(
        json['priority'] as String? ?? 'medium',
      ),
      assignedTo: json['assignedTo'] as String?,
      tags: _parseStringList(json['tags']),
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      resolvedAt: _parseNullableTimestamp(json['resolvedAt']),
      closedAt: _parseNullableTimestamp(json['closedAt']),
      lastActivityAt: _parseTimestamp(json['lastActivityAt']),
      messageCount: json['messageCount'] as int? ?? 0,
      hasUnreadSupportMessages:
          json['hasUnreadSupportMessages'] as bool? ?? false,
      isAutoCreated: json['isAutoCreated'] as bool? ?? false,
      resolution: json['resolution'] as String?,
      resolutionType: ResolutionType.fromJson(
        json['resolutionType'] as String?,
      ),
      userSatisfactionRating: json['userSatisfactionRating'] as int?,
      userSatisfactionComment: json['userSatisfactionComment'] as String?,
    );
  }

  /// Convert to a Firestore-compatible map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticketNumber': ticketNumber,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'type': type.toJson(),
      'category': category.toJson(),
      'subject': subject,
      'description': description,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'deviceContext': deviceContext.toJson(),
      'status': status.toJson(),
      'priority': priority.toJson(),
      'assignedTo': assignedTo,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      'messageCount': messageCount,
      'hasUnreadSupportMessages': hasUnreadSupportMessages,
      'isAutoCreated': isAutoCreated,
      'resolution': resolution,
      'resolutionType': resolutionType?.toJson(),
      'userSatisfactionRating': userSatisfactionRating,
      'userSatisfactionComment': userSatisfactionComment,
    };
  }

  /// Create a copy with some fields replaced
  SupportTicket copyWith({
    String? id,
    String? ticketNumber,
    String? userId,
    String? userEmail,
    String? userName,
    TicketType? type,
    TicketCategory? category,
    String? subject,
    String? description,
    List<TicketAttachment>? attachments,
    DeviceContext? deviceContext,
    TicketStatus? status,
    TicketPriority? priority,
    String? assignedTo,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    DateTime? lastActivityAt,
    int? messageCount,
    bool? hasUnreadSupportMessages,
    bool? isAutoCreated,
    String? resolution,
    ResolutionType? resolutionType,
    int? userSatisfactionRating,
    String? userSatisfactionComment,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      type: type ?? this.type,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      attachments: attachments ?? this.attachments,
      deviceContext: deviceContext ?? this.deviceContext,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      closedAt: closedAt ?? this.closedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      messageCount: messageCount ?? this.messageCount,
      hasUnreadSupportMessages:
          hasUnreadSupportMessages ?? this.hasUnreadSupportMessages,
      isAutoCreated: isAutoCreated ?? this.isAutoCreated,
      resolution: resolution ?? this.resolution,
      resolutionType: resolutionType ?? this.resolutionType,
      userSatisfactionRating:
          userSatisfactionRating ?? this.userSatisfactionRating,
      userSatisfactionComment:
          userSatisfactionComment ?? this.userSatisfactionComment,
    );
  }

  // ============= Helper Methods =============

  static List<TicketAttachment> _parseAttachments(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => TicketAttachment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  static DateTime? _parseNullableTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  @override
  String toString() {
    return 'SupportTicket(id: $id, ticketNumber: $ticketNumber, '
        'type: ${type.name}, status: ${status.name}, subject: $subject)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupportTicket && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
