import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Chat-related constants
class ChatConstants {
  // Pagination
  static const int pageSize = 50;
  static const int mediaCacheLimit = 100;

  // Animation durations
  static const Duration scrollAnimationDuration = Duration(milliseconds: 300);
  static const Duration scrollDelayBeforeAutoScroll = Duration(
    milliseconds: 200,
  );
  static const Duration scrollToNewMessageDelay = Duration(milliseconds: 800);
  static const Duration attachmentSheetDuration = Duration(milliseconds: 250);
  static const Duration recordingToastDuration = Duration(seconds: 1);

  // Chat message styling
  static const double chatMessagePadding = 12.0;
  static const double chatMediaPadding = 4.0;
  static const double chatBorderRadius = 12.0;

  // UI Dimensions
  static const double profileAvatarRadius = 20;
  static const double profileAvatarPadding = 12;
  static const double messageCornerRadius = 12;
  static const double messagePadding = 12;
  static const double mediaMessagePadding = 4;
  static const double avatarIconSize = 48;
  static const double circleAvatarRadius = 24;

  // Scroll Detection
  static const int scrollThresholdDistance = 5;

  // File extensions
  static const List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  ];

  static const List<String> videoExtensions = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
  ];

  static const List<String> audioExtensions = [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'flac',
    'ogg',
  ];

  static const List<String> documentExtensions = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'xlsx',
    'xls',
    'ppt',
    'pptx',
  ];

  static const List<String> heicExtensions = ['heic', 'heif'];

  // Scroll detection
  static const int scrollDetectionThreshold = 5;
}

/// Utility class for file type operations
class FileTypeHelper {
  /// Determine the message type from file extension
  static MessageType getMessageTypeFromExtension(String ext) {
    final cleanExt = ext.toLowerCase().replaceAll('.', '');

    if (ChatConstants.videoExtensions.contains(cleanExt)) {
      return MessageType.video;
    } else if (ChatConstants.audioExtensions.contains(cleanExt)) {
      return MessageType.audio;
    } else if (ChatConstants.documentExtensions.contains(cleanExt)) {
      return MessageType.doc;
    } else if (ChatConstants.imageExtensions.contains(cleanExt)) {
      return MessageType.image;
    } else {
      return MessageType.doc;
    }
  }

  /// Get file category (image/video/audio/document/file)
  static String getFileCategory(String ext) {
    final cleanExt = ext.toLowerCase().replaceAll('.', '');

    if (ChatConstants.imageExtensions.contains(cleanExt)) {
      return 'media';
    } else if (ChatConstants.videoExtensions.contains(cleanExt)) {
      return 'media';
    } else if (ChatConstants.audioExtensions.contains(cleanExt)) {
      return 'media';
    } else if (ChatConstants.documentExtensions.contains(cleanExt)) {
      return 'document';
    } else {
      return 'file';
    }
  }

  /// Generate a safe filename for download based on category and timestamp
  static String generateDownloadFilename(String ext, int timestamp) {
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    final category = getFileCategory('.$cleanExt');

    switch (category) {
      case 'media':
        return 'media_$timestamp.$cleanExt';
      case 'document':
        return 'document_$timestamp.$cleanExt';
      default:
        return 'file_$timestamp.$cleanExt';
    }
  }

  /// Check if file extension is HEIC/HEIF
  static bool isHeicFormat(String ext) {
    return ChatConstants.heicExtensions.contains(
      ext.toLowerCase().replaceAll('.', ''),
    );
  }
}

/// Utility class for permission handling
class PermissionHelper {
  /// Request microphone permission
  /// Returns true if granted, false otherwise
  /// NOTE: This requests permission without pre-checking status
  static Future<bool> requestMicrophonePermission() async {
    try {
      sl<AppLogger>().debug('Requesting microphone permission...', tag: 'PermissionHelper');

      // Call request() directly - this shows the OS dialog on first request
      final permission = await Permission.microphone.request();
      sl<AppLogger>().debug('Permission result: $permission', tag: 'PermissionHelper');

      // Return true only if granted, false otherwise (denied, permanentlyDenied, restricted, etc)
      return permission.isGranted;
    } catch (e, stackTrace) {
      sl<AppLogger>().error('Error requesting permission', tag: 'PermissionHelper', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Request camera permission
  /// Returns true if granted, false otherwise
  /// NOTE: This requests permission without pre-checking status
  static Future<bool> requestCameraPermission() async {
    try {
      sl<AppLogger>().debug('Requesting camera permission...', tag: 'PermissionHelper');

      // Call request() directly - this shows the OS dialog on first request
      final permission = await Permission.camera.request();
      sl<AppLogger>().debug('Permission result: $permission', tag: 'PermissionHelper');

      // Return true only if granted, false otherwise (denied, permanentlyDenied, restricted, etc)
      return permission.isGranted;
    } catch (e, stackTrace) {
      sl<AppLogger>().error('Error requesting camera permission', tag: 'PermissionHelper', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}

/// Utility class for date/time formatting
class DateTimeFormatter {
  static const List<String> monthNames = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Format time as "12:30 PM"
  static String formatTimeOnly(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = (hour % 12 == 0) ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  /// Format date for date separator ("Today", "Yesterday", or "Mon 15")
  static String formatDateSeparator(DateTime dateTime) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == todayDate) {
      return 'Today';
    }

    final yesterday = todayDate.subtract(const Duration(days: 1));
    if (messageDate == yesterday) {
      return 'Yesterday';
    }

    return '${monthNames[dateTime.month]} ${dateTime.day}';
  }

  /// Format call duration as "1:23"
  static String formatCallDuration(int durationSeconds) {
    final minutes = (durationSeconds / 60).floor();
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get default filename based on message type
  static String getDefaultFilename(Message message) {
    switch (message.type) {
      case MessageType.audio:
        return 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      case MessageType.video:
        return 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      case MessageType.image:
        return 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      case MessageType.doc:
        return 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      default:
        return 'file_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Copy message content to clipboard and show feedback
  static Future<void> copyMessageToClipboard(
    BuildContext context,
    Message message,
  ) async {
    String textToCopy = '';

    switch (message.type) {
      case MessageType.text:
        textToCopy = message.text;
        break;
      case MessageType.doc:
        textToCopy = message.text.isNotEmpty
            ? message.text
            : message.mediaUrl ?? '';
        break;
      default:
        // For media messages, copy the filename if available, otherwise the URL
        textToCopy = message.text.isNotEmpty
            ? message.text
            : (message.mediaUrl ?? '');
    }

    if (textToCopy.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
