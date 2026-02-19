import 'dart:async';
import 'package:flutter/material.dart';
import 'package:securityexperts_app/data/models/call_session.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/signaling_service.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/media_manager_factory.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/room_service.dart';
import 'package:securityexperts_app/features/calling/services/call_logger.dart';
import 'package:securityexperts_app/features/calling/services/callkit/callkit_service.dart';
import 'package:securityexperts_app/core/config/call_config.dart';
import 'package:securityexperts_app/core/errors/call_errors.dart';
import 'package:securityexperts_app/core/errors/call_error_handler.dart';
import 'package:securityexperts_app/features/calling/services/analytics/call_analytics.dart';
import 'package:securityexperts_app/features/calling/services/monitoring/network_quality_monitor.dart';
import 'package:securityexperts_app/features/calling/services/media/media_manager.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/shared/services/ringtone_service.dart';

enum CallState { initial, connecting, connected, ended, failed, reconnecting }

/// Controller for managing call lifecycle and state
///
/// This controller orchestrates the call flow including:
/// - Signaling (creating/joining rooms)
/// - Media management (camera, microphone, video rendering)
/// - State transitions
/// - Error handling
/// - Resource cleanup
class CallController extends ChangeNotifier {
  // Instance tracking for debugging duplicate instances
  static int _instanceCounter = 0;
  static int _activeInstances = 0;
  final int _instanceId;

  final SignalingService _signaling;
  final MediaManagerFactory _mediaFactory;
  final CallLogger _logger;
  final CallConfig _config;
  final CallErrorHandler _errorHandler;
  final CallAnalytics? _analytics;
  final NetworkQualityMonitor? _networkMonitor;

  MediaManager? _mediaManager;
  MediaManager? get mediaManager => _mediaManager;

  // Call Parameters
  final bool isCaller;
  final String? calleeId;
  final String? callId;
  final bool isVideo;

  // Internal State
  CallState _callState = CallState.initial;
  String? _errorMessage;
  final ValueNotifier<int> _durationSeconds = ValueNotifier<int>(0);
  CallSession? _session;
  DateTime? _callStartTime;
  DateTime? _connectionTime;

  // Resource tracking
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  Timer? _callTimeoutTimer; // Explicitly tracked for proper cancellation
  Timer? _durationTimer; // Track duration timer to prevent duplicates
  VoidCallback? _mediaConnectedListener;
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed; // Public getter for UI safety checks
  bool _isEndingCall =
      false; // Flag to suppress errors during intentional call termination
  bool _calleeAccepted =
      false; // Callee accepted via signaling (defer UI transition until media ready)
  bool _mediaReady = false; // Media (room.connect) completed successfully

  // Call quality and end reason state
  CallQualityStats? _currentQuality;
  CallEndReason? _lastEndReason;

  // Store actual error for proper error preservation
  CallError? _lastError;

  // Public Getters
  CallState get callState => _callState;
  String? get errorMessage => _errorMessage;
  CallError? get error => _lastError;
  ValueNotifier<int> get durationSeconds => _durationSeconds;
  CallSession? get session => _session;
  bool get isMuted => _mediaManager?.isMuted.value ?? false;
  bool get isVideoEnabled => _mediaManager?.isVideoEnabled.value ?? true;
  bool get isSpeakerOn => _mediaManager?.isSpeakerOn.value ?? true;
  NetworkQuality get networkQuality =>
      _networkMonitor?.quality ?? NetworkQuality.disconnected;

  /// Current call quality statistics (null if not connected or quality monitoring disabled)
  CallQualityStats? get callQuality =>
      _currentQuality ?? _mediaManager?.currentCallQuality;

  /// The reason the call ended (null if call hasn't ended)
  CallEndReason? get callEndReason => _lastEndReason;

  /// Whether remote video is muted
  bool get isRemoteVideoMuted =>
      _mediaManager?.isRemoteVideoEnabled.value != true;

  /// Whether remote audio is muted
  bool get isRemoteAudioMuted =>
      _mediaManager?.isRemoteAudioMuted?.value ?? false;

  CallController({
    required this.isCaller,
    required this.isVideo,
    required SignalingService signaling,
    required MediaManagerFactory mediaFactory,
    required CallLogger logger,
    required CallConfig config,
    required CallErrorHandler errorHandler,
    CallAnalytics? analytics,
    NetworkQualityMonitor? networkMonitor,
    this.calleeId,
    this.callId,
  }) : _instanceId = ++_instanceCounter,
       _signaling = signaling,
       _mediaFactory = mediaFactory,
       _logger = logger,
       _config = config,
       _errorHandler = errorHandler,
       _analytics = analytics,
       _networkMonitor = networkMonitor {
    _activeInstances++;
    _logger.debug(
      'Created instance $_instanceId (active: $_activeInstances, total: $_instanceCounter)',
    );

    // Debug assertion to catch UI bugs creating multiple controllers
    assert(
      _activeInstances <= 1,
      'Multiple CallController instances detected ($_activeInstances active). '
      'This usually indicates a UI bug where previous controller was not disposed.',
    );
  }

  Future<void> connect() async {
    if (_callState != CallState.initial) {
      _logger.warning('Cannot connect from state: $_callState');
      return;
    }

    _callStartTime = DateTime.now();
    _setCallState(CallState.connecting);

    // Start ringback tone for caller (dialing sound)
    if (isCaller) {
      _startRingbackTone();
    }

    // Track call start
    final callIdForAnalytics =
        callId ?? 'outgoing-${DateTime.now().millisecondsSinceEpoch}';
    _analytics?.trackCallStart(
      callId: callIdForAnalytics,
      isVideo: isVideo,
      isCaller: isCaller,
      calleeId: calleeId,
    );

    _logger.info('Starting call connection', {
      'isCaller': isCaller,
      'isVideo': isVideo,
      'calleeId': calleeId,
      'callId': callId,
    });

    try {
      // 1. App Signaling Handshake
      _logger.debug(
        '[STEP 1/6] Starting signaling handshake (isCaller: $isCaller)',
      );
      if (isCaller) {
        if (calleeId == null) {
          throw CallStateError('initial', 'start call without calleeId');
        }
        _session = await _signaling.startCall(
          calleeId: calleeId!,
          isVideo: isVideo,
        );
      } else {
        if (callId == null) {
          throw CallStateError('initial', 'accept call without callId');
        }
        _session = await _signaling.acceptCall(callId!, isVideo: isVideo);
      }

      _logger.debug('[STEP 1/6] Signaling handshake completed');
      _logger.info('Session created', {
        'callId': _session!.callId,
      });

      // 2. Media Manager Factory
      _logger.debug('[STEP 2/5] Creating media manager');
      _mediaManager = _mediaFactory.create();
      _logger.debug('[STEP 2/5] Media manager created');

      // 3. Run signaling listeners setup AND media initialization IN PARALLEL
      // This reduces connection delay by ~500-1000ms since AudioDeviceService
      // initialization doesn't depend on signaling events
      _logger.debug('[STEP 3/5] Parallel: signaling listeners + media init');
      await Future.wait([
        Future.sync(() {
          // Setup signaling listeners BEFORE connecting media
          // This is critical so we can detect if callee rejects while we're
          // still connecting (ICE can take 60+ seconds on poor networks)
          _listenToSignalingEvents();
          _logger.debug('[STEP 3/5] Signaling listeners ready');
        }),
        _mediaManager!.initialize().then((_) {
          _logger.debug('[STEP 3/5] Media manager initialized');
        }),
      ]);
      _logger.debug('[STEP 3/5] Parallel initialization complete');

      // Check if call was rejected/ended while initializing
      if (_callState == CallState.ended || _isEndingCall) {
        _logger.info(
          'Call ended during media initialization - aborting connect',
        );
        // CRITICAL: Clean up media manager to release camera/mic
        // This handles the race condition where peer rejects while we're
        // still acquiring camera/mic permissions
        await _mediaManager?.disconnect();
        return;
      }

      // 4. Connect Media
      _logger.debug('[STEP 4/5] Connecting media (calling room.connect)');
      await _mediaManager!.connect(_session!);
      _logger.debug('[STEP 4/5] Media connected successfully');

      _logger.info('Media connected successfully');

      // Check if call was rejected/ended while connecting
      if (_callState == CallState.ended || _isEndingCall) {
        _logger.info('Call ended during media connect - aborting');
        await _mediaManager?.disconnect();
        return;
      }

      // 5. For callee (incoming call), transition to connected immediately
      //    (room.connect() + media enable succeeded, callee already accepted)
      // For caller (outgoing call), check if callee has accepted via signaling
      _logger.debug('[STEP 5/5] Final state transition');
      if (!isCaller) {
        _connectionTime = DateTime.now();
        if (_callStartTime != null && _session != null) {
          _analytics?.trackCallConnected(
            callId: _session!.callId,
            connectionTime: _connectionTime!.difference(_callStartTime!),
          );
        }
        _setCallState(CallState.connected);
        _startDurationTimer();
        _networkMonitor?.startMonitoring();
        _logger.debug(
          '[STEP 5/5] Callee - media ready, transitioned to CONNECTED',
        );
        _logger.info('Callee media + signaling ready - call connected');
      } else if (_calleeAccepted) {
        // Callee already accepted via Firestore. Media is now ready too.
        // Transition to connected since both conditions are met.
        _mediaReady = true;
        _logger.debug(
          '[STEP 5/5] Caller - callee accepted + media ready, transitioning to CONNECTED',
        );
        _logger.info('📡 Callee already accepted + media ready → connected');
        _setCallState(CallState.connected);
        _startDurationTimer();
        _networkMonitor?.startMonitoring();
      } else {
        // Caller: media is ready but callee hasn't accepted yet.
        // Wait for callee acceptance via signaling listener.
        _mediaReady = true;
        _startCallTimeoutTimer();
        _logger.debug(
          '[STEP 5/5] Caller - media ready, waiting for CALLEE ACCEPTANCE',
        );
        _logger.info('Caller media ready, waiting for callee to accept...');
      }
    } on CallError catch (e) {
      // Only ignore errors if call was explicitly ended by user
      _logger.info(
        'CallError caught - state: $_callState, disposed: $_isDisposed, ending: $_isEndingCall',
      );

      if (_callState == CallState.ended || _isDisposed || _isEndingCall) {
        _logger.info(
          'Call connection interrupted by user action - ignoring error [$hashCode]',
        );
        return;
      }

      // This is a real connection error - show it
      _logger.error('Call connection failed [$hashCode]', e, null);
      _lastError = e; // Preserve actual error
      _errorMessage = e.userMessage;
      _setCallState(CallState.failed);
      _errorHandler.handleError(e);

      // CRITICAL: Clean up media manager to ensure proper browser cleanup
      if (_mediaManager != null) {
        _logger.info('Cleaning up media manager after connection failure');
        await _mediaManager!.disconnect();
      }
    } catch (e, stackTrace) {
      // Only ignore errors if call was explicitly ended by user
      _logger.info(
        'Exception caught - state: $_callState, disposed: $_isDisposed, ending: $_isEndingCall, error: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}',
      );

      if (_callState == CallState.ended || _isDisposed || _isEndingCall) {
        _logger.info(
          'Call connection interrupted by user action - ignoring error [$hashCode]',
        );
        return;
      }

      // This is a real connection error - show it
      _logger.error(
        'Call connection failed with unexpected error [$hashCode]',
        e,
        stackTrace,
      );
      final callError = CallErrorHandler.fromException(
        e,
        stackTrace: stackTrace,
      );
      _lastError = callError; // Preserve actual error
      _errorMessage = callError.userMessage;
      _setCallState(CallState.failed);
      _errorHandler.handleError(callError);

      // CRITICAL: Clean up media manager to ensure proper browser cleanup
      if (_mediaManager != null) {
        _logger.info('Cleaning up media manager after connection failure');
        await _mediaManager!.disconnect();
      }
    }
  }

  void _listenToSignalingEvents() {
    if (_session == null) return;

    _logger.debug('Setting up listeners for session: ${_session!.callId}');
    _logger.debug('   isCaller: $isCaller');
    _logger.debug('   Current state: $_callState');

    // Start listening to Firestore updates via the service
    final firestoreSub = _signaling.listenToCallStatus(_session!.callId);
    if (firestoreSub != null) {
      _addSubscription(firestoreSub);
      _logger.debug('Firestore listener registered');
    }

    // Listen for remote end/changes via the service stream
    final callStateSub = _signaling.callStateStream.listen((status) {
      _logger.debug('Received signaling status: $status');
      _logger.debug('   isCaller: $isCaller, currentState: $_callState');
      _logger.debug(
        '📡 [CallController] Received signaling status: $status (isCaller: $isCaller, currentState: $_callState)',
      );

      if (status == CallStatus.ended || status == CallStatus.rejected) {
        _logger.debug('Remote party ended/rejected - terminating');
        _logger.info(
          '📡 [CallController] Received remote end signal - ending call',
        );
        endCall();
      } else if (status == CallStatus.connected) {
        // Handle both caller and callee transitions
        if (_callState == CallState.connecting) {
          if (isCaller) {
            // CALLER: Record that callee accepted.
            // Only transition to connected when BOTH conditions are met:
            // 1. Callee accepted (this flag)
            // 2. Media is ready (room.connect() + media enable succeeded)
            // This prevents showing "Connected" UI with no audio/video.
            _calleeAccepted = true;
            _cancelCallTimeoutTimer();
            _connectionTime = DateTime.now();
            if (_callStartTime != null && _session != null) {
              _analytics?.trackCallConnected(
                callId: _session!.callId,
                connectionTime: _connectionTime!.difference(_callStartTime!),
              );
            }
            if (_mediaReady) {
              _logger.debug(
                'CALLEE ACCEPTED + media already ready - transitioning to CONNECTED',
              );
              _logger.info(
                '📡 [CallController] ✅ Callee accepted + media ready → connected',
              );
              _setCallState(CallState.connected);
              _startDurationTimer();
              _networkMonitor?.startMonitoring();
            } else {
              _logger.debug(
                'CALLEE ACCEPTED but media not ready - deferring transition to Step 5',
              );
              _logger.info(
                '📡 [CallController] ⏳ Callee accepted, waiting for media...',
              );
            }
          } else {
            // Callee: Firestore confirms call is active. This is expected since
            // WE accepted the call. Don't transition here — Step 5 handles the
            // callee transition AFTER room.connect() + media enable succeeds,
            // ensuring the user only sees "Connected" when media actually flows.
            _logger.debug(
              'CALLEE - Firestore confirms active call (no-op, Step 5 handles transition)',
            );
            _logger.info(
              '📡 [CallController] ℹ️ Callee Firestore sync (media not ready yet)',
            );
          }
        } else {
          _logger.debug(
            '📡 [CallController] ⏭️  Skipping state transition - isCaller: $isCaller, state: $_callState',
          );
        }
      }
    });
    _addSubscription(callStateSub);

    // Listen to media manager state changes - handle reconnection/disconnection
    _mediaConnectedListener = () {
      if (_isDisposed || _isEndingCall) return;

      final isConnected = _mediaManager!.isConnected.value;

      if (!isConnected && _callState == CallState.connected) {
        // Media disconnected while we thought we were connected
        _logger.warning(
          'Media disconnected unexpectedly - transitioning to reconnecting',
        );
        _logger.debug('Media disconnected - entering reconnecting state');
        _setCallState(CallState.reconnecting);
      } else if (isConnected && _callState == CallState.reconnecting) {
        // Media reconnected
        _logger.info('Media reconnected successfully');
        _logger.debug('Media reconnected');
        _setCallState(CallState.connected);
      }
    };
    _mediaManager?.isConnected.addListener(_mediaConnectedListener!);

    // Subscribe to LiveKit-specific streams
    _subscribeToLiveKitStreams();
  }

  /// Subscribe to LiveKit quality, end reason, and track status streams
  void _subscribeToLiveKitStreams() {
    // Call quality updates
    final qualityStream = _mediaManager?.callQualityStream;
    if (qualityStream != null) {
      final sub = qualityStream.listen((stats) {
        final previousQuality = _currentQuality?.quality;
        _currentQuality = stats;
        // Only notify listeners when quality level actually changes
        if (stats.quality != previousQuality) {
          if (stats.quality == CallQualityLevel.poor) {
            _logger.debug('Poor call quality detected');
            _logger.warning('Call quality degraded', {
              'quality': stats.quality.name,
            });
          }
          notifyListeners();
        }
      });
      _addSubscription(sub);
      _logger.debug('Call quality stream subscribed');
    }

    // Call end reason (auto-disconnect due to timeout, remote left, etc.)
    final endReasonStream = _mediaManager?.callEndReasonStream;
    if (endReasonStream != null) {
      final sub = endReasonStream.listen((reason) {
        _logger.debug('Call end reason: $reason');
        _lastEndReason = reason;
        _logger.info('Call ended by LiveKit', {'reason': reason.name});

        // Show user-friendly message based on reason
        switch (reason) {
          case CallEndReason.timeout:
            SnackbarService.show('Call timed out - no answer');
            break;
          case CallEndReason.remoteLeft:
            SnackbarService.show('Other party left the call');
            break;
          case CallEndReason.error:
            SnackbarService.show('Call ended due to an error');
            break;
          case CallEndReason.connectionFailure:
            SnackbarService.show('Connection lost - please try again');
            break;
          case CallEndReason.normal:
            // No message needed for normal disconnect
            break;
        }

        // Trigger end call if not already ending
        if (!_isEndingCall && _callState != CallState.ended) {
          endCall();
        }
      });
      _addSubscription(sub);
      _logger.debug('Call end reason stream subscribed');
    }

    // Remote track status (mute/unmute notifications)
    final trackStatusStream = _mediaManager?.remoteTrackStatusStream;
    if (trackStatusStream != null) {
      bool? lastVideoMuted;
      bool? lastAudioMuted;
      final sub = trackStatusStream.listen((status) {
        _logger.debug(
          'Remote track status: video=${status.videoMuted ? "off" : "on"}, audio=${status.audioMuted ? "muted" : "on"}',
        );
        // Only notify UI when track status actually changes
        if (status.videoMuted != lastVideoMuted || status.audioMuted != lastAudioMuted) {
          lastVideoMuted = status.videoMuted;
          lastAudioMuted = status.audioMuted;
          notifyListeners();
        }
      });
      _addSubscription(sub);
      _logger.debug('Remote track status stream subscribed');
    }
  }

  /// User Actions
  Future<void> toggleMute() async {
    try {
      await _mediaManager?.toggleMute();
      if (_session != null) {
        _analytics?.trackUserAction(
          callId: _session!.callId,
          action: isMuted
              ? CallAnalyticsEvent.audioMuted
              : CallAnalyticsEvent.audioUnmuted,
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to toggle mute', e, stackTrace);
    }
  }

  Future<void> toggleVideo() async {
    try {
      await _mediaManager?.toggleVideo();
      if (_session != null) {
        _analytics?.trackUserAction(
          callId: _session!.callId,
          action: isVideoEnabled
              ? CallAnalyticsEvent.videoEnabled
              : CallAnalyticsEvent.videoDisabled,
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to toggle video', e, stackTrace);
    }
  }

  Future<void> switchCamera() async {
    try {
      await _mediaManager?.switchCamera();
      if (_session != null) {
        _analytics?.trackUserAction(
          callId: _session!.callId,
          action: CallAnalyticsEvent.cameraSwitch,
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to switch camera', e, stackTrace);
    }
  }

  Future<void> toggleSpeaker() async {
    try {
      await _mediaManager?.toggleSpeaker();
      if (_session != null) {
        _analytics?.trackUserAction(
          callId: _session!.callId,
          action: CallAnalyticsEvent.speakerToggled,
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to toggle speaker', e, stackTrace);
    }
  }

  Future<void> endCall() async {
    // Guard against duplicate calls
    if (_isEndingCall || _callState == CallState.ended || _isDisposed) return;

    // Set flag to suppress errors that occur during call termination
    _isEndingCall = true;

    // Cancel timeout timer immediately
    _cancelCallTimeoutTimer();

    _logger.info(
      'Ending call - state: $_callState, isCaller: $isCaller, callId: ${_session?.callId}',
    );

    // Track call end analytics
    if (_session != null && _callStartTime != null) {
      _analytics?.trackCallEnd(
        callId: _session!.callId,
        callDuration: DateTime.now().difference(_callStartTime!),
        endReason: 'user_ended',
      );
    }

    _setCallState(CallState.ended);
    _cancelAllTimers();
    _networkMonitor?.stopMonitoring();

    try {
      // Call endCall FIRST to trigger server-side participant cleanup
      // This gives the server time to clean up while we do client cleanup
      // Without this, the next call may fail with ICE timeout because
      // the server still has the old participant session active
      if (_session != null) {
        _logger.info(
          '📞 [CallController] Calling signaling.endCall for room: ${_session!.callId}',
        );
        // Don't await - let it run in parallel with client cleanup
        _signaling
            .endCall(_session!.callId)
            .then((_) {
              _logger.info('📞 [CallController] signaling.endCall completed');
            })
            .catchError((e) {
              _logger.warning(
                '📞 [CallController] signaling.endCall error: $e',
              );
            });
      }

      // Now disconnect the media (this includes browser cleanup delays)
      await _mediaManager?.disconnect();

      // Report call end to CallKit (iOS only)
      try {
        final callKit = CallKitService();
        _logger.debug(
          'CallKit check - isAvailable: ${callKit.isAvailable}, hasActiveCall: ${callKit.hasActiveCall}, activeCallUUID: ${callKit.activeCallUUID}',
        );
        if (callKit.isAvailable && callKit.hasActiveCall) {
          _logger.info(
            '📞 [CallController] Reporting call end to CallKit with UUID: ${callKit.activeCallUUID}',
          );
          await callKit.endCall();
          _logger.debug('CallKit endCall completed');
        } else if (callKit.isAvailable) {
          // Try to end call anyway - native side will use its active UUID
          _logger.debug('No active call UUID, attempting endCall anyway');
          await callKit.endCall();
        }
      } catch (e, _) {
        _logger.warning('Failed to report call end to CallKit: $e');
      }
    } catch (e, stackTrace) {
      _logger.error('Error ending call', e, stackTrace);
    }
  }

  void _startDurationTimer() {
    // Guard: Prevent creating multiple duration timers
    // This can happen when both callee connection path and signaling listener
    // trigger state transitions to connected
    if (_durationTimer != null && _durationTimer!.isActive) {
      _logger.debug('Duration timer already running - skipping');
      return;
    }

    _durationTimer = _createTimer(
      const Duration(seconds: 1),
      periodic: true,
      callback: () {
        _durationSeconds.value++;
        // No notifyListeners() needed - ValueNotifier handles its own notifications
      },
    );
    _logger.debug('Duration timer started');
  }

  void _startCallTimeoutTimer() {
    // Cancel any existing timeout timer first
    _cancelCallTimeoutTimer();

    _callTimeoutTimer = Timer(_config.callTimeout, () {
      if (_callState == CallState.connecting && !_isEndingCall) {
        _logger.warning('Call timeout - callee did not answer');
        final error = CallTimeoutError(_config.callTimeout);
        _lastError = error;
        _errorMessage = error.userMessage;
        endCall();
        SnackbarService.show(error.userMessage);
      }
    });
    _logger.debug(
      'Call timeout timer started: ${_config.callTimeout.inSeconds}s',
    );
  }

  void _cancelCallTimeoutTimer() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  void _cancelAllTimers() {
    // Cancel duration timer explicitly
    _durationTimer?.cancel();
    _durationTimer = null;

    for (final timer in _timers) {
      try {
        timer.cancel();
      } catch (e, _) {
        _logger.warning('Error cancelling timer: $e');
      }
    }
    _timers.clear();
  }

  void _setCallState(CallState state) {
    if (_isDisposed) return;
    final oldState = _callState;
    _callState = state;
    _logger.debug('State transition: $oldState → $state');
    _logger.debug('State changed to: $state');

    // Stop ringback tone when call connects or ends (for caller)
    if (isCaller &&
        (state == CallState.connected ||
            state == CallState.ended ||
            state == CallState.failed)) {
      _stopRingbackTone();
    }

    // Track specific state transitions
    if (state == CallState.failed && _session != null) {
      _analytics?.trackCallFailed(
        callId: _session!.callId,
        errorType: error.runtimeType.toString(),
        errorMessage: _errorMessage ?? 'Unknown error',
        attemptDuration: _callStartTime != null
            ? DateTime.now().difference(_callStartTime!)
            : null,
      );
    }

    notifyListeners();
  }

  /// Start ringback tone for caller (dialing sound)
  void _startRingbackTone() {
    try {
      RingtoneService().startRingtone();
      _logger.debug('Ringback tone started');
    } catch (e, _) {
      _logger.warning('Failed to start ringback tone: $e');
    }
  }

  /// Stop ringback tone
  void _stopRingbackTone() {
    try {
      RingtoneService().stopRingtone();
      _logger.debug('Ringback tone stopped');
    } catch (e, _) {
      _logger.warning('Failed to stop ringback tone: $e');
    }
  }

  void _addSubscription(StreamSubscription sub) {
    _subscriptions.add(sub);
  }

  Timer _createTimer(
    Duration duration, {
    required VoidCallback callback,
    bool periodic = false,
  }) {
    late final Timer timer;
    if (periodic) {
      timer = Timer.periodic(duration, (_) => callback());
    } else {
      timer = Timer(duration, callback);
    }
    _timers.add(timer);
    return timer;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _activeInstances--;

    _logger.debug(
      'Disposing instance $_instanceId (active: $_activeInstances)',
    );
    _logger.info('Disposing CallController');

    // Remove media listener first
    if (_mediaConnectedListener != null) {
      try {
        _mediaManager?.isConnected.removeListener(_mediaConnectedListener!);
        _mediaConnectedListener = null;
      } catch (e, _) {
        _logger.warning('Error removing media listener during dispose', {
          'error': e.toString(),
        });
      }
    }

    // Cancel timeout timer explicitly
    _cancelCallTimeoutTimer();

    // Cancel all timers first (prevents callbacks during disposal)
    for (final timer in _timers) {
      try {
        timer.cancel();
      } catch (e, _) {
        _logger.warning('Error cancelling timer during dispose', {
          'error': e.toString(),
        });
      }
    }
    _timers.clear();

    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      try {
        sub.cancel();
      } catch (e, _) {
        _logger.warning('Error cancelling subscription during dispose', {
          'error': e.toString(),
        });
      }
    }
    _subscriptions.clear();

    // Dispose dependencies in reverse order of creation.
    // MediaManager.dispose() is async but ChangeNotifier.dispose() is sync,
    // so we fire-and-forget.  This is safe because:
    // 1. endCall() already awaited _mediaManager.disconnect() in the normal path.
    // 2. LiveKitService uses a STATIC _isCleaningUp flag, so even if this
    //    background cleanup is still running when a new call starts, the new
    //    call's connect() will wait for it.
    _mediaManager?.dispose().catchError((e) {
      _logger.error('Error disposing media manager', e, null);
    });

    // Dispose ValueNotifier
    _durationSeconds.dispose();

    super.dispose();
  }
}
