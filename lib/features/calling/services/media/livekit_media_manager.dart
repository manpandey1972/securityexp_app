import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:greenhive_app/data/models/call_session.dart';
import 'package:greenhive_app/core/config/livekit_config.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/themes/app_icon_sizes.dart';
import 'package:greenhive_app/features/calling/services/interfaces/room_service.dart';
import 'package:greenhive_app/features/calling/services/audio_device_service.dart';
import 'media_manager.dart';

/// LiveKit implementation of MediaManager
///
/// Uses dependency injection for RoomService and AudioDeviceService
class LiveKitMediaManager extends MediaManager {
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'LiveKitMediaManager';
  
  final RoomService _service;
  final AudioDeviceService _audioService;

  LiveKitMediaManager({
    required RoomService roomService,
    required AudioDeviceService audioService,
  }) : _service = roomService,
       _audioService = audioService;

  @override
  late final ValueNotifier<bool> isConnected = ValueNotifier(false);
  @override
  late final ValueNotifier<bool> isMuted = ValueNotifier(false);
  @override
  late final ValueNotifier<bool> isVideoEnabled = ValueNotifier(true);
  @override
  late final ValueNotifier<bool> isRemoteVideoEnabled = ValueNotifier(true);
  late final ValueNotifier<bool> _isRemoteAudioMuted = ValueNotifier(false);
  @override
  late final ValueNotifier<bool> isSpeakerOn = ValueNotifier(true);
  @override
  late final ValueNotifier<String> selectedAudioOutput = ValueNotifier(
    'speaker',
  );

  // Track when remote stream is first available (for UI "Connecting..." state)
  late final ValueNotifier<bool> _hasRemoteStream = ValueNotifier(false);
  @override
  ValueNotifier<bool>? get hasRemoteStream => _hasRemoteStream;

  // Flag to track if quality monitoring has been started (for lazy start)
  bool _qualityMonitoringStarted = false;

  // Expose remote audio mute state
  @override
  ValueNotifier<bool>? get isRemoteAudioMuted => _isRemoteAudioMuted;

  // Expose LiveKit-specific streams
  @override
  Stream<CallEndReason>? get callEndReasonStream =>
      _service.callEndReasonStream;

  @override
  Stream<CallQualityStats>? get callQualityStream => _service.callQualityStream;

  @override
  Stream<RemoteTrackStatus>? get remoteTrackStatusStream =>
      _service.remoteTrackStatusStream;

  @override
  CallQualityStats? get currentCallQuality => _service.currentCallQuality;

  bool _initialized = false;
  bool _isFrontCamera = true;
  bool _isDisposed = false;

  // Subscriptions
  StreamSubscription? _connectionStateSub;
  StreamSubscription? _audioDeviceSub;
  StreamSubscription? _participantsSub;

  @override
  Future<void> initialize() async {
    if (_initialized || _isDisposed) return;

    _setupListeners();
    await _audioService.initialize();

    // Guard: check if disposed during async initialization
    if (_isDisposed) return;

    _initialized = true;
  }

  void _setupListeners() {
    _connectionStateSub = _service.connectionStateStream.listen((connected) {
      if (!_isDisposed) {
        isConnected.value = connected;
      }
    });

    _audioDeviceSub = _audioService.onDeviceChanged.listen((device) {
      if (_isDisposed) return;
      final isSpeaker = device == AudioDevice.speaker;
      if (isSpeakerOn.value != isSpeaker) {
        isSpeakerOn.value = isSpeaker;
      }
      selectedAudioOutput.value = device.toString().split('.').last;
    });

    // Listen for remote participant audio and video state changes
    _participantsSub = _service.participantsStream.listen((participants) {
      if (_isDisposed) return;

      // Track when remote stream first becomes available
      final hasRemoteNow = participants.isNotEmpty;
      if (!_hasRemoteStream.value && hasRemoteNow) {
        _log.info('Remote stream first available', tag: _tag);
        _hasRemoteStream.value = true;

        // LAZY QUALITY MONITORING: Start quality monitoring only after
        // remote participant joins - reduces unnecessary CPU/network load
        // during connection setup
        if (!_qualityMonitoringStarted) {
          _log.info('Starting quality monitoring (lazy)', tag: _tag);
          _qualityMonitoringStarted = true;
          _service.startQualityMonitoring();
        }
      }

      if (participants.isEmpty) return;

      final remoteParticipant = participants.first;
      bool hasEnabledVideo = false;
      bool? isAudioMuted; // null means no track found yet

      // Check video state
      for (var pub in remoteParticipant.videoTrackPublications) {
        if (pub.subscribed && pub.track != null && !pub.muted) {
          hasEnabledVideo = true;
          break;
        }
      }

      // Check audio mute state
      for (var pub in remoteParticipant.audioTrackPublications) {
        if (pub.subscribed && pub.track != null) {
          isAudioMuted = pub.muted;
          break;
        }
      }

      // Only update if we actually found an audio track
      // This prevents false positives when tracks aren't subscribed yet
      if (isAudioMuted != null && !_isDisposed) {
        if (_isRemoteAudioMuted.value != isAudioMuted) {
          _log.debug('Remote audio muted state changed', tag: _tag, data: {'muted': isAudioMuted});
          _isRemoteAudioMuted.value = isAudioMuted;
        }
      }

      if (!_isDisposed && isRemoteVideoEnabled.value != hasEnabledVideo) {
        _log.debug('Remote video enabled state changed', tag: _tag, data: {'enabled': hasEnabledVideo});
        isRemoteVideoEnabled.value = hasEnabledVideo;
      }
    });
  }

  @override
  Future<void> connect(CallSession session) async {
    if (session.token == null) {
      throw Exception('LiveKit token is required');
    }

    // Set initial video state based on call type (audio vs video call)
    isVideoEnabled.value = session.isVideo;

    try {
      await _service.connect(
        url: LiveKitConfig.liveKitServerUrl,
        token: session.token!,
        enableVideo: session.isVideo,
        enableAudio: true,
      );

      // Guard: check if disposed during async connect
      if (_isDisposed) return;

      // WEB FIX: Restart local tracks after connect for new PeerConnection
      // On Web, tracks need to be restarted after a new connect to work properly
      // OPTIMIZATION: Skip this on native platforms (iOS/Android) where tracks work immediately
      // This reduces audio delay from 10-15s to near-instant on mobile
      if (kIsWeb) {
        // Guard: check connection state before restarting tracks
        if (!_service.isConnected) {
          _log.warning('Room not connected, skipping track restart', tag: _tag);
          return;
        }

        final localParticipant = _service.localParticipant;
        if (localParticipant != null) {
          // Wrap track restart in error-suppressing zone
          // This catches late async errors from LiveKit SDK's internal replaceTrack calls
          // which can fail if peer connection closes during the operation
          await _restartTracksWithErrorSuppression(localParticipant, session.isVideo);
        }
      } else {
        _log.debug('Native platform - skipping track restart (not needed)', tag: _tag);
      }

      // Guard: check if disconnected during track restart
      if (_isDisposed || !_service.isConnected) {
        _log.warning('Disconnected during track restart, skipping further setup', tag: _tag);
        return;
      }

      // Note: isConnected is updated via connectionStateStream listener (single source of truth)
      isVideoEnabled.value = session.isVideo;
      isMuted.value = false;

      // Note: Quality monitoring is started lazily when remote participant joins
      // (see _setupListeners -> participantsStream listener)
    } catch (e) {
      _log.error('Connect failed', tag: _tag, error: e);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _log.debug('disconnect() START', tag: _tag);

    try {
      // Always attempt to disconnect the underlying service, even if we are
      // mid-dispose.  _service.disconnect() has its own idempotency guards
      // (_room == null, _isCleaningUp) so calling it twice is safe.
      await _service.disconnect();
    } catch (e) {
      _log.error('Error during disconnect', tag: _tag, error: e);
    }

    // Reset state for potential reuse (important for Web reconnection)
    // Only update ValueNotifiers if we haven't been disposed, to avoid
    // "A ValueNotifier was used after being disposed" errors.
    if (!_isDisposed) {
      isConnected.value = false;
      isMuted.value = false;
      isVideoEnabled.value = true;
      isRemoteVideoEnabled.value = true;
      _isRemoteAudioMuted.value = false;
      _hasRemoteStream.value = false;
      _qualityMonitoringStarted = false;
      _isFrontCamera = true;
      _initialized = false; // Reset so initialize() can run again for next call
    }

    _log.debug('disconnect() COMPLETE', tag: _tag);
  }

  @override
  Future<void> toggleMute() async {
    final newState = !isMuted.value;
    try {
      await _service.setMicrophoneEnabled(!newState); // enabled = !muted
      if (!_isDisposed) {
        isMuted.value = newState;
      }
    } catch (e) {
      _log.error('Mic unavailable or permission revoked', tag: _tag, error: e);
    }
  }

  @override
  Future<void> toggleVideo() async {
    final newState = !isVideoEnabled.value;
    try {
      await _service.setCameraEnabled(newState);
      if (!_isDisposed) {
        isVideoEnabled.value = newState;
      }
    } catch (e) {
      _log.error('Camera unavailable or permission revoked', tag: _tag, error: e);
    }
  }

  @override
  Future<void> switchCamera() async {
    final participant = _service.localParticipant;
    if (participant != null) {
      for (var publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track is LocalVideoTrack) {
          try {
            _isFrontCamera = !_isFrontCamera;
            final newPosition = _isFrontCamera
                ? CameraPosition.front
                : CameraPosition.back;

            // Use CameraCaptureOptions to specify the new camera position
            // Using startVideoTrack logic from LiveKit usually
            await track.restartTrack(
              CameraCaptureOptions(cameraPosition: newPosition),
            );
          } catch (e) {
            _log.error('Failed to switch camera', tag: _tag, error: e);
            // Revert state if failed
            _isFrontCamera = !_isFrontCamera;
          }
        }
      }
    }
  }

  @override
  Future<void> toggleSpeaker() async {
    // Determine target state
    final targetDevice = isSpeakerOn.value
        ? AudioDevice.earpiece
        : AudioDevice.speaker;

    // Use AudioDeviceService to switch
    if (targetDevice == AudioDevice.speaker) {
      await _audioService.setSpeakerphoneOn(true);
    } else {
      await _audioService.setSpeakerphoneOn(false);
    }

    // Note: The listener updates the value, but we can optimistically update too
  }

  @override
  Future<void> setAudioOutput(String output) async {
    // Map string to AudioDevice enum if needed
  }

  @override
  Widget buildLocalPreview({bool mirror = true, BoxFit fit = BoxFit.cover}) {
    // We need to listen to local stream updates
    return StreamBuilder<LocalParticipant?>(
      stream: _service.localStreamStream,
      initialData: _service.localParticipant,
      builder: (context, snapshot) {
        final participant = snapshot.data;

        if (participant == null) {
          return const Center(
            child: Icon(Icons.videocam_off, color: AppColors.textPrimary),
          );
        }

        // Base on actual track presence, not just the flag
        // This prevents showing blank spinner when track isn't published yet
        final hasCameraTrack = participant.videoTrackPublications.any(
          (p) => p.track != null,
        );

        if (!hasCameraTrack || (_isDisposed ? true : !isVideoEnabled.value)) {
          return const Center(
            child: Icon(Icons.videocam_off, color: AppColors.textPrimary),
          );
        }

        // Find the video track
        VideoTrack? videoTrack;
        if (participant.videoTrackPublications.isNotEmpty) {
          // Ideally check for source == camera
          videoTrack =
              participant.videoTrackPublications.first.track as VideoTrack?;
        }

        if (videoTrack == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return VideoTrackRenderer(
          videoTrack,
          fit: fit == BoxFit.cover ? VideoViewFit.cover : VideoViewFit.contain,
        );
      },
    );
  }

  @override
  Widget buildRemoteVideo({
    bool mirror = false,
    BoxFit fit = BoxFit.cover,
    String? placeholderName,
  }) {
    return StreamBuilder<List<RemoteParticipant>>(
      stream: _service.participantsStream,
      initialData: _service.remoteParticipants,
      builder: (context, snapshot) {
        final participants = snapshot.data ?? [];
        _log.verbose('Participants count', tag: _tag, data: {'count': participants.length});

        if (participants.isEmpty) {
          return Center(
            child: Text(
              placeholderName != null
                  ? 'Waiting for $placeholderName...'
                  : 'Waiting for remote video...',
              style: AppTypography.bodyRegular,
            ),
          );
        }

        // Select the first participant with a subscribed video track
        // This handles reconnect reordering and participants without video
        final remoteParticipant = participants.firstWhere(
          (p) => p.videoTrackPublications.any(
            (pub) => pub.subscribed && pub.track != null,
          ),
          orElse: () => participants.first,
        );
        _log.verbose('Remote participant', tag: _tag, data: {
          'identity': remoteParticipant.identity,
          'videoPubs': remoteParticipant.videoTrackPublications.length,
          'audioPubs': remoteParticipant.audioTrackPublications.length
        });

        // Find video track
        VideoTrack? videoTrack;
        bool isTrackMuted = false;
        // Check subscriptions
        for (var pub in remoteParticipant.videoTrackPublications) {
          _log.verbose('Video publication', tag: _tag, data: {
            'sid': pub.sid,
            'subscribed': pub.subscribed,
            'muted': pub.muted,
            'track': pub.track != null ? 'EXISTS' : 'NULL'
          });
          if (pub.subscribed && pub.track != null) {
            videoTrack = pub.track as VideoTrack?;
            isTrackMuted = pub.muted;
            break;
          }
        }

        // Show placeholder if no track or track is muted
        if (videoTrack == null || isTrackMuted) {
          _log.verbose('Showing placeholder', tag: _tag, data: {
            'videoTrack': videoTrack != null ? 'EXISTS' : 'NULL',
            'muted': isTrackMuted
          });
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person,
                  size: AppIconSizes.hero,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  placeholderName ?? remoteParticipant.name,
                  style: AppTypography.bodyRegular,
                ),
              ],
            ),
          );
        }

        _log.verbose('Rendering video track', tag: _tag, data: {'sid': videoTrack.sid});
        return VideoTrackRenderer(
          videoTrack,
          fit: fit == BoxFit.cover ? VideoViewFit.cover : VideoViewFit.contain,
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _log.debug('dispose()', tag: _tag);

    // Cancel all subscriptions to prevent memory leaks
    await _connectionStateSub?.cancel();
    await _audioDeviceSub?.cancel();
    await _participantsSub?.cancel();

    // Disconnect from the service, which handles its own internal cleanup
    await disconnect();

    // Dispose all ValueNotifiers
    isConnected.dispose();
    isMuted.dispose();
    isVideoEnabled.dispose();
    isRemoteVideoEnabled.dispose();
    _isRemoteAudioMuted.dispose();
    isSpeakerOn.dispose();
    selectedAudioOutput.dispose();
    _hasRemoteStream.dispose();

    super.dispose();
  }

  // =========================================================================
  // WEB-SPECIFIC HELPERS
  // =========================================================================

  /// Restarts local tracks with error suppression.
  ///
  /// On Web, late async errors from LiveKit's internal `replaceTrack` can
  /// occur if the peer connection closes during the operation. This wraps
  /// the restart in a zone that catches and logs these non-critical errors.
  /// Restarts local tracks after web PeerConnection setup.
  ///
  /// IMPORTANT: Uses try-catch per track rather than runZonedGuarded.
  /// runZonedGuarded intercepts Future rejections from the inner async body,
  /// causing the outer `await` to hang forever when tracks fail to start
  /// (e.g., getUserMedia denied). try-catch allows the method to complete
  /// so connect() can return and the call state machine progresses.
  Future<void> _restartTracksWithErrorSuppression(
    LocalParticipant participant,
    bool enableVideo,
  ) async {
    _log.debug('Restarting local tracks for Web...', tag: _tag);

    // Restart audio track
    try {
      await participant.setMicrophoneEnabled(true);
      _log.debug('Audio track restarted', tag: _tag);
    } catch (e) {
      _log.warning(
        'Failed to restart audio track (non-critical): $e',
        tag: _tag,
      );
    }

    // Restart video track if it's a video call
    if (enableVideo) {
      try {
        await participant.setCameraEnabled(true);
        _log.debug('Video track restarted', tag: _tag);
      } catch (e) {
        _log.warning(
          'Failed to restart video track (non-critical): $e',
          tag: _tag,
        );
      }
    }
  }

}
