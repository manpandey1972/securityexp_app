import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/data/models/call_session.dart';
import 'package:greenhive_app/features/calling/services/interfaces/signaling_service.dart';

/// Mock implementation of SignalingService for testing
///
/// Provides controllable behavior for testing call flows without
/// actual Firebase backend interaction.
class MockSignalingService implements SignalingService {
  final StreamController<CallStatus> _callStateController =
      StreamController<CallStatus>.broadcast();

  bool _disposed = false;

  // Configurable behaviors
  bool shouldFailStartCall = false;
  bool shouldFailAcceptCall = false;
  bool shouldFailEndCall = false;
  Duration? startCallDelay;
  Duration? acceptCallDelay;
  CallSession? mockStartCallResponse;
  CallSession? mockAcceptCallResponse;

  // Tracking
  int startCallCount = 0;
  int acceptCallCount = 0;
  int endCallCount = 0;
  int rejectCallCount = 0;
  String? lastCalleeId;
  String? lastAcceptedCallId;
  String? lastEndedCallId;

  @override
  Stream<CallStatus> get callStateStream => _callStateController.stream;

  @override
  Future<CallSession> startCall({
    required String calleeId,
    required bool isVideo,
    String? callerName,
    String? calleeName,
  }) async {
    startCallCount++;
    lastCalleeId = calleeId;

    if (startCallDelay != null) {
      await Future.delayed(startCallDelay!);
    }

    if (shouldFailStartCall) {
      throw Exception('Mock startCall failure');
    }

    _callStateController.add(CallStatus.connecting);

    return mockStartCallResponse ??
        CallSession(
          callId: 'test-call-id',
          roomId: 'test-room-id',
          isCaller: true,
          calleeId: calleeId,
          callerId: 'test-caller-id',
          isVideo: isVideo,
        );
  }

  @override
  Future<CallSession> acceptCall(String callId, {required bool isVideo}) async {
    acceptCallCount++;
    lastAcceptedCallId = callId;

    if (acceptCallDelay != null) {
      await Future.delayed(acceptCallDelay!);
    }

    if (shouldFailAcceptCall) {
      throw Exception('Mock acceptCall failure');
    }

    _callStateController.add(CallStatus.connected);

    return mockAcceptCallResponse ??
        CallSession(
          callId: callId,
          roomId: callId,
          isCaller: false,
          calleeId: 'test-callee-id',
          callerId: 'test-caller-id',
          isVideo: isVideo,
        );
  }

  @override
  Future<void> endCall(String callId) async {
    endCallCount++;
    lastEndedCallId = callId;

    if (shouldFailEndCall) {
      throw Exception('Mock endCall failure');
    }

    _callStateController.add(CallStatus.ended);
  }

  @override
  Future<void> rejectCall(String callId) async {
    rejectCallCount++;
    _callStateController.add(CallStatus.rejected);
  }

  @override
  StreamSubscription<DocumentSnapshot>? listenToCallStatus(String callId) {
    // Return null for mock - real listener not needed in tests
    return null;
  }

  @override
  Stream<List<CallSession>> listenForIncomingCalls(String userId) {
    // Return empty stream for mock
    return Stream.value([]);
  }

  /// Simulate remote peer connecting
  void simulateRemoteConnect() {
    if (!_disposed) {
      _callStateController.add(CallStatus.connected);
    }
  }

  /// Simulate remote peer ending call
  void simulateRemoteEnd() {
    if (!_disposed) {
      _callStateController.add(CallStatus.ended);
    }
  }

  /// Simulate call rejection
  void simulateReject() {
    if (!_disposed) {
      _callStateController.add(CallStatus.rejected);
    }
  }

  /// Reset all counters and state
  void reset() {
    startCallCount = 0;
    acceptCallCount = 0;
    endCallCount = 0;
    rejectCallCount = 0;
    lastCalleeId = null;
    lastAcceptedCallId = null;
    lastEndedCallId = null;
    shouldFailStartCall = false;
    shouldFailAcceptCall = false;
    shouldFailEndCall = false;
    startCallDelay = null;
    acceptCallDelay = null;
    mockStartCallResponse = null;
    mockAcceptCallResponse = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _callStateController.close();
  }
}
