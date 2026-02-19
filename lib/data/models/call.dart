import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Call represents a call between two users.
class Call extends Equatable {
  final String id;
  final String callerId;
  final String calleeId;
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;
  final bool isVideo;
  final String status; // 'pending', 'answered', 'rejected', 'ended'
  final Timestamp createdAt;
  final Timestamp? answeredAt;
  final Timestamp? endedAt;

  const Call({
    required this.id,
    required this.callerId,
    required this.calleeId,
    this.offer,
    this.answer,
    this.isVideo = true,
    this.status = 'pending',
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'] as String? ?? '',
      callerId: json['caller_id'] as String? ?? '',
      calleeId: json['callee_id'] as String? ?? '',
      offer: json['offer'] as Map<String, dynamic>?,
      answer: json['answer'] as Map<String, dynamic>?,
      isVideo:
          json['is_video'] as bool? ??
          false, // Default to audio-only for safety
      status: json['status'] as String? ?? 'pending',
      createdAt: (json['created_at'] as Timestamp?) ?? Timestamp.now(),
      answeredAt: json['answered_at'] as Timestamp?,
      endedAt: json['ended_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'caller_id': callerId,
      'callee_id': calleeId,
      if (offer != null) 'offer': offer,
      if (answer != null) 'answer': answer,
      'is_video': isVideo,
      'status': status,
      'created_at': createdAt,
      if (answeredAt != null) 'answered_at': answeredAt,
      if (endedAt != null) 'ended_at': endedAt,
    };
  }

  @override
  List<Object?> get props => [
    id,
    callerId,
    calleeId,
    offer,
    answer,
    isVideo,
    status,
    createdAt,
    answeredAt,
    endedAt,
  ];
}
