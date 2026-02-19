import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/data/models/call_session.dart';

/// Status of a call in the signaling layer
enum CallStatus { connecting, ringing, connected, ended, rejected, failed }

/// Abstract interface for call signaling services
///
/// This interface defines the contract for handling call signaling,
/// including starting/accepting/ending calls and listening to call state changes.
///
/// Implementations can use different backends (Cloud Functions, WebRTC signaling, etc.)
abstract class SignalingService {
  /// Stream of call state changes
  ///
  /// Emits [CallStatus] updates when the call state changes on the backend
  Stream<CallStatus> get callStateStream;

  /// Starts a new outgoing call
  ///
  /// Creates a call session and initiates signaling with the callee.
  ///
  /// Returns [CallSession] with room details and media provider information.
  /// Throws [Exception] if call creation fails.
  Future<CallSession> startCall({
    required String calleeId,
    required bool isVideo,
    String? callerName,
    String? calleeName,
  });

  /// Accepts an incoming call
  ///
  /// Joins an existing call session identified by [callId].
  /// [isVideo] indicates whether this is a video call.
  ///
  /// Returns [CallSession] with room details and media provider information.
  /// Throws [Exception] if accepting fails.
  Future<CallSession> acceptCall(String callId, {required bool isVideo});

  /// Ends an active call
  ///
  /// Terminates the call session and notifies other participants.
  ///
  /// This method should be idempotent - calling it multiple times
  /// should not cause errors.
  Future<void> endCall(String callId);

  /// Rejects an incoming call
  ///
  /// Declines the call without accepting it.
  Future<void> rejectCall(String callId);

  /// Listens to call status updates from the backend
  ///
  /// Returns a [StreamSubscription] that emits updates when call status
  /// changes in the database. Caller is responsible for cancelling
  /// the subscription when done.
  ///
  /// Updates are also pushed to [callStateStream].
  StreamSubscription<DocumentSnapshot>? listenToCallStatus(String callId);

  /// Listens for incoming calls for a specific user
  ///
  /// Returns a stream of incoming call sessions for the given [userId].
  /// This is typically used to show incoming call notifications.
  Stream<List<CallSession>> listenForIncomingCalls(String userId);

  /// Disposes of resources used by the signaling service
  ///
  /// Should be called when the service is no longer needed.
  /// Closes streams and cancels any active listeners.
  void dispose();
}
