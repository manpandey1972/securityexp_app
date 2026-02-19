class CallSession {
  final String callId; // specific to the call instance
  final String roomId; // often same as callId or roomId
  final String? token; // For LiveKit
  final bool isCaller;
  final String calleeId;
  final String callerId;
  final bool isVideo;

  CallSession({
    required this.callId,
    required this.roomId,
    required this.isCaller,
    required this.calleeId,
    required this.callerId,
    required this.isVideo,
    this.token,
  });

  /// Deserialize from JSON map.
  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      callId: json['callId'] ?? '',
      roomId: json['roomId'] ?? '',
      token: json['token'],
      isCaller: json['isCaller'] ?? false,
      calleeId: json['calleeId'] ?? '',
      callerId: json['callerId'] ?? '',
      isVideo: json['isVideo'] ?? false,
    );
  }

  /// @Deprecated('Use fromJson() instead')
  factory CallSession.fromMap(Map<String, dynamic> data) = CallSession.fromJson;

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'roomId': roomId,
      if (token != null) 'token': token,
      'isCaller': isCaller,
      'calleeId': calleeId,
      'callerId': callerId,
      'isVideo': isVideo,
    };
  }
}
