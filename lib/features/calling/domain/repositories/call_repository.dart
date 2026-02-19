import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/data/models/call_session.dart';
import 'package:greenhive_app/features/calling/services/interfaces/signaling_service.dart';

/// Request object for creating a new call
class CreateCallRequest {
  final String calleeId;
  final bool isVideo;
  final String? callerName;
  final String? calleeName;

  CreateCallRequest({
    required this.calleeId,
    required this.isVideo,
    this.callerName,
    this.calleeName,
  });
}

/// Request object for generating authentication tokens
class GenerateTokenRequest {
  final String userId;
  final String roomId;
  final String userName;
  final bool canPublish;
  final bool canSubscribe;

  GenerateTokenRequest({
    required this.userId,
    required this.roomId,
    required this.userName,
    this.canPublish = true,
    this.canSubscribe = true,
  });
}

/// Repository interface for call-related data operations
///
/// This abstraction separates business logic from data access,
/// making the code more testable and maintainable.
///
/// Implementations can use:
/// - Firebase Cloud Functions + Firestore
/// - REST API + WebSocket
/// - Any other backend
abstract class CallRepository {
  /// Creates a new call and returns the session information
  ///
  /// This initiates the call signaling process with the backend.
  Future<CallSession> createCall(CreateCallRequest request);

  /// Accepts an incoming call
  ///
  /// Updates the call status and returns session information for the callee.
  /// [isVideo] indicates whether this is a video call.
  Future<CallSession> acceptCall(String callId, {required bool isVideo});

  /// Ends an active call
  ///
  /// Notifies all participants that the call has ended.
  Future<void> endCall(String callId);

  /// Rejects an incoming call
  ///
  /// Notifies the caller that the call was rejected.
  Future<void> rejectCall(String callId);

  /// Generates an authentication token for media connection
  ///
  /// Required for LiveKit or other token-based media services.
  Future<String?> generateToken(GenerateTokenRequest request);

  /// Watch real-time call status changes
  ///
  /// Returns a stream that emits CallStatus updates as the call progresses.
  StreamSubscription<DocumentSnapshot>? watchCallStatus(
    String callId,
    void Function(CallStatus status) onStatusChange,
  );

  /// Listen for incoming calls for a specific user
  ///
  /// Returns a stream of call sessions for incoming calls.
  Stream<List<CallSession>> listenForIncomingCalls(String userId);
}
