import 'package:cloud_firestore/cloud_firestore.dart';

import 'support_enums.dart';
import 'ticket_attachment.dart';

/// Represents a message in a support ticket conversation.
///
/// Messages can be from the user, support team, or system-generated.
class SupportMessage {
  /// Unique identifier for the message
  final String id;

  /// ID of the ticket this message belongs to
  final String ticketId;

  // ============= Sender Info =============

  /// ID of the sender (user ID, support agent ID, or 'system')
  final String senderId;

  /// Type of sender
  final MessageSenderType senderType;

  /// Display name of the sender
  final String senderName;

  // ============= Content =============

  /// Message text content
  final String content;

  /// Attached files
  final List<TicketAttachment> attachments;

  // ============= Metadata =============

  /// When the message was created
  final DateTime createdAt;

  /// When the message was read by the recipient
  final DateTime? readAt;

  /// Whether this is an internal note (visible only to support)
  final bool isInternal;

  // ============= System Message Fields =============

  /// Type of system message (if applicable)
  final SystemMessageType? systemMessageType;

  /// Additional data for system messages
  final Map<String, dynamic>? systemMessageData;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.content,
    this.attachments = const [],
    required this.createdAt,
    this.readAt,
    this.isInternal = false,
    this.systemMessageType,
    this.systemMessageData,
  });

  // ============= Computed Properties =============

  /// Whether this is a system-generated message
  bool get isSystemMessage => senderType == MessageSenderType.system;

  /// Whether this message is from the support team
  bool get isFromSupport => senderType == MessageSenderType.support;

  /// Whether this message is from the user
  bool get isFromUser => senderType == MessageSenderType.user;

  /// Whether this message has been read
  bool get isRead => readAt != null;

  /// Whether this message has attachments
  bool get hasAttachments => attachments.isNotEmpty;

  /// Get the time since this message was sent
  Duration get timeSinceSent => DateTime.now().difference(createdAt);

  // ============= Factory Methods =============

  /// Create from a Firestore document
  factory SupportMessage.fromJson(Map<String, dynamic> json, {String? docId}) {
    return SupportMessage(
      id: docId ?? json['id'] as String? ?? '',
      ticketId: json['ticketId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderType: MessageSenderType.fromJson(
        json['senderType'] as String? ?? 'user',
      ),
      senderName: json['senderName'] as String? ?? 'Unknown',
      content: json['content'] as String? ?? '',
      attachments: _parseAttachments(json['attachments']),
      createdAt: _parseTimestamp(json['createdAt']),
      readAt: _parseNullableTimestamp(json['readAt']),
      isInternal: json['isInternal'] as bool? ?? false,
      systemMessageType: SystemMessageType.fromJson(
        json['systemMessageType'] as String?,
      ),
      systemMessageData: json['systemMessageData'] as Map<String, dynamic>?,
    );
  }

  /// Convert to a Firestore-compatible map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticketId': ticketId,
      'senderId': senderId,
      'senderType': senderType.toJson(),
      'senderName': senderName,
      'content': content,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'isInternal': isInternal,
      'systemMessageType': systemMessageType?.toJson(),
      'systemMessageData': systemMessageData,
    };
  }

  /// Create a copy with some fields replaced
  SupportMessage copyWith({
    String? id,
    String? ticketId,
    String? senderId,
    MessageSenderType? senderType,
    String? senderName,
    String? content,
    List<TicketAttachment>? attachments,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isInternal,
    SystemMessageType? systemMessageType,
    Map<String, dynamic>? systemMessageData,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isInternal: isInternal ?? this.isInternal,
      systemMessageType: systemMessageType ?? this.systemMessageType,
      systemMessageData: systemMessageData ?? this.systemMessageData,
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
    return 'SupportMessage(id: $id, ticketId: $ticketId, '
        'senderType: ${senderType.name}, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupportMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
