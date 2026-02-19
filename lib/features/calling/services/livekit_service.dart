import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:greenhive_app/features/calling/services/interfaces/room_service.dart';
import 'package:greenhive_app/features/calling/services/call_logger.dart';
import 'package:greenhive_app/features/calling/services/monitoring/call_quality_analyzer.dart';
import 'package:greenhive_app/core/config/livekit_config.dart';
import 'package:greenhive_app/core/errors/call_errors.dart';

class LiveKitService implements RoomService {
  // ----------------------------------------------------------------
  // STATIC / CROSS-INSTANCE COORDINATION
  // ----------------------------------------------------------------
  // These fields are STATIC because LiveKitService is registered as a
  // factory (new instance per call).  When Call-1 is still tearing down
  // and Call-2 creates a fresh instance, the new instance must be able
  // to detect the in-progress cleanup and wait for it.
  // ----------------------------------------------------------------

  /// Track when the last call ended to enforce minimum delay between calls.
  /// This prevents ICE failures when the same identity connects before
  /// the LiveKit server has cleaned up the previous session.
  static DateTime? _lastCallEndTime;

  /// True while ANY instance is running disconnect / _destroyRoom.
  static bool _isCleaningUp = false;

  /// Completer that resolves when the active cleanup finishes.
  /// A new connect() awaits this if [_isCleaningUp] is true.
  static Completer<void>? _cleanupCompleter;

  /// Number of consecutive calls where both default AND relay ICE failed.
  /// After 2+ failures on web, we throw [CallBrowserDegradedError] to
  /// suggest a page refresh.
  static int _consecutiveIceFailures = 0;

  // ----------------------------------------------------------------
  // INSTANCE STATE
  // ----------------------------------------------------------------

  // Dependencies
  final CallLogger _logger;
  final CallQualityAnalyzer _qualityAnalyzer;
  Room? _room;
  LocalParticipant? _local;
  RemoteParticipant? _remote;

  CancelListenFunc? _roomSub;
  CancelListenFunc? _localSub;
  CancelListenFunc? _remoteSub;

  bool _isDisposed = false;
  bool _connectCancelled = false;
  Timer? _remoteJoinTimer;
  Timer? _qualityTimer;

  // Set to true after room.connect() completes successfully (or via
  // timeout-tolerance). Used in the RoomConnectedEvent listener to
  // distinguish mid-call reconnections from the initial connect.
  bool _connectCompleted = false;

  // Tracks when the last RoomConnectedEvent was received. Used in the
  // timeout tolerance check: if signaling connected (RoomConnectedEvent)
  // within the last few seconds, the PeerConnection might still be viable
  // even if connectionState isn't "connected" yet.
  DateTime? _lastRoomConnectedEventTime;
  CallQualityStats? _currentQuality;

  // Stopwatch for elapsed-time logging during call lifecycle
  final Stopwatch _callStopwatch = Stopwatch();

  /// Returns elapsed time since connect() was called, formatted as 'Xms' or 'X.Xs'
  String get _elapsed {
    final ms = _callStopwatch.elapsedMilliseconds;
    if (ms < 10000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  final _connectionController = StreamController<bool>.broadcast();
  final _localController = StreamController<LocalParticipant?>.broadcast();
  final _remoteController = StreamController<RemoteParticipant?>.broadcast();
  final _callEndReasonController = StreamController<CallEndReason>.broadcast();
  final _callQualityController = StreamController<CallQualityStats>.broadcast();
  final _remoteTrackStatusController =
      StreamController<RemoteTrackStatus>.broadcast();

  @override
  Stream<bool> get connectionStateStream => _connectionController.stream;
  Stream<LocalParticipant?> get localParticipantStream =>
      _localController.stream;
  Stream<RemoteParticipant?> get remoteParticipantStream =>
      _remoteController.stream;
  @override
  Stream<CallEndReason> get callEndReasonStream =>
      _callEndReasonController.stream;
  @override
  Stream<CallQualityStats> get callQualityStream =>
      _callQualityController.stream;
  @override
  Stream<RemoteTrackStatus> get remoteTrackStatusStream =>
      _remoteTrackStatusController.stream;
  @override
  CallQualityStats? get currentCallQuality => _currentQuality;

  @override
  Room? get room => _room;
  @override
  LocalParticipant? get localParticipant => _local;
  @override
  List<RemoteParticipant> get remoteParticipants =>
      _remote == null ? [] : [_remote!];

  @override
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  /// 🔑 Derived state: remote joined but video not yet available
  bool get remoteHasVideo {
    if (_remote == null) return false;
    for (final pub in _remote!.videoTrackPublications) {
      if (pub.subscribed && pub.track != null) return true;
    }
    return false;
  }

  /// Check if remote video is muted or unavailable
  @override
  bool get isRemoteVideoMuted {
    if (_remote == null) return true;
    final pubs = _remote!.videoTrackPublications;
    if (pubs.isEmpty) return true;
    // Check if ANY video track is subscribed and not muted
    // A track is available if it's subscribed (track may still be populating)
    return !pubs.any((pub) => pub.subscribed && !pub.muted);
  }

  /// Check if remote audio is muted or unavailable
  @override
  bool get isRemoteAudioMuted {
    if (_remote == null) return true;
    final pubs = _remote!.audioTrackPublications;
    if (pubs.isEmpty) return true;
    // Check if ANY audio track is subscribed and not muted
    return !pubs.any((pub) => pub.subscribed && !pub.muted);
  }

  // --------------------------------------------------
  // CONSTRUCTOR
  // --------------------------------------------------
  LiveKitService({CallLogger? logger, CallQualityAnalyzer? qualityAnalyzer})
    : _logger = logger ?? DebugCallLogger(),
      _qualityAnalyzer = qualityAnalyzer ?? CallQualityAnalyzer();

  /// Reset static coordination state.  Only for tests.
  @visibleForTesting
  static void resetStaticState() {
    _lastCallEndTime = null;
    _isCleaningUp = false;
    _cleanupCompleter = null;
    _consecutiveIceFailures = 0;
  }

  // --------------------------------------------------
  // SAFE CONTROLLER ADD HELPER
  // --------------------------------------------------
  /// Safely adds an event to a stream controller, checking if disposed first
  void _safeAdd<T>(StreamController<T> controller, T value) {
    if (!_isDisposed && !controller.isClosed) {
      controller.add(value);
    }
  }

  // --------------------------------------------------
  // CONNECT
  // --------------------------------------------------
  @override
  Future<void> connect({
    required String url,
    required String token,
    required bool enableVideo,
    required bool enableAudio,
  }) async {
    _callStopwatch.reset();
    _callStopwatch.start();

    _logger.info('⏱️ [+$_elapsed] connect() START', {
      'url': url,
      'video': enableVideo,
      'audio': enableAudio,
    });

    // Reset any previous connect cancellation state
    _connectCancelled = false;

    // Enforce minimum delay between calls to allow server-side cleanup
    // This prevents ICE failures when the same identity connects before
    // the LiveKit server has cleaned up the previous session
    if (_lastCallEndTime != null) {
      final elapsed = DateTime.now()
          .difference(_lastCallEndTime!)
          .inMilliseconds;
      final remaining = LiveKitConfig.minTimeBetweenCallsMs - elapsed;
      if (remaining > 0) {
        _logger.info(
          '⏱️ [+$_elapsed] ⏳ Enforcing cooldown: ${remaining}ms remaining before next call',
        );
        await Future.delayed(Duration(milliseconds: remaining));
        _logger.debug('⏱️ [+$_elapsed] Cooldown complete');
      }
    }

    // Wait for any previous instance's cleanup to complete.
    // _isCleaningUp and _cleanupCompleter are STATIC so a fresh factory
    // instance can detect that an older instance is still tearing down.
    if (_isCleaningUp && _cleanupCompleter != null) {
      _logger.debug(
        '⏱️ [+$_elapsed] Waiting for previous call cleanup to finish...',
      );
      try {
        await _cleanupCompleter!.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            _logger.warning(
              '⚠️ Previous cleanup timeout after 8s - forcing reset',
            );
            _isCleaningUp = false;
          },
        );
        _logger.debug('⏱️ [+$_elapsed] Previous cleanup finished');
      } catch (e) {
        _logger.warning('Cleanup wait error: $e');
        _isCleaningUp = false;
      }
    }

    if (_room != null) {
      _logger.warning('Room already exists, disconnecting...');
      await disconnect();
    }

    try {
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          // Ensure auto-subscribe is enabled (default is true)
          defaultVideoPublishOptions: VideoPublishOptions(simulcast: true),
          defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
        ),
      );

      _attachRoomListeners();

      // ICE transport strategy:
      // - FIRST attempt: default ICE policy (all candidates) with 30s timeout.
      //   SRFLX/host candidates work well on most networks.
      // - FALLBACK: relay only with 15s timeout.
      //   If SRFLX fails (restrictive NAT/firewall), TURN relay may help.

      // Both web and native start with default ICE (host/SRFLX).
      // Relay is used as fallback if default ICE fails.
      bool useRelay = false;
      bool isRetryAttempt = false;
      // Reset connect-completed flag for this connection attempt.
      _connectCompleted = false;
      _lastRoomConnectedEventTime = null;

      while (true) {
        try {
          final timeoutSeconds = isRetryAttempt
              ? LiveKitConfig.iceRetryTimeoutSeconds
              : LiveKitConfig.iceFirstAttemptTimeoutSeconds;
          _logger.info(
            '⏱️ [+$_elapsed] Connecting (ICE: ${useRelay ? "relay" : "default"}, timeout: ${timeoutSeconds}s${isRetryAttempt ? ", retry" : ""})',
          );

          await _room!.connect(
            url,
            token,
            connectOptions: ConnectOptions(
              autoSubscribe: true,
              // First attempt uses default ICE (SRFLX/host).
              // On retry, policy flips to relay-only as fallback.
              rtcConfiguration: useRelay
                  ? const RTCConfiguration(
                      iceTransportPolicy: RTCIceTransportPolicy.relay,
                    )
                  : const RTCConfiguration(),
              timeouts: Timeouts(
                connection: Duration(seconds: timeoutSeconds),
                debounce: const Duration(milliseconds: 100),
                publish: Duration(seconds: LiveKitConfig.sdkMediaTimeoutSeconds),
                subscribe: Duration(seconds: LiveKitConfig.sdkMediaTimeoutSeconds),
                peerConnection: Duration(seconds: LiveKitConfig.sdkPeerConnectTimeoutSeconds),
                iceRestart: Duration(seconds: LiveKitConfig.sdkIceRestartTimeoutSeconds),
              ),
            ),
          );
          _logger.info('⏱️ [+$_elapsed] Server connection SUCCESS');

          _consecutiveIceFailures = 0;
          _connectCompleted = true;
          break; // success
        } catch (e) {
          // Check for cancellation FIRST before logging errors
          // This prevents stale errors from polluting logs for subsequent calls
          if (_connectCancelled || _isDisposed) {
            _logger.debug(
              'Connection error ignored - connect was cancelled/disposed: $e',
            );
            await _destroyRoom(
              waitForBrowser: false,
            ); // Quick cleanup, no wait needed
            return;
          }

          // The SDK's room.connect() future can time out
          // (MediaConnectException) even though the SDK's INTERNAL
          // reconnection loop has already re-established the
          // PeerConnection.  This happens when the overall connection
          // timeout fires slightly after the internal ICE restart
          // succeeds (observed at ~21-28s in production logs).
          //
          // Tolerance check:
          // 1. Primary: room.connectionState == connected
          // 2. Secondary: RoomConnectedEvent fired within last 5s (SDK
          //    considers signaling connected, PeerConnection might be
          //    establishing)
          // If either is true, treat the timeout as benign.
          if (e.toString().contains('MediaConnectException')) {
            final state = _room?.connectionState;
            final recentlyConnected =
                _lastRoomConnectedEventTime != null &&
                DateTime.now()
                        .difference(_lastRoomConnectedEventTime!)
                        .inSeconds <
                    5;

            if (state == ConnectionState.connected) {
              _logger.info(
                '⏱️ [+$_elapsed] room.connect() timed out but room is CONNECTED '
                'via internal reconnection — treating as success',
              );
              _consecutiveIceFailures = 0;
              _connectCompleted = true;
              break;
            } else if (recentlyConnected) {
              _logger.info(
                '⏱️ [+$_elapsed] room.connect() timed out, connectionState=$state '
                'but RoomConnectedEvent fired recently — treating as success',
              );
              _consecutiveIceFailures = 0;
              _connectCompleted = true;
              break;
            }

            _logger.warning(
              '⏱️ [+$_elapsed] Tolerance check failed: connectionState=$state, '
              'lastRoomConnectedEventTime=$_lastRoomConnectedEventTime',
            );
          }

          _logger.error('⏱️ [+$_elapsed] Server connection FAILED', e);
          // Use quick cleanup for retry (no browser wait) vs full cleanup for final failure
          final willRetry =
              !isRetryAttempt && e.toString().contains('MediaConnectException');
          await _destroyRoom(waitForBrowser: !willRetry);

          // If a disconnect/cancel occurred while attempting to connect, abort quietly
          if (_connectCancelled || _isDisposed) {
            _logger.warning(
              'Connect attempt cancelled during cleanup; aborting connect flow',
            );
            return;
          }
          // Retry once with flipped ICE policy, if not already attempted
          if (willRetry) {
            isRetryAttempt = true;
            // Flip: default→relay as fallback
            useRelay = !useRelay;
            _logger.warning(
              '⏱️ [+$_elapsed] ICE failed, retrying with ${useRelay ? "TURN relay" : "default ICE"} (attempt 2)',
            );

            // Recreate room for a clean retry
            _logger.debug('Creating new Room for retry...');
            _room = Room(
              roomOptions: const RoomOptions(
                adaptiveStream: true,
                dynacast: true,
                defaultVideoPublishOptions: VideoPublishOptions(
                  simulcast: true,
                ),
                defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
              ),
            );
            _attachRoomListeners();
            // loop continues and attempts connect with relay
            continue;
          }

          // Both default + relay have failed.
          _consecutiveIceFailures++;

          _logger.warning(
            '⏱️ [+$_elapsed] All ICE attempts exhausted '
            '(consecutive failures: $_consecutiveIceFailures)',
          );

          // After 2+ consecutive total ICE failures on web, Chrome's
          // WebRTC stack is likely degraded beyond repair.  Throw a
          // specific error so the UI can suggest a page refresh.
          if (kIsWeb && _consecutiveIceFailures >= 2) {
            throw CallBrowserDegradedError(originalError: e);
          }

          rethrow;
        }
      }

      _local = _room!.localParticipant;
      _logger.debug('Local participant: ${_local?.identity}');
      _safeAdd(_localController, _local);

      // If disconnect/cancel occurred after connect, abort before enabling media
      if (_connectCancelled || _isDisposed || _room == null) {
        _logger.warning(
          'Connect flow cancelled before enabling media; exiting connect() gracefully',
        );
        return;
      }

      // Enable audio and video in parallel for faster activation.
      final mediaEnableTimeout = LiveKitConfig.mediaEnableTimeoutSeconds;
      if (enableAudio && enableVideo && !_connectCancelled) {
        _logger.debug('⏱️ [+$_elapsed] Enabling audio and video...');
        try {
          await Future.wait([
            (_local?.setMicrophoneEnabled(true) ?? Future.value())
                .timeout(
                  Duration(seconds: mediaEnableTimeout),
                  onTimeout: () {
                    _logger.warning(
                      'Microphone enable timeout (${mediaEnableTimeout}s)',
                    );
                    return null;
                  },
                )
                .catchError((e) {
                  if (e.toString().contains('Permission denied')) {
                    _logger.warning('Microphone permission denied');
                  } else {
                    _logger.warning('Microphone enable error: $e');
                  }
                  return null;
                }),
            (_local?.setCameraEnabled(true) ?? Future.value())
                .timeout(
                  Duration(seconds: mediaEnableTimeout),
                  onTimeout: () {
                    _logger.warning(
                      'Camera enable timeout (${mediaEnableTimeout}s)',
                    );
                    return null;
                  },
                )
                .catchError((e) {
                  if (e.toString().contains('Permission denied')) {
                    _logger.warning('Camera permission denied');
                  } else {
                    _logger.warning('Camera enable error: $e');
                  }
                  return null;
                }),
          ]);
          _logger.debug('⏱️ [+$_elapsed] Audio and video enabled');

          // CRITICAL: Check cancellation AFTER enabling media
          // The peer may have rejected while we were acquiring camera/mic
          // If cancelled, disconnect() is handling cleanup
          if (_connectCancelled || _isDisposed) {
            _logger.warning(
              'Media enabled but connect was cancelled - cleanup in progress',
            );
            return;
          }
        } catch (e) {
          if (_connectCancelled || _isDisposed) {
            _logger.warning('Media enable aborted due to cancellation');
            return;
          }
          _logger.error('Error enabling media in parallel', e);
        }
      } else if (enableAudio && !_connectCancelled) {
        _logger.debug('⏱️ [+$_elapsed] Enabling audio...');
        try {
          final micFuture = _local?.setMicrophoneEnabled(true);
          if (micFuture != null) {
            await micFuture.timeout(
              Duration(seconds: mediaEnableTimeout),
              onTimeout: () {
                _logger.warning(
                  'Microphone enable timeout (${mediaEnableTimeout}s)',
                );
                return null;
              },
            );
          }
        } catch (e) {
          // If cancellation happened while enabling, exit quietly
          if (_connectCancelled || _isDisposed) {
            _logger.warning('Microphone enable aborted due to cancellation');
            return;
          }
          // Don't fail the entire call if mic permission denied
          if (e.toString().contains('Permission denied')) {
            _logger.warning(
              'Microphone permission denied - continuing without audio',
            );
          } else {
            rethrow;
          }
        }
        _logger.debug('⏱️ [+$_elapsed] Audio enabled');

        // Check cancellation after enabling
        if (_connectCancelled || _isDisposed) {
          _logger.warning(
            'Audio enabled but connect was cancelled - cleanup in progress',
          );
          return;
        }
      } else if (enableVideo && !_connectCancelled) {
        _logger.debug('⏱️ [+$_elapsed] Enabling video...');
        try {
          final cameraFuture = _local?.setCameraEnabled(true);
          if (cameraFuture != null) {
            await cameraFuture.timeout(
              Duration(seconds: mediaEnableTimeout),
              onTimeout: () {
                _logger.warning(
                  'Camera enable timeout (${mediaEnableTimeout}s)',
                );
                return null;
              },
            );
          }
        } catch (e) {
          if (_connectCancelled || _isDisposed) {
            _logger.warning('Camera enable aborted due to cancellation');
            return;
          }
          // Don't fail the entire call if camera permission denied
          if (e.toString().contains('Permission denied')) {
            _logger.warning(
              'Camera permission denied - continuing without video',
            );
          } else {
            rethrow;
          }
        }
        _logger.debug('⏱️ [+$_elapsed] Video enabled');

        // Check cancellation after enabling
        if (_connectCancelled || _isDisposed) {
          _logger.warning(
            'Video enabled but connect was cancelled - cleanup in progress',
          );
          return;
        }
      }

      // Final cancellation check before marking as connected
      if (_connectCancelled || _isDisposed) {
        _logger.warning(
          'Connect completing but was cancelled - not marking connected',
        );
        return;
      }

      _safeAdd(_connectionController, true);

      // Auto-start timeout if remote hasn't joined yet
      if (_remote == null) {
        startRemoteJoinTimeout();
      }

      _logger.info('⏱️ [+$_elapsed] connect() COMPLETE');
    } catch (e) {
      // If anything goes wrong during connection setup, ensure complete cleanup
      _logger.error('connect() FAILED - performing emergency cleanup', e);

      // Cancel any active timers
      cancelRemoteJoinTimeout();
      stopQualityMonitoring();

      // Destroy room if it was created
      if (_room != null) {
        try {
          await _destroyRoom(waitForBrowser: true);
        } catch (cleanupError) {
          _logger.warning('Error during emergency cleanup: $cleanupError');
        }
      }

      // Reset all state
      _room = null;
      _local = null;
      _remote = null;
      // Note: do NOT reset static _isCleaningUp here — _destroyRoom handles that

      // If the connect was cancelled (for example due to remote leaving and we decided to disconnect),
      // swallow the error to avoid surfacing a failure state to the UI.
      if (_connectCancelled || _isDisposed) {
        _logger.warning('connect() error ignored due to cancellation/dispose');
        return;
      }
      rethrow;
    }
  }

  // --------------------------------------------------
  // LISTENERS
  // --------------------------------------------------
  void _attachRoomListeners() {
    final room = _room!;

    _roomSub = room.events.listen((event) {
      if (event is RoomConnectedEvent) {
        _logger.info(
          '⏱️ [+$_elapsed] 🟢 Room CONNECTED (signaling established, connectionState: ${room.connectionState})',
        );
        _lastRoomConnectedEventTime = DateTime.now();

        // After the initial connect() completes, any subsequent
        // RoomConnectedEvent means the SDK has re-established the
        // connection internally (e.g. after a brief ICE drop).
        // The SDK sometimes fires RoomConnectedEvent instead of
        // RoomReconnectedEvent in this case, so we handle both.
        if (_connectCompleted) {
          _logger.info(
            '⏱️ [+$_elapsed] 🟢 Room RE-CONNECTED via RoomConnectedEvent',
          );
          _local = room.localParticipant;
          _safeAdd(_localController, _local);
          _safeAdd(_connectionController, true);

          // Re-check remote participant after reconnection
          if (_remote != null && room.remoteParticipants.isEmpty) {
            _logger.info('Remote participant gone after reconnection');
            _handleRemoteLeft();
          } else if (room.remoteParticipants.isNotEmpty && _remote == null) {
            _logger.info('Remote participant appeared after reconnection');
            _setRemote(room.remoteParticipants.values.first);
          }
        }
      }

      if (event is RoomReconnectingEvent) {
        _logger.warning(
          '⏱️ [+$_elapsed] 🟡 Room RECONNECTING (connectionState: ${room.connectionState})',
        );
        _safeAdd(_connectionController, false);
      }

      if (event is RoomAttemptReconnectEvent) {
        _logger.warning(
          '⏱️ [+$_elapsed] 🔄 Room ATTEMPTING RECONNECT '
          '(attempt: ${event.attempt}/${event.maxAttemptsRetry}, '
          'nextDelay: ${event.nextRetryDelaysInMs}ms, '
          'connectionState: ${room.connectionState})',
        );

        // On web, if we're past attempt 5, the ICE/TURN is likely degraded
        // and further SDK reconnection attempts will just create more
        // DUPLICATE_IDENTITY errors. Force disconnect to break the loop.
        if (kIsWeb && event.attempt >= 5) {
          _logger.error(
            '⏱️ [+$_elapsed] ❌ Excessive reconnection attempts on web - '
            'forcing disconnect to prevent DUPLICATE_IDENTITY loop',
            null,
          );
          _connectCancelled = true;
          _safeAdd(_callEndReasonController, CallEndReason.connectionFailure);

          // Schedule disconnect to happen after this event handler completes.
          Future.microtask(() => disconnect());
        }
      }

      if (event is RoomDisconnectedEvent) {
        _logger.warning(
          '⏱️ [+$_elapsed] 🔴 Room DISCONNECTED (reason: ${event.reason})',
        );
        _safeAdd(_connectionController, false);

        // Handle critical disconnect reasons that should NOT trigger SDK reconnection.
        // DUPLICATE_IDENTITY: Server detected overlapping sessions with same identity.
        //   This happens when SDK's internal reconnection creates a new connection
        //   before the old one fully closes. Letting the SDK continue reconnecting
        //   creates an infinite loop of duplicate sessions being kicked.
        // JOIN_FAILURE: Server join timeout (JOIN_TIMEOUT in server logs).
        //   After ~45s of failed reconnection attempts, server gives up.
        //   Further reconnection attempts are futile.
        // RECONNECT_ATTEMPTS_EXCEEDED: SDK itself gave up after max retries.
        if (event.reason == DisconnectReason.duplicateIdentity ||
            event.reason == DisconnectReason.joinFailure ||
            event.reason == DisconnectReason.reconnectAttemptsExceeded) {
          _logger.error(
            '⏱️ [+$_elapsed] ❌ Fatal disconnect: ${event.reason} - forcing call end',
            null,
          );
          // Clear room reference to prevent SDK from continuing reconnection loop.
          // This must happen synchronously before SDK's next reconnect attempt.
          _connectCancelled = true;

          // Emit call end reason so UI can show appropriate message
          final endReason = event.reason == DisconnectReason.duplicateIdentity
              ? CallEndReason.connectionFailure // Session overlap from ICE issues
              : event.reason == DisconnectReason.joinFailure
                  ? CallEndReason.timeout
                  : CallEndReason.error;
          _safeAdd(_callEndReasonController, endReason);

          // Schedule disconnect to happen after this event handler completes.
          // This stops the SDK's reconnection loop without blocking the event callback.
          Future.microtask(() => disconnect());
        }
      }

      if (event is RoomReconnectedEvent) {
        _logger.info(
          '⏱️ [+$_elapsed] 🟢 Room RECONNECTED (media should now flow)',
        );

        _local = room.localParticipant;
        _safeAdd(_localController, _local);
        _safeAdd(_connectionController, true);

        // After reconnection, verify remote participant is still present.
        // During reconnection the SDK drops & re-adds participants;
        // if the remote truly left while we were reconnecting, handle it now.
        if (_remote != null && room.remoteParticipants.isEmpty) {
          _logger.info('Remote participant gone after reconnection');
          _handleRemoteLeft();
        } else if (room.remoteParticipants.isNotEmpty && _remote == null) {
          _logger.info('Remote participant appeared after reconnection');
          _setRemote(room.remoteParticipants.values.first);
        }
      }

      if (event is ParticipantConnectedEvent) {
        _logger.info(
          '⏱️ [+$_elapsed] Remote participant JOINED: ${event.participant.identity}',
        );
        _setRemote(event.participant);
      }

      if (event is ParticipantDisconnectedEvent &&
          event.participant.identity == _remote?.identity) {
        // Only treat as a real "remote left" when the room is fully
        // connected.  During the SDK's internal reconnection (or the
        // initial PeerConnection setup inside room.connect()), the SDK
        // temporarily drops all participants and fires
        // ParticipantDisconnectedEvent.  Reacting to that tears down the
        // call prematurely and prevents the ICE-relay retry from running.
        final roomState = _room?.connectionState;
        if (roomState == ConnectionState.connected) {
          _logger.info(
            '⏱️ [+$_elapsed] Remote participant LEFT: ${event.participant.identity}',
          );
          _handleRemoteLeft();
        } else {
          _logger.debug(
            '⏱️ [+$_elapsed] Ignoring ParticipantDisconnected during '
            'non-connected state (room: $roomState)',
          );
        }
      }

      if (event is TrackSubscribedEvent) {
        _handleRemoteTrackEvent(event.participant);
      }

      if (event is TrackPublishedEvent) {
        _handleRemoteTrackEvent(event.participant);
      }
    });

    _localSub = room.localParticipant?.events.listen((_) {
      _safeAdd(_localController, room.localParticipant);
    });

    if (room.remoteParticipants.isNotEmpty) {
      _setRemote(room.remoteParticipants.values.first);
    }
  }

  void _setRemote(RemoteParticipant participant) {
    cancelRemoteJoinTimeout();

    if (_remote?.identity == participant.identity) return;

    _logger.info('Switching remote participant to: ${participant.identity}');
    _remoteSub?.call();
    _remote = participant;
    _safeAdd(_remoteController, _remote);

    // Emit initial track status - tracks might already be subscribed
    final initialStatus = RemoteTrackStatus(
      videoMuted: isRemoteVideoMuted,
      audioMuted: isRemoteAudioMuted,
    );
    _logger.debug('Initial track state', {
      'videoPubs': participant.videoTrackPublications.length,
      'audioPubs': participant.audioTrackPublications.length,
    });
    _safeAdd(_remoteTrackStatusController, initialStatus);

    _remoteSub = participant.events.listen((event) {
      if (event is TrackSubscribedEvent ||
          event is TrackUnsubscribedEvent ||
          event is TrackMutedEvent ||
          event is TrackUnmutedEvent) {
        _logger.debug('⏱️ [+$_elapsed] Remote track ${event.runtimeType}');
        _safeAdd(_remoteController, _remote);

        final status = RemoteTrackStatus(
          videoMuted: isRemoteVideoMuted,
          audioMuted: isRemoteAudioMuted,
        );
        _safeAdd(_remoteTrackStatusController, status);
      }
    });
  }

  void _clearRemote() {
    _remoteSub?.call();
    _remoteSub = null;
    _remote = null;
    _safeAdd(_remoteController, null);
  }

  /// Handle remote track events from room-level listener
  /// This is important for tracks that were published before we joined
  void _handleRemoteTrackEvent(RemoteParticipant participant) {
    if (_remote == null || participant.identity != _remote!.identity) {
      if (_remote == null) _setRemote(participant);
      return;
    }

    _remote = participant;
    _safeAdd(_remoteController, _remote);
    _safeAdd(_remoteTrackStatusController, _getTrackStatusFromParticipant(participant));
  }

  /// Get track status directly from a participant (uses event data, not cached _remote)
  RemoteTrackStatus _getTrackStatusFromParticipant(
    RemoteParticipant participant,
  ) {
    final videoPubs = participant.videoTrackPublications;
    final audioPubs = participant.audioTrackPublications;

    // Video is available if ANY publication is subscribed and not muted
    final videoMuted =
        videoPubs.isEmpty ||
        !videoPubs.any((pub) => pub.subscribed && !pub.muted);

    // Audio is available if ANY publication is subscribed and not muted
    final audioMuted =
        audioPubs.isEmpty ||
        !audioPubs.any((pub) => pub.subscribed && !pub.muted);

    return RemoteTrackStatus(videoMuted: videoMuted, audioMuted: audioMuted);
  }

  // --------------------------------------------------
  // REMOTE JOIN TIMEOUT
  // --------------------------------------------------
  @override
  void startRemoteJoinTimeout({
    Duration duration = const Duration(
      seconds: LiveKitConfig.remoteJoinTimeoutSeconds,
    ),
  }) {
    _logger.info('startRemoteJoinTimeout() - ${duration.inSeconds}s');
    cancelRemoteJoinTimeout();

    _remoteJoinTimer = Timer(duration, () async {
      if (_remote == null && _room != null && !_isCleaningUp) {
        _logger.warning(
          'TIMEOUT - Remote never joined after ${duration.inSeconds}s',
        );
        _safeAdd(_callEndReasonController, CallEndReason.timeout);
        await disconnect();
      }
    });
  }

  @override
  void cancelRemoteJoinTimeout() {
    if (_remoteJoinTimer?.isActive ?? false) {
      _logger.debug('cancelRemoteJoinTimeout() - timer cancelled');
      _remoteJoinTimer?.cancel();
    }
    _remoteJoinTimer = null;
  }

  // --------------------------------------------------
  // CALL QUALITY MONITORING
  // --------------------------------------------------
  @override
  void startQualityMonitoring({
    Duration interval = const Duration(
      seconds: LiveKitConfig.qualityMonitorIntervalSeconds,
    ),
  }) {
    _logger.info('startQualityMonitoring() - ${interval.inSeconds}s interval');
    stopQualityMonitoring();

    _qualityTimer = Timer.periodic(interval, (_) => _collectQualityStats());
    // Collect initial stats immediately
    _collectQualityStats();
  }

  @override
  void stopQualityMonitoring() {
    if (_qualityTimer?.isActive ?? false) {
      _logger.debug('stopQualityMonitoring() - stopped');
      _qualityTimer?.cancel();
    }
    _qualityTimer = null;
  }

  Future<void> _collectQualityStats() async {
    if (_room == null || !isConnected) return;

    try {
      _currentQuality = await _qualityAnalyzer.collectStats(
        localParticipant: _local,
        remoteParticipant: _remote,
      );

      _safeAdd(_callQualityController, _currentQuality!);
    } catch (e) {
      _logger.warning('Error collecting quality stats: $e');
    }
  }

  // --------------------------------------------------
  // AUTO END
  // --------------------------------------------------
  Future<void> _handleRemoteLeft() async {
    if (_isCleaningUp) {
      return;
    }
    _clearRemote();
    _safeAdd(_callEndReasonController, CallEndReason.remoteLeft);
    await Future.delayed(
      const Duration(milliseconds: LiveKitConfig.remoteLeftDelayMs),
    );
    await disconnect();
  }

  // --------------------------------------------------
  // MEDIA CONTROLS
  // --------------------------------------------------
  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _local?.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    if (_isCleaningUp ||
        _room == null ||
        _room?.connectionState != ConnectionState.connected) {
      return;
    }
    await _local?.setCameraEnabled(enabled);
    await Future.delayed(
      const Duration(milliseconds: LiveKitConfig.cameraToggleDelayMs),
    );
    _safeAdd(_localController, _local);
  }

  @override
  bool isMicrophoneEnabled() {
    return _local?.isMicrophoneEnabled() ?? false;
  }

  @override
  bool isCameraEnabled() {
    return _local?.isCameraEnabled() ?? false;
  }

  // --------------------------------------------------
  // DISCONNECT / CLEANUP
  // --------------------------------------------------
  @override
  Future<void> disconnect() async {
    _logger.info('⏱️ [+$_elapsed] disconnect() START');

    // If a connect is in-flight, mark it as cancelled so we can ignore late errors
    _connectCancelled = true;

    // Guard against double disconnect (static: covers cross-instance calls too)
    if (_isCleaningUp) {
      _logger.debug('Already disconnecting (static guard), skipping');
      return;
    }

    if (_room == null) {
      _logger.debug('Room already null, skipping');
      return;
    }

    _isCleaningUp = true;
    _cleanupCompleter = Completer<void>();

    try {
      cancelRemoteJoinTimeout();
      stopQualityMonitoring();

      // Check if already disposed before adding to controllers
      if (!_isDisposed) {
        _safeAdd(_connectionController, false);
      }

      // Cancel subscriptions
      _roomSub?.call();
      _localSub?.call();
      _remoteSub?.call();

      await _destroyRoom(waitForBrowser: true);

      // Check if already disposed before adding to controllers
      // (dispose() may have been called during the browser cleanup wait)
      if (!_isDisposed) {
        _safeAdd(_localController, null);
        _safeAdd(_remoteController, null);
      }
    } catch (e) {
      _logger.error('Error during disconnect', e, null);
    } finally {
      // ALWAYS clear static cleanup flag and complete the Completer,
      // even on error.  This unblocks any new connect() waiting on us.
      _isCleaningUp = false;
      if (_cleanupCompleter != null && !_cleanupCompleter!.isCompleted) {
        _cleanupCompleter!.complete();
      }
    }

    _callStopwatch.stop();
    _logger.info('⏱️ [+$_elapsed] disconnect() COMPLETE');
  }

  Future<void> _destroyRoom({required bool waitForBrowser}) async {
    final roomToDestroy = _room;

    // Cancel event subscriptions FIRST to prevent old room events from
    // interfering during cleanup or retry (e.g., stale RoomDisconnectedEvent
    // resetting connection state while the new retry room is connecting).
    _roomSub?.call();
    _localSub?.call();
    _remoteSub?.call();

    _local = null;
    _remote = null;
    _room = null;

    try {
      if (roomToDestroy == null) return;

      final localParticipant = roomToDestroy.localParticipant;
      final isConnected =
          roomToDestroy.connectionState == ConnectionState.connected;

      // On Web, we need to stop media stream tracks DIRECTLY to release camera/mic
      // This must be done BEFORE disconnecting the room because:
      // 1. unpublishAllTracks() tries to call replaceTrack() on RTCRtpSender
      // 2. If peer connection is closed, replaceTrack() fails with InvalidStateError
      // So we stop the underlying mediaStreamTrack first, then disconnect
      if (kIsWeb && localParticipant != null) {
        for (var pub in localParticipant.trackPublications.values) {
          try {
            final track = pub.track;
            if (track != null) {
              // Stop the underlying browser MediaStreamTrack to release hardware
              await track.mediaStreamTrack.stop();
            }
          } catch (e) {
            _logger.warning('Error stopping mediaStreamTrack: $e');
          }
        }
      }

      // ---------------------------------------------------------------
      // Quick cleanup path (retry / cancel): fire-and-forget the slow
      // disconnect + dispose so the retry can start immediately.
      // roomToDestroy.disconnect() can block 10+ seconds waiting for
      // the SDK's internal PeerConnection ICE timeout, which stalls the
      // retry and lets the TURN warmup expire.
      // ---------------------------------------------------------------
      if (!waitForBrowser) {
        // When ICE has timed out, disconnect() blocks 10+ seconds waiting
        // for a graceful close that will never happen. Running it as
        // fire-and-forget is worse: the background disconnect competes
        // for browser WebRTC resources and kills the new relay room ~6s
        // later (observed as consistent relay disconnections).
        // Instead: skip disconnect entirely (PeerConnection is already
        // dead) and just dispose synchronously.
        if (!kIsWeb &&
            localParticipant != null &&
            localParticipant.trackPublications.isNotEmpty) {
          try {
            await localParticipant.unpublishAllTracks(stopOnUnpublish: true);
          } catch (_) {}
        }
        try {
          await roomToDestroy.dispose();
        } catch (e) {
          _logger.debug('Quick dispose error: $e');
        }
        // Let Chrome fully release PeerConnection resources (ICE agents,
        // TURN allocations, UDP port bindings) before creating the relay
        // room. 500ms was insufficient — relay rooms inherited stale state
        // and suffered reconnect loops. 1500ms matches the time Chrome
        // needs for its internal RTCPeerConnection cleanup.
        if (kIsWeb) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        return;
      }

      // ---------------------------------------------------------------
      // Full cleanup path: await everything for graceful shutdown.
      // ---------------------------------------------------------------
      if (isConnected) {
        try {
          await roomToDestroy.disconnect();
        } catch (e) {
          _logger.warning('Error disconnecting room: $e');
        }
      }

      // On mobile, stop tracks after disconnect (peer connection handling is different)
      if (!kIsWeb &&
          localParticipant != null &&
          localParticipant.trackPublications.isNotEmpty) {
        try {
          await localParticipant.unpublishAllTracks(stopOnUnpublish: true);
        } catch (e) {
          _logger.debug('Error unpublishing tracks (expected if already closed): $e');
        }
      }

      try {
        await roomToDestroy.dispose();
      } catch (e) {
        _logger.warning('Error disposing room: $e');
      }

      // Wait for WebRTC resources to fully release before next call
      await Future.delayed(Duration(seconds: LiveKitConfig.platformCleanupSeconds));
    } finally {
      // ALWAYS record when call ended for cooldown enforcement
      // This ensures next call has proper delay even if cleanup failed
      _lastCallEndTime = DateTime.now();
    }
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _logger.info('dispose() START');
    _isDisposed = true; // Set BEFORE closing controllers

    await disconnect();
    await _connectionController.close();
    await _localController.close();
    await _remoteController.close();
    await _callEndReasonController.close();
    await _callQualityController.close();
    await _remoteTrackStatusController.close();
    _logger.info('dispose() COMPLETE');
  }

  @override
  RemoteParticipant? getRemoteParticipant() {
    return _remote;
  }

  @override
  Stream<LocalParticipant?> get localStreamStream {
    return _localController.stream;
  }

  @override
  Stream<List<RemoteParticipant>> get participantsStream {
    return _remoteController.stream.map((remote) {
      if (remote == null) return <RemoteParticipant>[];
      return <RemoteParticipant>[remote];
    });
  }

  @override
  Future<void> updateRemoteParticipants() async {
    if (_room == null) return;

    if (_room!.remoteParticipants.isEmpty) {
      _clearRemote();
      return;
    }

    final participant = _room!.remoteParticipants.values.first;
    if (_remote?.identity != participant.identity) {
      _setRemote(participant);
    } else {
      _safeAdd(_remoteController, _remote);
    }
  }
}
