import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:securityexperts_app/features/chat/services/audio_recording_manager.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';

/// Handles recording UI logic (permission checks, snackbars)
class ChatRecordingHandler {
  final AudioRecordingManager _audioRecordingManager;
  final Future<void> Function(File audioFile) onRecordingComplete;

  ChatRecordingHandler({
    required AudioRecordingManager audioRecordingManager,
    required this.onRecordingComplete,
  }) : _audioRecordingManager = audioRecordingManager;

  /// Start recording with permission check and UI feedback
  Future<void> startRecording() async {
    if (kIsWeb) {
      SnackbarService.show('Audio recording is not supported on web');
      return;
    }

    await ErrorHandler.handle<void>(
      operation: () async {
        // Request microphone permission
        final micPermission = await Permission.microphone.request();

        if (micPermission.isDenied) {
          SnackbarService.show(
            'Microphone permission is required for recording',
          );
          return;
        }

        await _audioRecordingManager.startRecording();
      },
      fallback: null,
      onError: (error) {
        SnackbarService.show('Failed to start recording');
      },
    );
  }

  /// Stop recording and send audio message
  Future<void> stopRecording() async {
    final audioFile = await ErrorHandler.handle<File?>(
      operation: () async {
        return await _audioRecordingManager.stopRecording();
      },
      fallback: null,
      onError: (error) {
        SnackbarService.show('Failed to stop recording');
      },
    );

    if (audioFile != null) {
      await onRecordingComplete(audioFile);
    } else {
      SnackbarService.show('Failed to save audio recording');
    }
  }

  /// Stop recording for preview without sending
  Future<File?> stopRecordingForPreview() async {
    final audioFile = await ErrorHandler.handle<File?>(
      operation: () async {
        return await _audioRecordingManager.stopRecording();
      },
      fallback: null,
      onError: (error) {
        SnackbarService.show('Failed to stop recording');
      },
    );
    
    return audioFile;
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _audioRecordingManager.pauseRecording();
      },
      fallback: null,
    );
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _audioRecordingManager.resumeRecording();
      },
      fallback: null,
    );
  }

  /// Cancel recording and discard the file
  Future<void> cancelRecording() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _audioRecordingManager.cancelRecording();
      },
      fallback: null,
    );
  }
}
