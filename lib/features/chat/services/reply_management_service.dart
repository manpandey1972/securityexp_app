import 'package:flutter/material.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';

typedef OnReplyChanged = void Function(Message? replyingTo);

class ReplyManagementService {
  Message? _replyingTo;
  final OnReplyChanged? onReplyChanged;

  ReplyManagementService({this.onReplyChanged});

  Message? get replyingTo => _replyingTo;

  bool get isReplying => _replyingTo != null;

  void setReplyingTo(Message? message) {
    _replyingTo = message;
    onReplyChanged?.call(_replyingTo);
  }

  void clearReply() {
    _replyingTo = null;
    onReplyChanged?.call(null);
  }

  void toggleReply(Message message) {
    if (_replyingTo?.id == message.id) {
      clearReply();
    } else {
      setReplyingTo(message);
    }
  }

  /// Build reply preview bar
  Widget buildReplyPreviewBar(
    BuildContext context, {
    required VoidCallback onClear,
    required bool isRecording,
  }) {
    if (_replyingTo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.1),
        border: Border(left: BorderSide(color: AppColors.surface, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Replying to:',
                  style: AppTypography.captionEmphasis,
                ),
                const SizedBox(height: 4),
                _buildReplyPreviewContent(),
              ],
            ),
          ),
          if (!isRecording)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyPreviewContent() {
    final msg = _replyingTo!;

    // Helper to strip encryption suffix and extract filename from URL
    String getFileName(String path) {
      if (path.isEmpty) return '';

      // Strip .enc extension added during encryption
      String stripEnc(String name) {
        if (name.toLowerCase().endsWith('.enc')) {
          return name.substring(0, name.length - 4);
        }
        return name;
      }

      try {
        // Handle Firebase Storage URLs with encoded paths
        final uri = Uri.parse(path);

        // Extract the path component (after /o/)
        if (uri.pathSegments.contains('o') && uri.pathSegments.length > 1) {
          final oIndex = uri.pathSegments.indexOf('o');
          if (oIndex + 1 < uri.pathSegments.length) {
            // Decode the URL-encoded path
            final encodedPath = uri.pathSegments[oIndex + 1];
            final decodedPath = Uri.decodeComponent(encodedPath);

            // Extract just the filename (last part after /) and strip .enc
            var fileName = stripEnc(decodedPath.split('/').last);

            // Limit length and add ellipsis if needed
            if (fileName.length > 30) {
              return '${fileName.substring(0, 27)}...';
            }
            return fileName;
          }
        }

        // Fallback for non-Firebase URLs
        var name = stripEnc(path.split('/').last.split('?').first);
        if (name.length > 30) {
          return '${name.substring(0, 27)}...';
        }
        return name;
      } catch (e) {
        // If parsing fails, use simple split
        var name = stripEnc(path.split('/').last.split('?').first);
        if (name.length > 30) {
          return '${name.substring(0, 27)}...';
        }
        return name;
      }
    }

    // Helper to get readable text
    String getDisplayText() {
      // Prefer the stored clean filename (avoids .enc exposure)
      if (msg.fileName != null && msg.fileName!.isNotEmpty) {
        return msg.fileName!;
      }
      // For media types, extract filename from URL as fallback
      if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
        final fileName = getFileName(msg.mediaUrl!);
        if (fileName.isNotEmpty) return fileName;
      }
      
      // Check if text contains a URL
      if (msg.text.startsWith('http://') || msg.text.startsWith('https://')) {
        // Extract domain from URL
        try {
          final uri = Uri.parse(msg.text);
          return uri.host.replaceFirst('www.', '');
        } catch (e) {
          return 'Link';
        }
      }
      
      return msg.text.isEmpty ? '' : msg.text;
    }

    if (msg.type == MessageType.audio) {
      final displayText = getDisplayText();
      return Row(
        children: [
          const Icon(Icons.music_note, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayText.isEmpty ? 'Audio message' : displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      );
    }

    if (msg.type == MessageType.video) {
      final displayText = getDisplayText();
      return Row(
        children: [
          const Icon(Icons.videocam, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayText.isEmpty ? 'Video message' : displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      );
    }

    if (msg.type == MessageType.image) {
      final displayText = getDisplayText();
      return Row(
        children: [
          const Icon(Icons.image, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayText.isEmpty ? 'Photo' : displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      );
    }

    if (msg.type == MessageType.doc) {
      final displayText = getDisplayText();
      return Row(
        children: [
          const Icon(Icons.description, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayText.isEmpty ? 'Document' : displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      );
    }

    // For text messages, check if it contains a link
    final text = msg.text;
    if (text.startsWith('http://') || text.startsWith('https://')) {
      try {
        final uri = Uri.parse(text);
        final domain = uri.host.replaceFirst('www.', '');
        return Row(
          children: [
            const Icon(Icons.link, size: 14, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                domain,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        );
      } catch (e) {
        // Fall through to regular text display
      }
    }

    return Text(
      msg.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
    );
  }

  /// Get reply text for UI
  String getReplyDisplayText() {
    if (_replyingTo == null) return '';

    // Helper to strip encryption suffix and extract filename from URL
    String getFileName(String path) {
      if (path.isEmpty) return '';

      String stripEnc(String name) {
        if (name.toLowerCase().endsWith('.enc')) {
          return name.substring(0, name.length - 4);
        }
        return name;
      }

      try {
        final uri = Uri.parse(path);

        if (uri.pathSegments.contains('o') && uri.pathSegments.length > 1) {
          final oIndex = uri.pathSegments.indexOf('o');
          if (oIndex + 1 < uri.pathSegments.length) {
            final encodedPath = uri.pathSegments[oIndex + 1];
            final decodedPath = Uri.decodeComponent(encodedPath);
            var fileName = stripEnc(decodedPath.split('/').last);
            if (fileName.length > 30) {
              return '${fileName.substring(0, 27)}...';
            }
            return fileName;
          }
        }

        var name = stripEnc(path.split('/').last.split('?').first);
        if (name.length > 30) {
          return '${name.substring(0, 27)}...';
        }
        return name;
      } catch (e) {
        var name = stripEnc(path.split('/').last.split('?').first);
        if (name.length > 30) {
          return '${name.substring(0, 27)}...';
        }
        return name;
      }
    }

    // Get display text based on message type
    String displayText = _replyingTo!.text;

    // Prefer the stored clean filename (avoids .enc exposure)
    if (_replyingTo!.fileName != null && _replyingTo!.fileName!.isNotEmpty) {
      displayText = _replyingTo!.fileName!;
    } else if (_replyingTo!.mediaUrl != null && _replyingTo!.mediaUrl!.isNotEmpty) {
      final fileName = getFileName(_replyingTo!.mediaUrl!);
      if (fileName.isNotEmpty) displayText = fileName;
    }

    // For links, show domain
    if (displayText.startsWith('http://') || displayText.startsWith('https://')) {
      try {
        final uri = Uri.parse(displayText);
        displayText = uri.host.replaceFirst('www.', '');
      } catch (e) {
        displayText = 'Link';
      }
    }

    switch (_replyingTo!.type) {
      case MessageType.audio:
        return '🎵 ${displayText.isEmpty ? 'Audio message' : displayText}';
      case MessageType.video:
        return '🎬 ${displayText.isEmpty ? 'Video message' : displayText}';
      case MessageType.image:
        return '🖼️ ${displayText.isEmpty ? 'Photo' : displayText}';
      case MessageType.doc:
        return '📄 ${displayText.isEmpty ? 'Document' : displayText}';
      case MessageType.callLog:
        return '☎️ ${_replyingTo!.text}';
      default:
        // Check if regular text message contains a link
        if (displayText.isNotEmpty && 
            (displayText.startsWith('http://') || displayText.startsWith('https://'))) {
          return '🔗 $displayText';
        }
        return _replyingTo!.text;
    }
  }

  /// Clear service
  void dispose() {
    _replyingTo = null;
  }
}
