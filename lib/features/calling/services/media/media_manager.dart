import 'package:flutter/material.dart';
import 'package:securityexperts_app/data/models/call_session.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/room_service.dart';

/// Abstract base class for Media Management (WebRTC vs LiveKit)
/// The UI interacts ONLY with this class, never with specific providers.
abstract class MediaManager {
  // Reactive State
  ValueNotifier<bool> get isConnected;
  ValueNotifier<bool> get isMuted;
  ValueNotifier<bool> get isVideoEnabled;
  ValueNotifier<bool> get isRemoteVideoEnabled;
  ValueNotifier<bool> get isSpeakerOn;
  ValueNotifier<String> get selectedAudioOutput; // 'speaker', 'earpiece', etc.

  // Optional: Track when remote stream is available (if supported by implementation)
  ValueNotifier<bool>? get hasRemoteStream => null;

  // Optional: Remote audio mute state (if supported by implementation)
  ValueNotifier<bool>? get isRemoteAudioMuted => null;

  // Optional: Stream-based events for LiveKit features
  /// Stream of call end reasons (why the call ended)
  Stream<CallEndReason>? get callEndReasonStream => null;

  /// Stream of call quality statistics
  Stream<CallQualityStats>? get callQualityStream => null;

  /// Stream of remote track mute status changes
  Stream<RemoteTrackStatus>? get remoteTrackStatusStream => null;

  /// Get current call quality snapshot
  CallQualityStats? get currentCallQuality => null;

  // Initialization & Connection
  Future<void> initialize();

  /// Connects to the media session using the provided metadata
  Future<void> connect(CallSession session);

  /// Disconnects and cleans up resources
  Future<void> disconnect();

  // Actions
  Future<void> toggleMute();
  Future<void> toggleVideo();
  Future<void> switchCamera();
  Future<void> toggleSpeaker();
  Future<void> setAudioOutput(String output);

  // Widget Builders
  /// Returns the widget for local camera preview
  Widget buildLocalPreview({bool mirror = true, BoxFit fit = BoxFit.cover});

  /// Returns the widget for remote video feed
  Widget buildRemoteVideo({
    bool mirror = false,
    BoxFit fit = BoxFit.cover,
    String? placeholderName,
  });

  /// Dispose internally created notifiers and resources
  /// Note: This is async to allow proper cleanup of underlying services
  @mustCallSuper
  Future<void> dispose() async {
    // Implementations should call super.dispose()
  }
}
