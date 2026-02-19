import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/data/models/call_session.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/features/calling/domain/repositories/call_repository.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/signaling_service.dart';
import 'package:securityexperts_app/core/config/call_config.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';

/// Firebase implementation of CallRepository
///
/// Uses Firebase Cloud Functions for call operations and
/// Firestore for real-time state synchronization.
class FirebaseCallRepository implements CallRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final UserCacheService _userCache;
  final AppLogger _log = sl<AppLogger>();
  final AnalyticsService _analytics = sl<AnalyticsService>();

  static const String _tag = 'FirebaseCallRepo';

  FirebaseCallRepository({
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required UserCacheService userCache,
    CallConfig? callConfig, // Kept for DI compatibility, no longer used
  }) : _functions = functions,
       _firestore = firestore,
       _auth = auth,
       _userCache = userCache;

  @override
  Future<CallSession> createCall(CreateCallRequest request) async {
    final trace = _analytics.newTrace('call_setup_outgoing');
    trace.putAttribute('is_video', request.isVideo.toString());
    await trace.start();

    try {
      // OPTIMIZATION: Fetch names from UserCacheService in PARALLEL
      // This saves 100-300ms when both names need to be fetched
      String? finalCallerName = request.callerName;
      String? finalCalleeName = request.calleeName;

      final callerId = _auth.currentUser?.uid;

      // Build list of futures for parallel execution
      final List<Future> fetchFutures = [];
      var callerIndex = -1;
      var calleeIndex = -1;

      if ((finalCallerName == null || finalCallerName.isEmpty) &&
          callerId != null) {
        callerIndex = fetchFutures.length;
        fetchFutures.add(_userCache.getOrFetch(callerId));
      }

      if (finalCalleeName == null || finalCalleeName.isEmpty) {
        calleeIndex = fetchFutures.length;
        fetchFutures.add(_userCache.getOrFetch(request.calleeId));
      }

      // Execute fetches in parallel
      if (fetchFutures.isNotEmpty) {
        final results = await Future.wait(fetchFutures);

        if (callerIndex >= 0) {
          finalCallerName = results[callerIndex]?.name ?? 'Unknown';
          _log.debug('Fetched caller name: $finalCallerName', tag: _tag);
        }
        if (calleeIndex >= 0) {
          finalCalleeName = results[calleeIndex]?.name ?? 'Unknown';
          _log.debug('Fetched callee name: $finalCalleeName', tag: _tag);
        }
      }

      _log.info(
        'Calling createCall Cloud Function',
        tag: _tag,
        data: {
          'callee_id': request.calleeId,
          'is_video': request.isVideo,
          'caller': finalCallerName,
          'callee': finalCalleeName,
        },
      );

      final result = await _functions.httpsCallable('api').call({
        'action': 'createCall',
        'payload': {
          'callee_id': request.calleeId,
          'is_video': request.isVideo,
          'caller_name': finalCallerName,
          'callee_name': finalCalleeName,
        },
      });

      _log.info('createCall response received', tag: _tag);
      final response = Map<String, dynamic>.from(result.data);
      _log.debug('Response success: ${response['success']}', tag: _tag);

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Unknown error');
      }

      final data = Map<String, dynamic>.from(response['data']);
      final roomId = data['room_id'];

      // Token is always returned from the unified api facade
      String? token;
      token = data['livekit_token'] as String?;
      if (token != null) {
        _log.info('Using token from createCall response', tag: _tag);
      } else {
        _log.warning('Token not in createCall response', tag: _tag);
      }

      return CallSession(
        callId: roomId,
        roomId: roomId,
        token: token,
        isCaller: true,
        calleeId: request.calleeId,
        callerId: _auth.currentUser?.uid ?? '',
        isVideo: request.isVideo,
      );
    } catch (e) {
      _log.error('createCall failed', tag: _tag, error: e);
      trace.putAttribute('error', e.runtimeType.toString());
      rethrow;
    } finally {
      try {
        await trace.stop();
      } catch (e) {
        // Ignore trace errors (can happen on web platform)
      }
    }
  }

  @override
  Future<CallSession> acceptCall(String callId, {required bool isVideo}) async {
    final trace = _analytics.newTrace('call_setup_incoming');
    trace.putAttribute('is_video', isVideo.toString());
    await trace.start();

    try {
      _log.info('Accepting call: $callId', tag: _tag);

      final result = await _functions.httpsCallable('api').call({
        'action': 'acceptCall',
        'payload': {'room_id': callId},
      });

      final response = Map<String, dynamic>.from(result.data);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Unknown error');
      }

      _log.debug('acceptCall - isVideo: $isVideo', tag: _tag);

      // Token is always returned from the unified api facade
      String? token;
      String? tokenFromResponse;
      if (response.containsKey('data') && response['data'] != null) {
        final data = Map<String, dynamic>.from(response['data']);
        tokenFromResponse = data['livekit_token'] as String?;
      }
      token = tokenFromResponse;
      if (token != null) {
        _log.info('Using token from acceptCall response', tag: _tag);
      } else {
        _log.warning('Token not in acceptCall response', tag: _tag);
      }

      return CallSession(
        callId: callId,
        roomId: callId,
        token: token,
        isCaller: false,
        calleeId: _auth.currentUser?.uid ?? '',
        callerId: '',
        isVideo: isVideo,
      );
    } catch (e) {
      _log.error('acceptCall failed', tag: _tag, error: e);
      trace.putAttribute('error', e.runtimeType.toString());
      rethrow;
    } finally {
      try {
        await trace.stop();
      } catch (e) {
        // Ignore trace errors (can happen on web platform)
      }
    }
  }

  @override
  Future<void> endCall(String callId) async {
    try {
      _log.info('Ending call: $callId', tag: _tag);
      await _functions.httpsCallable('api').call({
        'action': 'endCall',
        'payload': {'room_id': callId},
      });
      _log.info('endCall succeeded', tag: _tag);
    } catch (e) {
      // "not-found" error is expected if the call was already deleted
      // (e.g., by the other participant or a cleanup function)
      // This is not an error condition - just log as info
      if (e.toString().contains('not-found') ||
          e.toString().contains('Call does not exist')) {
        _log.info('endCall - call already deleted (idempotent)', tag: _tag);
        return; // Suppress error - this is normal
      }
      _log.error('endCall failed', tag: _tag, error: e);
      rethrow; // Rethrow only for actual errors
    }
  }

  @override
  Future<void> rejectCall(String callId) async {
    try {
      _log.info('Rejecting call: $callId', tag: _tag);
      await _functions.httpsCallable('api').call({
        'action': 'rejectCall',
        'payload': {'room_id': callId},
      });
      _log.info('rejectCall succeeded', tag: _tag);
    } catch (e) {
      _log.error('rejectCall failed', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<String?> generateToken(GenerateTokenRequest request) async {
    // Optimization 4: Standalone generateLiveKitTokenFunction removed.
    // Tokens are now always returned inline from createCall/acceptCall
    // via the unified api facade. This method exists only to satisfy
    // the CallRepository interface contract.
    _log.warning(
      'generateToken called — tokens should come from createCall/acceptCall response',
      tag: _tag,
    );
    return null;
  }

  @override
  StreamSubscription<DocumentSnapshot>? watchCallStatus(
    String callId,
    void Function(CallStatus status) onStatusChange,
  ) {
    _log.debug('Watching status for call: $callId', tag: _tag);

    return _firestore
        .collection('livekit_rooms')
        .doc(callId)
        .snapshots()
        .listen(
          (snapshot) {
            _log.verbose(
              'Status snapshot for: $callId, exists: ${snapshot.exists}',
              tag: _tag,
            );

            if (!snapshot.exists) {
              _log.debug('Document does not exist - emitting ended', tag: _tag);
              onStatusChange(CallStatus.ended);
              return;
            }

            final data = snapshot.data();
            if (data == null) {
              _log.verbose('Document data is null', tag: _tag);
              return;
            }

            final statusStr = data['status'] as String?;
            _log.verbose('Raw status from Firestore: $statusStr', tag: _tag);

            if (statusStr == null) {
              _log.verbose('Status field is null', tag: _tag);
              return;
            }

            final status = _parseCallStatus(statusStr);
            _log.debug('Parsed status: $status', tag: _tag);
            onStatusChange(status);
          },
          onError: (e) {
            _log.error('Status watch error', tag: _tag, error: e);
          },
        );
  }

  @override
  Stream<List<CallSession>> listenForIncomingCalls(String userId) {
    _log.debug('Listening for incoming calls: $userId', tag: _tag);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('incoming_calls')
        .snapshots()
        .map((snapshot) {
          _log.verbose(
            'Received ${snapshot.docs.length} incoming calls',
            tag: _tag,
          );

          final sessions = <CallSession>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              final session = CallSession(
                callId: doc.id,
                roomId: doc.id,
                isCaller: false,
                calleeId: userId,
                callerId: data['caller_id'] ?? '',
                isVideo: data['is_video'] ?? false,
              );
              sessions.add(session);
              _log.verbose('Incoming call: ${doc.id}', tag: _tag);
            } catch (e) {
              _log.warning('Error parsing call ${doc.id}: $e', tag: _tag);
            }
          }

          return sessions;
        });
  }

  /// Parse Firestore status string to CallStatus enum
  CallStatus _parseCallStatus(String statusStr) {
    switch (statusStr) {
      case 'active':
      case 'connected':
        return CallStatus.connected;
      case 'rejected':
      case 'cancelled':
      case 'missed':
        return CallStatus.rejected;
      case 'ended':
        return CallStatus.ended;
      case 'pending':
        return CallStatus.ringing;
      default:
        return CallStatus.ringing;
    }
  }
}
