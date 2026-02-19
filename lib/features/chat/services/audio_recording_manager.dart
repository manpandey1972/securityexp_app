import 'dart:io';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';

typedef OnRecordingStateChanged = void Function(bool isRecording);
typedef OnRecordingDurationChanged = void Function(Duration duration);
typedef OnError = void Function(String error);

class AudioRecordingManager {
  final AudioRecorder _recordService = AudioRecorder();
  final OnRecordingStateChanged? onRecordingStateChanged;
  final OnRecordingDurationChanged? onRecordingDurationChanged;
  final OnError? onError;
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'AudioRecordingMgr';
  bool _isRecording = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  String? _recordingPath;

  bool get isRecording => _isRecording;

  Duration get recordingDuration => _recordingDuration;

  String? get recordingPath => _recordingPath;

  AudioRecordingManager({
    this.onRecordingStateChanged,
    this.onRecordingDurationChanged,
    this.onError,
  });

  /// Request microphone permission
  /// NOTE: Use .request() directly to ensure iOS shows the permission dialog
  Future<bool> requestMicrophonePermission() async {
    return ErrorHandler.handle(
      operation: () async {
        _log.debug('Requesting microphone permission...', tag: _tag);

        // Request directly - do NOT check status first
        // Checking status can cause iOS to cache the decision prematurely
        final status = await Permission.microphone.request();
        _log.debug('Permission request result: $status', tag: _tag);

        if (status.isDenied) {
          onError?.call('Microphone permission denied');
          return false;
        } else if (status.isPermanentlyDenied) {
          onError?.call(
            'Microphone permission permanently denied. Open app settings to enable it.',
          );
          return false;
        }

        return status.isGranted;
      },
      fallback: false,
      onError: (error) =>
          onError?.call('Error requesting microphone permission: $error'),
    );
  }

  /// Check if microphone permission is granted
  Future<bool> isMicrophonePermissionGranted() async {
    return ErrorHandler.handle(
      operation: () async {
        final status = await Permission.microphone.status;
        return status.isGranted;
      },
      fallback: false,
      onError: (error) =>
          onError?.call('Error checking microphone permission: $error'),
    );
  }

  /// Start recording audio
  /// Assumes microphone permission has already been requested by the caller
  Future<void> startRecording() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        _log.debug('startRecording() called', tag: _tag);

        // Check if already recording
        if (await _recordService.isRecording()) {
          _log.warning('Already recording, aborting', tag: _tag);
          return;
        }

        _log.debug('Getting temporary directory', tag: _tag);

        // Use temp directory for recording (cleaned up after upload)
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final recordingFile = File(
          '${tempDir.path}/recording_$timestamp.m4a',
        );

        _log.debug('Recording to: ${recordingFile.path}', tag: _tag);

        // Start recording with RecordConfig - use higher bitrate for better quality
        _log.debug('Starting record service', tag: _tag);
        await _recordService.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 256000, // High bitrate for better audio quality
            sampleRate: 44100,
            numChannels: 1, // Mono is sufficient for voice
            autoGain: true, // Enable automatic gain control for better volume
            echoCancel: true, // Enable echo cancellation
            noiseSuppress: true, // Enable noise suppression
          ),
          path: recordingFile.path,
        );

        _isRecording = true;
        _recordingPath = recordingFile.path;
        _recordingDuration = Duration.zero;

        _log.info('Recording started successfully', tag: _tag);
        onRecordingStateChanged?.call(true);

        // Start timer to track duration
        _startRecordingTimer();
      },
      onError: (error) {
        _isRecording = false;
        onError?.call('Error starting recording: $error');
      },
    );
  }

  /// Stop recording and return the file
  Future<File?> stopRecording() async {
    return ErrorHandler.handle<File?>(
      operation: () async {
        if (!_isRecording) {
          return null;
        }

        final path = await _recordService.stop();

        _recordingTimer?.cancel();
        _isRecording = false;
        _recordingDuration = Duration.zero;

        onRecordingStateChanged?.call(false);
        onRecordingDurationChanged?.call(Duration.zero);

        if (path != null) {
          return File(path);
        }

        return null;
      },
      fallback: null,
      onError: (error) {
        _isRecording = false;
        onError?.call('Error stopping recording: $error');
      },
    );
  }

  /// Cancel recording and discard the file
  Future<void> cancelRecording() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        if (!_isRecording) return;

        await _recordService.stop();

        // Delete the recording file
        if (_recordingPath != null) {
          final file = File(_recordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }

        _recordingTimer?.cancel();
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = Duration.zero;

        onRecordingStateChanged?.call(false);
        onRecordingDurationChanged?.call(Duration.zero);
      },
      onError: (error) => onError?.call('Error cancelling recording: $error'),
    );
  }

  /// Pause recording (if supported by platform)
  Future<void> pauseRecording() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        if (!_isRecording) return;

        await _recordService.pause();
        _recordingTimer?.cancel();
      },
      onError: (error) => onError?.call('Error pausing recording: $error'),
    );
  }

  /// Resume recording (if it was paused)
  Future<void> resumeRecording() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        if (!_isRecording) return;

        await _recordService.resume();
        _startRecordingTimer();
      },
      onError: (error) => onError?.call('Error resuming recording: $error'),
    );
  }

  /// Get recording duration as formatted string
  String getFormattedDuration() {
    final minutes = _recordingDuration.inMinutes;
    final seconds = _recordingDuration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Private method to start recording timer
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
      onRecordingDurationChanged?.call(_recordingDuration);
    });
  }

  /// Dispose resources
  void dispose() {
    _recordingTimer?.cancel();
    if (_isRecording) {
      _recordService.stop();
    }
    _recordService.dispose();
  }
}
