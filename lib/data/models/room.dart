import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Room defines the structure for a chat room.
class Room extends Equatable {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final Timestamp? lastMessageTime;
  final Timestamp? createdAt;

  const Room({
    required this.id,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageTime,
    this.createdAt,
  });

  // Convenience getters for timestamp conversions
  DateTime? get lastMessageDateTime => lastMessageTime?.toDate();
  DateTime? get createdDateTime => createdAt?.toDate();

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String? ?? '',
      participants: List<String>.from(
        json['participants'] as List<dynamic>? ?? [],
      ),
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageTime: json['lastMessageTime'] as Timestamp?,
      createdAt: json['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      if (lastMessageTime != null) 'lastMessageTime': lastMessageTime,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  @override
  List<Object?> get props => [
    id,
    participants,
    lastMessage,
    lastMessageTime,
    createdAt,
  ];
}
