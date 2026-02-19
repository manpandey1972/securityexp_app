import 'dart:async';
import 'package:livekit_client/livekit_client.dart';

/// Reason for call ending
enum CallEndReason {
  /// Normal disconnect (user initiated)
  normal,

  /// Remote participant left
  remoteLeft,

  /// Timeout waiting for remote to join
  timeout,

  /// Connection error
  error,

  /// ICE/WebRTC connection failure (network issues, TURN failure, etc.)
  connectionFailure,
}

/// Call quality level
enum CallQualityLevel { excellent, good, fair, poor, unknown }

/// Call quality statistics
class CallQualityStats {
  /// Current connection quality level
  final CallQualityLevel quality;

  /// Round trip time in milliseconds
  final double? rttMs;

  /// Packet loss percentage (0-100)
  final double? packetLossPercent;

  /// Jitter in milliseconds
  final double? jitterMs;

  /// Bitrate for sending (kbps)
  final double? sendBitrateKbps;

  /// Bitrate for receiving (kbps)
  final double? recvBitrateKbps;

  /// Timestamp of this stats snapshot
  final DateTime timestamp;

  const CallQualityStats({
    this.quality = CallQualityLevel.unknown,
    this.rttMs,
    this.packetLossPercent,
    this.jitterMs,
    this.sendBitrateKbps,
    this.recvBitrateKbps,
    required this.timestamp,
  });

  @override
  String toString() =>
      'CallQualityStats(quality: $quality, rtt: ${rttMs?.toStringAsFixed(1)}ms, '
      'loss: ${packetLossPercent?.toStringAsFixed(1)}%, jitter: ${jitterMs?.toStringAsFixed(1)}ms, '
      'send: ${sendBitrateKbps?.toStringAsFixed(0)}kbps, recv: ${recvBitrateKbps?.toStringAsFixed(0)}kbps)';
}

/// Remote participant track mute status
class RemoteTrackStatus {
  /// Whether remote video is muted
  final bool videoMuted;

  /// Whether remote audio is muted
  final bool audioMuted;

  const RemoteTrackStatus({required this.videoMuted, required this.audioMuted});

  @override
  String toString() =>
      'RemoteTrackStatus(video: ${videoMuted ? 'muted' : 'on'}, audio: ${audioMuted ? 'muted' : 'on'})';
}

/// Abstract interface for room connection and participant management
///
/// This abstraction allows us to:
/// - Test components without actual LiveKit connections
/// - Potentially swap providers in the future
/// - Follow Dependency Inversion Principle
///
/// Uses only LiveKit SDK APIs - no direct WebRTC API usage
abstract class RoomService {
  /// Stream of remote participants
  Stream<List<RemoteParticipant>> get participantsStream;

  /// Stream of connection state changes
  Stream<bool> get connectionStateStream;

  /// Stream of local participant updates
  Stream<LocalParticipant?> get localStreamStream;

  /// Get the current room instance
  Room? get room;

  /// Get the local participant
  LocalParticipant? get localParticipant;

  /// Get list of remote participants
  List<RemoteParticipant> get remoteParticipants;

  /// Check if currently connected
  bool get isConnected;

  /// Connect to a room with the given credentials
  ///
  /// LiveKit SDK handles media acquisition internally, so no local stream
  /// parameter is needed. Camera and microphone are acquired by the SDK.
  ///
  /// [url] - WebSocket URL of the LiveKit server
  /// [token] - JWT token for authentication
  /// [enableVideo] - Whether to enable video on connection
  /// [enableAudio] - Whether to enable audio on connection
  Future<void> connect({
    required String url,
    required String token,
    required bool enableVideo,
    required bool enableAudio,
  });

  /// Disconnect from the current room
  Future<void> disconnect();

  /// Update remote participants list
  Future<void> updateRemoteParticipants();

  /// Toggle microphone on/off
  Future<void> setMicrophoneEnabled(bool enabled);

  /// Toggle camera on/off
  Future<void> setCameraEnabled(bool enabled);

  /// Check if microphone is enabled
  bool isMicrophoneEnabled();

  /// Check if camera is enabled
  bool isCameraEnabled();

  /// Check if remote participant's video is muted/unavailable
  bool get isRemoteVideoMuted;

  /// Check if remote participant's audio is muted/unavailable
  bool get isRemoteAudioMuted;

  /// Stream of call end reasons (emitted when call ends)
  Stream<CallEndReason> get callEndReasonStream;

  /// Stream of call quality statistics (emitted periodically)
  Stream<CallQualityStats> get callQualityStream;

  /// Stream of remote track mute status changes
  Stream<RemoteTrackStatus> get remoteTrackStatusStream;

  /// Get current call quality stats snapshot
  CallQualityStats? get currentCallQuality;

  /// Start monitoring call quality (call after connection established)
  /// [interval] - How often to emit stats (default 2 seconds)
  void startQualityMonitoring({Duration interval = const Duration(seconds: 2)});

  /// Stop monitoring call quality
  void stopQualityMonitoring();

  /// Get first remote participant (for one-to-one calls)
  RemoteParticipant? getRemoteParticipant();

  /// Start timeout timer for waiting for remote participant
  /// [duration] - How long to wait before timing out (default 60 seconds)
  void startRemoteJoinTimeout({
    Duration duration = const Duration(seconds: 60),
  });

  /// Cancel the remote join timeout (call when remote joins)
  void cancelRemoteJoinTimeout();

  /// Dispose resources
  Future<void> dispose();
}
