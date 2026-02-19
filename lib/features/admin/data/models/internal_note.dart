import 'package:cloud_firestore/cloud_firestore.dart';

/// Internal note model for admin-only ticket notes.
///
/// Internal notes are private notes added by support/admin staff
/// that are not visible to regular users.
class InternalNote {
  final String id;
  final String ticketId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  const InternalNote({
    required this.id,
    required this.ticketId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory InternalNote.fromJson(Map<String, dynamic> json, {String? docId}) {
    return InternalNote(
      id: docId ?? json['id'] as String? ?? '',
      ticketId: json['ticketId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticketId': ticketId,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  InternalNote copyWith({
    String? id,
    String? ticketId,
    String? authorId,
    String? authorName,
    String? content,
    DateTime? createdAt,
  }) {
    return InternalNote(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
