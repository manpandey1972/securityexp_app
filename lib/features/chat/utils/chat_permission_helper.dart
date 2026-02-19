import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Helper class for handling chat-related permissions
class ChatPermissionHelper {
  /// Request microphone permission for audio recording
  static Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) {
      SnackbarService.show('Audio recording is not supported on web');
      return false;
    }

    try {
      final micPermission = await Permission.microphone.request();

      if (micPermission.isDenied) {
        SnackbarService.show('Microphone permission is required for recording');
        return false;
      }

      return micPermission.isGranted;
    } catch (e, stackTrace) {
      sl<AppLogger>().error('Failed to request permission', tag: 'ChatPermissionHelper', error: e, stackTrace: stackTrace);
      SnackbarService.show('Failed to request permission: $e');
      return false;
    }
  }

  /// Check if microphone permission is granted
  static Future<bool> isMicrophonePermissionGranted() async {
    if (kIsWeb) return false;

    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e, stackTrace) {
      sl<AppLogger>().error('Error checking permission', tag: 'ChatPermissionHelper', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
