import 'package:flutter/material.dart';
import 'package:securityexperts_app/data/models/call_session.dart';
import 'package:securityexperts_app/features/calling/services/media/media_manager.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/room_service.dart';

/// Mock implementation of MediaManager for testing
///
/// Provides controllable behavior for testing media operations
/// without actual camera/microphone access.
class MockMediaManager implements MediaManager {
  // State notifiers
  @override
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  @override
  final ValueNotifier<bool> isMuted = ValueNotifier(false);

  @override
  final ValueNotifier<bool> isVideoEnabled = ValueNotifier(true);

  @override
  final ValueNotifier<bool> isRemoteVideoEnabled = ValueNotifier(true);

  @override
  final ValueNotifier<bool> isSpeakerOn = ValueNotifier(true);

  @override
  final ValueNotifier<String> selectedAudioOutput = ValueNotifier('speaker');

  @override
  ValueNotifier<bool>? get hasRemoteStream => ValueNotifier(false);

  @override
  ValueNotifier<bool>? get isRemoteAudioMuted => ValueNotifier(false);

  // LiveKit-specific streams (return null for mock - not testing LiveKit features)
  @override
  Stream<CallEndReason>? get callEndReasonStream => null;

  @override
  Stream<CallQualityStats>? get callQualityStream => null;

  @override
  CallQualityStats? get currentCallQuality => null;

  @override
  Stream<RemoteTrackStatus>? get remoteTrackStatusStream => null;

  // Configurable behaviors
  bool shouldFailInitialize = false;
  bool shouldFailConnect = false;
  bool shouldFailDisconnect = false;
  Duration? initializeDelay;
  Duration? connectDelay;

  // Tracking
  bool initializeCalled = false;
  bool connectCalled = false;
  bool disconnectCalled = false;
  int toggleMuteCount = 0;
  int toggleVideoCount = 0;
  int switchCameraCount = 0;
  int toggleSpeakerCount = 0;
  CallSession? lastConnectedSession;
  bool _disposed = false;

  @override
  Future<void> initialize() async {
    initializeCalled = true;

    if (initializeDelay != null) {
      await Future.delayed(initializeDelay!);
    }

    if (shouldFailInitialize) {
      throw Exception('Mock initialize failure');
    }
  }

  @override
  Future<void> connect(CallSession session) async {
    connectCalled = true;
    lastConnectedSession = session;

    if (connectDelay != null) {
      await Future.delayed(connectDelay!);
    }

    if (shouldFailConnect) {
      throw Exception('Mock connect failure');
    }

    isConnected.value = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;

    if (shouldFailDisconnect) {
      throw Exception('Mock disconnect failure');
    }

    isConnected.value = false;
  }

  @override
  Future<void> toggleMute() async {
    toggleMuteCount++;
    isMuted.value = !isMuted.value;
  }

  @override
  Future<void> toggleVideo() async {
    toggleVideoCount++;
    isVideoEnabled.value = !isVideoEnabled.value;
  }

  @override
  Future<void> switchCamera() async {
    switchCameraCount++;
  }

  @override
  Future<void> toggleSpeaker() async {
    toggleSpeakerCount++;
    isSpeakerOn.value = !isSpeakerOn.value;
  }

  @override
  Future<void> setAudioOutput(String output) async {
    selectedAudioOutput.value = output;
  }

  @override
  Widget buildLocalPreview({bool mirror = true, BoxFit fit = BoxFit.cover}) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Mock Local Preview',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  @override
  Widget buildRemoteVideo({
    bool mirror = false,
    BoxFit fit = BoxFit.cover,
    String? placeholderName,
  }) {
    return Container(
      color: Colors.grey,
      child: Center(
        child: Text(
          placeholderName ?? 'Mock Remote Video',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  /// Simulate disconnection
  void simulateDisconnect() {
    if (!_disposed) {
      isConnected.value = false;
    }
  }

  /// Simulate remote video disabled
  void simulateRemoteVideoDisabled() {
    if (!_disposed) {
      isRemoteVideoEnabled.value = false;
    }
  }

  /// Reset all state and counters
  void reset() {
    initializeCalled = false;
    connectCalled = false;
    disconnectCalled = false;
    toggleMuteCount = 0;
    toggleVideoCount = 0;
    switchCameraCount = 0;
    toggleSpeakerCount = 0;
    lastConnectedSession = null;
    shouldFailInitialize = false;
    shouldFailConnect = false;
    shouldFailDisconnect = false;
    initializeDelay = null;
    connectDelay = null;
    isConnected.value = false;
    isMuted.value = false;
    isVideoEnabled.value = true;
    isRemoteVideoEnabled.value = true;
    isSpeakerOn.value = true;
    selectedAudioOutput.value = 'speaker';
  }

  @override
  Future<void> dispose() async {
    if (!_disposed) {
      _disposed = true;
      isConnected.dispose();
      isMuted.dispose();
      isVideoEnabled.dispose();
      isRemoteVideoEnabled.dispose();
      isSpeakerOn.dispose();
      selectedAudioOutput.dispose();
    }
  }
}
