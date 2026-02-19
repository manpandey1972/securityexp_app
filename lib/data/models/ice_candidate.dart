import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// IceCandidate represents a WebRTC ICE candidate for connection.
class IceCandidate extends Equatable {
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  final String from; // 'caller' or 'callee'
  final Timestamp createdAt;

  const IceCandidate({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
    required this.from,
    required this.createdAt,
  });

  factory IceCandidate.fromJson(Map<String, dynamic> json) {
    return IceCandidate(
      candidate: json['candidate'] as String? ?? '',
      sdpMid: json['sdp_mid'] as String?,
      sdpMLineIndex: json['sdp_m_line_index'] as int?,
      from: json['from'] as String? ?? '',
      createdAt: (json['created_at'] as Timestamp?) ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'candidate': candidate,
      if (sdpMid != null) 'sdp_mid': sdpMid,
      if (sdpMLineIndex != null) 'sdp_m_line_index': sdpMLineIndex,
      'from': from,
      'created_at': createdAt,
    };
  }

  @override
  List<Object?> get props => [candidate, sdpMid, sdpMLineIndex, from, createdAt];
}
