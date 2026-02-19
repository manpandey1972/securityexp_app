import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/data/models/call_session.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/signaling_service.dart';
import 'package:securityexperts_app/features/calling/domain/repositories/call_repository.dart';

/// Unified signaling service implementation using CallRepository
///
/// This is now a thin adapter that delegates to the repository layer,
/// following the Repository Pattern for better separation of concerns.
class UnifiedSignalingService implements SignalingService {
  final CallRepository _repository;

  // Stream controller for call state changes
  final StreamController<CallStatus> _callStateController =
      StreamController<CallStatus>.broadcast();

  bool _isDisposed = false;

  UnifiedSignalingService({required CallRepository repository})
    : _repository = repository;

  @override
  Stream<CallStatus> get callStateStream => _callStateController.stream;

  void _addCallStatus(CallStatus status) {
    if (!_isDisposed && !_callStateController.isClosed) {
      _callStateController.add(status);
    }
  }

  /// Starts a call by invoking the repository
  @override
  Future<CallSession> startCall({
    required String calleeId,
    required bool isVideo,
    String? callerName,
    String? calleeName,
  }) async {
    try {
      _addCallStatus(CallStatus.connecting);

      sl<AppLogger>().debug('Creating call via repository...', tag: 'UnifiedSignaling');

      final session = await _repository.createCall(
        CreateCallRequest(
          calleeId: calleeId,
          isVideo: isVideo,
          callerName: callerName,
          calleeName: calleeName,
        ),
      );

      sl<AppLogger>().debug('Call created: ${session.callId}', tag: 'UnifiedSignaling');
      return session;
    } catch (e) {
      _addCallStatus(CallStatus.failed);
      sl<AppLogger>().error('startCall failed', tag: 'UnifiedSignaling', error: e);
      rethrow;
    }
  }

  /// Accepts an incoming call via repository
  @override
  Future<CallSession> acceptCall(String callId, {required bool isVideo}) async {
    try {
      sl<AppLogger>().debug('Accepting call via repository...', tag: 'UnifiedSignaling');
      final session = await _repository.acceptCall(callId, isVideo: isVideo);
      sl<AppLogger>().debug('Call accepted: $callId', tag: 'UnifiedSignaling');
      return session;
    } catch (e) {
      sl<AppLogger>().error('acceptCall failed', tag: 'UnifiedSignaling', error: e);
      rethrow;
    }
  }

  /// Ends a call via repository
  @override
  Future<void> endCall(String callId) async {
    try {
      sl<AppLogger>().debug('Ending call via repository...', tag: 'UnifiedSignaling');
      await _repository.endCall(callId);
      sl<AppLogger>().debug('Call ended: $callId', tag: 'UnifiedSignaling');
      _addCallStatus(CallStatus.ended);
    } catch (e) {
      sl<AppLogger>().error('endCall failed', tag: 'UnifiedSignaling', error: e);
      // Even if it fails, emit ended status for local UI update
      _addCallStatus(CallStatus.ended);
    }
  }

  /// Rejects an incoming call via repository
  @override
  Future<void> rejectCall(String callId) async {
    try {
      sl<AppLogger>().debug('Rejecting call via repository...', tag: 'UnifiedSignaling');
      await _repository.rejectCall(callId);
      _addCallStatus(CallStatus.rejected);
      sl<AppLogger>().debug('Call rejected: $callId', tag: 'UnifiedSignaling');
    } catch (e) {
      sl<AppLogger>().error('rejectCall failed', tag: 'UnifiedSignaling', error: e);
    }
  }

  /// Listen to call status updates via repository
  @override
  StreamSubscription<DocumentSnapshot>? listenToCallStatus(String callId) {
    sl<AppLogger>().debug('Setting up status listener...', tag: 'UnifiedSignaling');
    return _repository.watchCallStatus(callId, (CallStatus status) {
      if (!_isDisposed) {
        _addCallStatus(status);
      }
    });
  }

  /// Listen for incoming calls via repository
  @override
  Stream<List<CallSession>> listenForIncomingCalls(String userId) {
    sl<AppLogger>().debug('Setting up incoming call listener...', tag: 'UnifiedSignaling');
    return _repository.listenForIncomingCalls(userId);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _callStateController.close();
  }
}
