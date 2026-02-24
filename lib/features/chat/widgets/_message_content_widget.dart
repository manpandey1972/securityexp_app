import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import 'package:securityexperts_app/features/chat/widgets/document_message_bubble.dart';
import 'package:securityexperts_app/features/chat/pages/pdf_viewer_page.dart';
import 'package:securityexperts_app/features/chat/pages/text_viewer_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'link_preview_widget.dart';
import 'linkified_text.dart';

/// Builds message content based on message type
/// Extracted from MessageBubble for better reusability and testability
class MessageContentWidget extends StatelessWidget {
  final Message message;
  final bool fromMe;
  final Function(String)? onShowImagePreview;
  final Function(String)? onPlayAudio;
  final Widget? audioWidget;
  final Widget? videoWidget;
  final Widget? documentWidget;
  final CacheManager? cacheManager;
  final String? roomId;

  const MessageContentWidget({
    super.key,
    required this.message,
    required this.fromMe,
    this.onShowImagePreview,
    this.onPlayAudio,
    this.audioWidget,
    this.videoWidget,
    this.documentWidget,
    this.cacheManager,
    this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return _buildMessageContent();
  }

  Widget _buildMessageContent() {
    switch (message.type) {
      case MessageType.text:
        final text = message.text;
        final hasUrl = containsUrl(text);

        if (hasUrl) {
          final url = extractFirstUrl(text)!;
          final textWithoutUrl = extractTextWithoutUrl(text);

          // If message is only a URL, show just the preview
          if (textWithoutUrl == null) {
            return LinkPreviewWidget(url: url, fromMe: fromMe);
          }

          // If message has text + URL, show text then preview
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                textWithoutUrl,
                style: AppTypography.bodyEmphasis.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: 8),
              LinkPreviewWidget(url: url, fromMe: fromMe),
            ],
          );
        }

        return LinkifiedText(
          text,
          style: AppTypography.bodyEmphasis.copyWith(color: AppColors.white),
          selectable: true,
        );
      case MessageType.image:
        return _buildImageMessage();
      case MessageType.video:
        return videoWidget ?? _buildVideoMessage();
      case MessageType.audio:
        return audioWidget ?? _buildAudioMessage();
      case MessageType.doc:
        return _buildDocMessage();
      case MessageType.callLog:
        return _buildCallLogMessage();
      case MessageType.system:
        return Text(
          message.text,
          style: AppTypography.captionSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        );
    }
  }

  /// Whether this message has encrypted media that needs decryption.
  bool get _hasEncryptedMedia =>
      message.isEncrypted &&
      message.mediaKey != null &&
      message.mediaUrl != null;

  Widget _buildImageMessage() {
    if (_hasEncryptedMedia) {
      return _EncryptedImageWidget(
        message: message,
        roomId: roomId,
        onShowImagePreview: onShowImagePreview,
      );
    }
    return GestureDetector(
      onTap: onShowImagePreview != null
          ? () => onShowImagePreview!(message.mediaUrl!)
          : null,
      child: CachedNetworkImage(
        imageUrl: message.mediaUrl!,
        cacheManager: cacheManager,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Container(
          width: 140,
          height: 140,
          color: AppColors.textSecondary,
          child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }

  Widget _buildVideoMessage() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.textSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Show a placeholder instead of trying to load video as image
          Container(
            width: 140,
            height: 140,
            color: AppColors.divider,
            child: const Icon(
              Icons.video_library,
              size: AppIconSizes.display,
              color: AppColors.textSecondary,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.play_arrow, color: AppColors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioMessage() {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPlayAudio != null
                ? () => onPlayAudio!(message.mediaUrl!)
                : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: AppColors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Voice message',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(message.metadata?['duration'] ?? 0).toStringAsFixed(1)}s',
                  style: AppTypography.captionTiny.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocMessage() {
    // Use custom document widget if provided
    if (documentWidget != null) {
      return documentWidget!;
    }

    final fileName = message.metadata?['fileName'] ?? 'Document';
    final fileSizeInt = message.metadata?['fileSize'] as int?;
    final fileSize = fileSizeInt != null ? _formatFileSize(fileSizeInt) : null;
    final mediaUrl = message.mediaUrl;

    return DocumentMessageBubble(
      fileName: fileName,
      fileSize: fileSize,
      mediaUrl: mediaUrl,
      fromMe: fromMe,
      onTap: null, // Navigation handled by chat_message_list_item
    );
  }

  /// Format file size in bytes to human-readable string
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Static method to navigate to the appropriate document viewer
  static void navigateToDocumentViewer(
    BuildContext context, {
    required String fileName,
    required String? mediaUrl,
    String? roomId,
  }) async {
    if (mediaUrl == null || mediaUrl.isEmpty) return;

    // Try to get extension from fileName first, then fallback to URL
    String extension = '';
    if (fileName.contains('.')) {
      extension = fileName.split('.').last.toLowerCase();
    } else if (mediaUrl.contains('.')) {
      // Try to extract extension from URL (before query params)
      final urlPath = Uri.parse(mediaUrl).path;
      if (urlPath.contains('.')) {
        extension = urlPath.split('.').last.toLowerCase();
      }
    }

    if (isPdfFile(extension)) {
      if (kIsWeb) {
        // On web, open PDF in new tab (browser handles it natively)
        final uri = Uri.parse(mediaUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        // On mobile/desktop, use in-app viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PDFViewerPage(
              url: mediaUrl,
              fileName: fileName,
              roomId: roomId,
            ),
          ),
        );
      }
    } else if (isTextFile(extension)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TextViewerPage(
            url: mediaUrl,
            fileName: fileName,
            roomId: roomId,
          ),
        ),
      );
    } else {
      // For documents that can't be viewed in-app, open externally
      final uri = Uri.parse(mediaUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Check if the file is a PDF
  static bool isPdfFile(String extension) {
    return extension == 'pdf';
  }

  /// Check if the file is a text/code file
  static bool isTextFile(String extension) {
    const textExtensions = [
      'txt', 'md', 'log', 'dart', 'js', 'ts', 'json',
      'xml', 'yaml', 'yml', 'html', 'css', 'py', 'java',
      'kt', 'swift', 'c', 'cpp', 'h', 'hpp', 'sh', 'bash',
      'zsh', 'env', 'ini', 'cfg', 'conf', 'toml', 'gradle',
    ];
    return textExtensions.contains(extension);
  }

  /// Check if the file can be viewed in-app
  static bool canViewInApp(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return isPdfFile(extension) || isTextFile(extension);
  }

  Widget _buildCallLogMessage() {
    final status = message.metadata?['status'] ?? 'ended';
    final durationSeconds = message.metadata?['durationSeconds'] ?? 0;
    final duration = Duration(seconds: durationSeconds as int);

    String statusText = status.toString();
    IconData statusIcon = Icons.call;

    switch (status) {
      case 'missed':
        statusText = '❌ Missed call';
        statusIcon = Icons.call_missed;
        break;
      case 'rejected':
        statusText = '❌ Call rejected';
        statusIcon = Icons.call_missed_outgoing;
        break;
      case 'ended':
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        statusText = '✓ Call ended (${minutes}m ${seconds}s)';
        statusIcon = Icons.call;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(statusIcon, color: AppColors.textPrimary, size: AppIconSizes.small),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: AppTypography.bodyEmphasis.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// A widget that downloads, decrypts, caches, and displays an encrypted image.
class _EncryptedImageWidget extends StatefulWidget {
  final Message message;
  final String? roomId;
  final Function(String)? onShowImagePreview;

  const _EncryptedImageWidget({
    required this.message,
    this.roomId,
    this.onShowImagePreview,
  });

  @override
  State<_EncryptedImageWidget> createState() => _EncryptedImageWidgetState();
}

class _EncryptedImageWidgetState extends State<_EncryptedImageWidget> {
  Future<Uint8List?>? _decryptFuture;

  @override
  void initState() {
    super.initState();
    _decryptFuture = _loadDecryptedImage();
  }

  Future<Uint8List?> _loadDecryptedImage() async {
    final roomId = widget.roomId;
    final mediaUrl = widget.message.mediaUrl!;
    final mediaKey = widget.message.mediaKey!;
    final mediaHash = widget.message.mediaHash;

    if (roomId == null) return null;

    try {
      final mediaCacheService = sl<MediaCacheService>();

      // On web, dart:io File operations don't work.
      // Use getDecryptedMediaBytes which returns raw bytes.
      if (kIsWeb) {
        return await mediaCacheService.getDecryptedMediaBytes(
          mediaUrl,
          mediaKey: mediaKey,
          mediaHash: mediaHash,
        );
      }

      // On native, use file-based caching for efficiency.
      final ext = _extensionFromMimeType(widget.message.mediaType);

      final fileInfo = await mediaCacheService.getEncryptedMediaFile(
        roomId,
        mediaUrl,
        mediaKey: mediaKey,
        mediaHash: mediaHash,
        fileExtension: ext,
      );

      if (fileInfo != null && fileInfo.file.existsSync()) {
        return await fileInfo.file.readAsBytes();
      }

      // Fallback: get raw decrypted bytes
      return await mediaCacheService.getDecryptedMediaBytes(
        mediaUrl,
        mediaKey: mediaKey,
        mediaHash: mediaHash,
      );
    } catch (_) {
      return null;
    }
  }

  /// Open a full-screen preview showing the already-decrypted image bytes.
  void _showDecryptedImagePreview(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (innerContext) => Scaffold(
          appBar: AppBar(title: const Text('Image')),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 64),
                    SizedBox(height: 16),
                    Text('Image failed to load'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _extensionFromMimeType(String? mimeType) {
    if (mimeType == null) return '.bin';
    switch (mimeType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
        return '.heic';
      default:
        return '.bin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _decryptFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 140,
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return Container(
            width: 140,
            height: 140,
            color: AppColors.textSecondary,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: AppColors.white, size: 24),
                SizedBox(height: 4),
                Text(
                  'Cannot decrypt',
                  style: TextStyle(color: AppColors.white, fontSize: 10),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () => _showDecryptedImagePreview(context, bytes),
          child: Image.memory(
            bytes,
            width: 140,
            height: 140,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 140,
              height: 140,
              color: AppColors.textSecondary,
              child: const Icon(Icons.broken_image),
            ),
          ),
        );
      },
    );
  }
}
