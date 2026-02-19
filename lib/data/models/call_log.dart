class CallLog {
  final String id;
  final String userId;
  final String otherUserId;
  final String otherUserName;
  final DateTime callTime;
  final int durationSeconds;
  final String callType; // 'audio' or 'video'
  final String status; // 'completed', 'missed', 'declined'
  final String direction; // 'incoming' or 'outgoing'

  CallLog({
    required this.id,
    required this.userId,
    required this.otherUserId,
    required this.otherUserName,
    required this.callTime,
    required this.durationSeconds,
    required this.callType,
    required this.status,
    required this.direction,
  });

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'callTime': callTime.millisecondsSinceEpoch,
      'durationSeconds': durationSeconds,
      'callType': callType,
      'status': status,
      'direction': direction,
    };
  }

  /// @Deprecated('Use toJson() instead')
  Map<String, dynamic> toMap() => toJson();

  /// Deserialize from JSON map.
  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      otherUserId: json['otherUserId'] ?? '',
      otherUserName: json['otherUserName'] ?? '',
      callTime: DateTime.fromMillisecondsSinceEpoch(json['callTime'] ?? 0),
      durationSeconds: json['durationSeconds'] ?? 0,
      callType: json['callType'] ?? 'audio',
      status: json['status'] ?? 'completed',
      direction: json['direction'] ?? 'outgoing',
    );
  }

  /// @Deprecated('Use fromJson() instead')
  factory CallLog.fromMap(Map<String, dynamic> map) = CallLog.fromJson;
}
