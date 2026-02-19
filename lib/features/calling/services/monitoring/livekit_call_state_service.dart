import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';

/// Dedicated service for LiveKit call state management via Cloud Functions.
///
/// This service is completely separate from WebRTC signaling and only handles:
/// - Listening to call state changes from Cloud Functions
/// - Emitting real-time call events to UI subscribers
/// - No WebRTC or media handling (that's in FirestoreSignalingService)
///
/// State changes tracked:
/// - pending: Call created, waiting for callee to accept
/// - active: Call accepted by callee
/// - rejected: Call rejected by callee
/// - missed: Call timed out (no response from callee)
/// - cancelled: Call cancelled by caller before answer
/// - ended: Call ended normally
class LiveKitCallStateService {
  // Firestore instance
  final FirebaseFirestore _firestore = FirestoreInstance().db;

  static const String _liveKitRoomsCollection = 'livekit_rooms';
  static const String _usersCollection = 'users';
  static const String _incomingCallsSubcollection = 'incoming_calls';

  String? _currentUserId;

  // Stream controllers for call state events - recreated on each connect()
  late StreamController<Map<String, dynamic>> incomingCallController;
  late StreamController<Map<String, dynamic>> callStatusChangeController;
  late StreamController<Map<String, dynamic>> callAcceptedController;
  late StreamController<Map<String, dynamic>> callRejectedController;
  late StreamController<Map<String, dynamic>> callMissedController;
  late StreamController<Map<String, dynamic>> callEndedController;

  // Stream subscriptions
  StreamSubscription? _incomingCallsSubscription;
  StreamSubscription? _callStatusSubscription;

  // Track processed calls to avoid duplicates
  Set<String>? _processedIncomingCalls;
  Map<String, DateTime>? _lastIncomingCallTime;
  static const Duration _incomingCallDebounce = Duration(milliseconds: 500);

  // Track last emitted status to avoid re-emitting same status
  Map<String, String>? _lastEmittedStatus; // roomId → last status

  bool _isDisposed = false;

  /// Initialize service
  LiveKitCallStateService() {
    _processedIncomingCalls = {};
    _lastIncomingCallTime = {};
    _lastEmittedStatus = {};
    _initControllers();
    sl<AppLogger>().debug('Initialized', tag: 'LiveKitCallState');
  }

  /// Initialize or recreate stream controllers
  void _initControllers() {
    incomingCallController = StreamController<Map<String, dynamic>>.broadcast();
    callStatusChangeController =
        StreamController<Map<String, dynamic>>.broadcast();
    callAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
    callRejectedController = StreamController<Map<String, dynamic>>.broadcast();
    callMissedController = StreamController<Map<String, dynamic>>.broadcast();
    callEndedController = StreamController<Map<String, dynamic>>.broadcast();
  }

  // Stream getters for subscribers
  Stream<Map<String, dynamic>> get incomingCallStream =>
      incomingCallController.stream;
  Stream<Map<String, dynamic>> get callStatusChangeStream =>
      callStatusChangeController.stream;
  Stream<Map<String, dynamic>> get callAcceptedStream =>
      callAcceptedController.stream;
  Stream<Map<String, dynamic>> get callRejectedStream =>
      callRejectedController.stream;
  Stream<Map<String, dynamic>> get callMissedStream =>
      callMissedController.stream;
  Stream<Map<String, dynamic>> get callEndedStream =>
      callEndedController.stream;

  /// Initialize with current user ID and start listening
  Future<void> connect(String userId) async {
    _currentUserId = userId;
    _isDisposed = false;

    // Clear tracking for fresh session (important for multi-device & reconnect)
    _processedIncomingCalls?.clear();
    _lastIncomingCallTime?.clear();
    _lastEmittedStatus?.clear();

    // Recreate controllers if they were closed (reconnect scenario)
    if (incomingCallController.isClosed) {
      _initControllers();
    }

    sl<AppLogger>().debug('CONNECTING for user: $userId', tag: 'LiveKitCallState');
    sl<AppLogger>().debug(
      '_firestore instance: $_firestore',
      tag: 'LiveKitCallState',
    );
    sl<AppLogger>().debug(
      '_usersCollection: $_usersCollection',
      tag: 'LiveKitCallState',
    );
    sl<AppLogger>().debug(
      '_incomingCallsSubcollection: $_incomingCallsSubcollection',
      tag: 'LiveKitCallState',
    );

    sl<AppLogger>().debug(
      'Calling _listenToIncomingCalls()...',
      tag: 'LiveKitCallState',
    );
    _listenToIncomingCalls();
    sl<AppLogger>().debug(
      'Incoming calls listener started',
      tag: 'LiveKitCallState',
    );

    sl<AppLogger>().debug(
      'Calling _listenToCallStatusChanges()...',
      tag: 'LiveKitCallState',
    );
    _listenToCallStatusChanges();
    sl<AppLogger>().debug('Call status listener started', tag: 'LiveKitCallState');

    sl<AppLogger>().debug(
      'LISTENER REGISTRATION COMPLETE - Both listeners active',
      tag: 'LiveKitCallState',
    );
  }

  /// Listen to incoming calls for current user
  /// Monitors users/{userId}/incoming_calls collection
  void _listenToIncomingCalls() {
    if (_currentUserId == null) {
      sl<AppLogger>().error(
        'Cannot listen: _currentUserId is null',
        tag: 'LiveKitCallState',
      );
      return;
    }

    final collectionPath = 'users/$_currentUserId/incoming_calls';
    sl<AppLogger>().debug('INCOMING CALLS LISTENER SETUP', tag: 'LiveKitCallState');
    sl<AppLogger>().debug(
      'Collection path: $collectionPath',
      tag: 'LiveKitCallState',
    );
    sl<AppLogger>().debug('Building Firestore query...', tag: 'LiveKitCallState');

    final query = _firestore
        .collection(_usersCollection)
        .doc(_currentUserId)
        .collection(_incomingCallsSubcollection);

    sl<AppLogger>().debug(
      'Query built, attaching snapshots() listener...',
      tag: 'LiveKitCallState',
    );

    _incomingCallsSubscription = query.snapshots().listen(
      (snapshot) {
        if (_isDisposed) {
          sl<AppLogger>().warning(
            'Snapshot arrived but _isDisposed=true, ignoring',
            tag: 'LiveKitCallState',
          );
          return;
        }

        sl<AppLogger>().debug(
          'SNAPSHOT RECEIVED: ${snapshot.docs.length} documents in $collectionPath',
          tag: 'LiveKitCallState',
        );

        if (snapshot.docs.isEmpty) {
          sl<AppLogger>().debug(
            'Empty snapshot - no incoming calls',
            tag: 'LiveKitCallState',
          );
          return;
        }

        for (final doc in snapshot.docs) {
          final roomId = doc.id;
          final data = doc.data();
          final status = data['status'] as String?;
          final callerId = data['caller_id'] as String? ?? '';
          final callerName = data['caller_name'] as String? ?? 'Unknown';
          final isVideo =
              data['is_video'] as bool? ??
              false; // Default to audio-only for safety
          final createdAt = data['created_at'];

          sl<AppLogger>().debug('DOCUMENT FOUND: $roomId', tag: 'LiveKitCallState');
          sl<AppLogger>().debug(
            '  - Caller: $callerName ($callerId)',
            tag: 'LiveKitCallState',
          );
          sl<AppLogger>().debug('  - Status: $status', tag: 'LiveKitCallState');
          sl<AppLogger>().debug('  - Video: $isVideo', tag: 'LiveKitCallState');
          sl<AppLogger>().debug('  - Created: $createdAt', tag: 'LiveKitCallState');

          // Only emit for pending calls - ignore rejected/ended/missed/cancelled
          if (status != 'pending') {
            sl<AppLogger>().debug(
              'SKIPPED: Incoming call status is $status (not pending)',
              tag: 'LiveKitCallState',
            );
            continue;
          }

          // Skip if already processed (debounce)
          final isProcessed =
              _processedIncomingCalls?.contains(roomId) ?? false;
          if (isProcessed) {
            sl<AppLogger>().debug(
              'SKIPPED: Already processed $roomId',
              tag: 'LiveKitCallState',
            );
            continue;
          }

          // Debounce: skip if emitted recently
          final lastTime = _lastIncomingCallTime?[roomId];
          if (lastTime != null &&
              DateTime.now().difference(lastTime) < _incomingCallDebounce) {
            final timeSince = DateTime.now()
                .difference(lastTime)
                .inMilliseconds;
            sl<AppLogger>().debug(
              'DEBOUNCED: Emitted ${timeSince}ms ago, skipping',
              tag: 'LiveKitCallState',
            );
            continue;
          }

          // Mark as processed
          _processedIncomingCalls?.add(roomId);
          _lastIncomingCallTime?[roomId] = DateTime.now();

          sl<AppLogger>().debug(
            'EMITTING: incomingCallStream event for $roomId',
            tag: 'LiveKitCallState',
          );

          // Emit event
          _safeEmit(incomingCallController, {
            'room_id': roomId,
            'caller_id': callerId,
            'caller_name': callerName,
            'is_video': isVideo,
            'status': status,
            ...data,
          });

          sl<AppLogger>().debug(
            'EMITTED: Incoming call for $roomId',
            tag: 'LiveKitCallState',
          );
        }
      },
      onError: (e, stacktrace) {
        sl<AppLogger>().error('LISTENER ERROR: $e', tag: 'LiveKitCallState', error: e);
        sl<AppLogger>().error('Stacktrace: $stacktrace', tag: 'LiveKitCallState');
        sl<AppLogger>().error('This could indicate:', tag: 'LiveKitCallState');
        sl<AppLogger>().error('   - Firestore security rules DENYING access', tag: 'LiveKitCallState');
        sl<AppLogger>().error('   - Authentication token expired', tag: 'LiveKitCallState');
        sl<AppLogger>().error('   - Network connectivity issue', tag: 'LiveKitCallState');
        sl<AppLogger>().error('   - Firestore service unavailable', tag: 'LiveKitCallState');
      },
    );
    sl<AppLogger>().debug('Listener registered and active', tag: 'LiveKitCallState');
  }

  /// Listen to call status changes on livekit_rooms
  /// Detects when Cloud Functions update call status
  void _listenToCallStatusChanges() {
    if (_currentUserId == null) {
      sl<AppLogger>().warning(
        'Cannot listen: _currentUserId is null',
        tag: 'LiveKitCallState',
      );
      return;
    }

    sl<AppLogger>().debug(
      'Listening for call status changes',
      tag: 'LiveKitCallState',
    );

    bool isFirstSnapshot = true;

    // Filter by user at query level to reduce Firestore billing & bandwidth
    // This is critical at scale - listening to ALL rooms is expensive
    _callStatusSubscription = _firestore
        .collection(_liveKitRoomsCollection)
        .where(
          Filter.or(
            Filter('caller_id', isEqualTo: _currentUserId),
            Filter('callee_id', isEqualTo: _currentUserId),
          ),
        )
        .snapshots()
        .listen(
          (snapshot) {
            if (_isDisposed) return;

            sl<AppLogger>().debug(
              'Room status snapshot: ${snapshot.docs.length} rooms',
              tag: 'LiveKitCallState',
            );

            for (final doc in snapshot.docs) {
              final roomId = doc.id;
              final status = doc.data()['status'] as String?;
              final calleeId = doc.data()['callee_id'] as String?;
              final callerId = doc.data()['caller_id'] as String?;
              final lastStatus = _lastEmittedStatus?[roomId];

              // Skip if not relevant to current user
              if (calleeId != _currentUserId && callerId != _currentUserId) {
                continue;
              }

              // Only process if status changed
              if (status == null || status == lastStatus || isFirstSnapshot) {
                if (status != null) {
                  _lastEmittedStatus![roomId] = status;
                }
                continue;
              }

              sl<AppLogger>().debug(
                'Status change: $roomId → $status (was $lastStatus)',
                tag: 'LiveKitCallState',
              );
              _lastEmittedStatus![roomId] = status;

              // Clear processed tracking on end states
              final isEndStatus =
                  status == 'ended' ||
                  status == 'missed' ||
                  status == 'cancelled' ||
                  status == 'rejected';
              if (isEndStatus) {
                _processedIncomingCalls?.remove(roomId);
                _lastIncomingCallTime?.remove(roomId);
              }

              // Emit generic status change
              final eventData = {
                'room_id': roomId,
                'status': status,
                'caller_id': callerId,
                'callee_id': calleeId,
                ...doc.data(),
              };

              _safeEmit(callStatusChangeController, eventData);

              // Emit specific status events
              switch (status) {
                case 'active':
                  sl<AppLogger>().debug(
                    'Call accepted: $roomId',
                    tag: 'LiveKitCallState',
                  );
                  _safeEmit(callAcceptedController, eventData);
                  break;
                case 'rejected':
                  sl<AppLogger>().debug(
                    'Call rejected: $roomId',
                    tag: 'LiveKitCallState',
                  );
                  _safeEmit(callRejectedController, eventData);
                  break;
                case 'missed':
                  sl<AppLogger>().debug(
                    'Call missed: $roomId',
                    tag: 'LiveKitCallState',
                  );
                  _safeEmit(callMissedController, eventData);
                  break;
                case 'ended':
                case 'cancelled':
                  sl<AppLogger>().debug(
                    'Call ended: $roomId ($status)',
                    tag: 'LiveKitCallState',
                  );
                  _safeEmit(callEndedController, eventData);
                  break;
                default:
                  sl<AppLogger>().debug(
                    'Status: $roomId → $status',
                    tag: 'LiveKitCallState',
                  );
              }
            }

            isFirstSnapshot = false;
          },
          onError: (e) {
            sl<AppLogger>().error(
              'Error listening to call status: $e',
              tag: 'LiveKitCallState',
              error: e,
            );
          },
        );
  }

  /// Safely emit event to stream controller
  void _safeEmit(
    StreamController<Map<String, dynamic>> controller,
    Map<String, dynamic> data,
  ) {
    try {
      if (!controller.isClosed) {
        controller.add(data);
      } else {
        sl<AppLogger>().warning(
          'Controller is closed, cannot emit',
          tag: 'LiveKitCallState',
        );
      }
    } catch (e) {
      sl<AppLogger>().error('Error emitting event: $e', tag: 'LiveKitCallState', error: e);
    }
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    sl<AppLogger>().debug('Disconnecting', tag: 'LiveKitCallState');
    _isDisposed = true;

    // Cancel subscriptions
    _incomingCallsSubscription?.cancel();
    _incomingCallsSubscription = null;
    _callStatusSubscription?.cancel();
    _callStatusSubscription = null;

    // Clear tracking
    _processedIncomingCalls?.clear();
    _lastIncomingCallTime?.clear();
    _lastEmittedStatus?.clear();

    // Close controllers
    try {
      if (!incomingCallController.isClosed) {
        incomingCallController.close();
      }
      if (!callStatusChangeController.isClosed) {
        callStatusChangeController.close();
      }
      if (!callAcceptedController.isClosed) {
        callAcceptedController.close();
      }
      if (!callRejectedController.isClosed) {
        callRejectedController.close();
      }
      if (!callMissedController.isClosed) {
        callMissedController.close();
      }
      if (!callEndedController.isClosed) {
        callEndedController.close();
      }
    } catch (e) {
      sl<AppLogger>().error('Error closing controllers: $e', tag: 'LiveKitCallState', error: e);
    }

    sl<AppLogger>().debug('Disconnected', tag: 'LiveKitCallState');
  }
}
