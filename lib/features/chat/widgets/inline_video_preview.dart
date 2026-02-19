import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' show FileInfo;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/media_audio_session_helper.dart';

/// Inline video preview widget for network videos.
/// Shows a thumbnail with play button, supports inline playback.
class InlineVideoPreview extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onTapExpand;
  final VoidCallback? onTapDownload;

  const InlineVideoPreview({
    super.key,
    required this.videoUrl,
    required this.onTapExpand,
    this.onTapDownload,
  });

  @override
  State<InlineVideoPreview> createState() => _InlineVideoPreviewState();
}

class _InlineVideoPreviewState extends State<InlineVideoPreview> {
  String? _thumbnailPath;
  VideoPlayerController? _miniController;
  bool _isPlaying = false;
  bool _isInitialized = false;
  VoidCallback? _videoListener;

  static const String _tag = 'InlineVideoPreview';
  final AppLogger _log = sl<AppLogger>();

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
    _initializeController();
  }

  Future<void> _initializeController() async {
    _miniController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    try {
      await _miniController!.initialize();
      await _miniController!.setVolume(1.0);

      // Add listener to sync _isPlaying with actual controller state
      _videoListener = () {
        if (mounted) {
          final isCurrentlyPlaying = _miniController!.value.isPlaying;
          if (_isPlaying != isCurrentlyPlaying) {
            setState(() {
              _isPlaying = isCurrentlyPlaying;
            });
          }
        }
      };
      _miniController!.addListener(_videoListener!);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _log.error('Failed to initialize controller: $e', tag: _tag);
    }
  }

  Future<void> _generateThumbnail() async {
    // Skip thumbnail generation on web - path_provider not supported
    if (kIsWeb) {
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await video_thumbnail.VideoThumbnail.thumbnailFile(
        video: widget.videoUrl,
        thumbnailPath: tempDir.path,
        imageFormat: video_thumbnail.ImageFormat.PNG,
        maxWidth: 300,
        quality: 75,
      );
      if (mounted) {
        setState(() => _thumbnailPath = thumbnailPath);
      }
    } catch (e) {
      _log.error('Thumbnail generation failed: $e', tag: _tag);
    }
  }

  Future<void> _toggleMiniPlayer() async {
    if (!_isInitialized || _miniController == null) {
      if (mounted) {
        SnackbarService.show('Video is still loading...');
      }
      return;
    }

    if (_isPlaying) {
      await _miniController!.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // Configure audio session before playing on iOS (native)
      await MediaAudioSessionHelper.configureForMediaPlayback();
      await _miniController!.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _miniController?.dispose();
    super.dispose();
  }

  /// Pause the inline video player (called before opening fullscreen)
  void _pauseVideo() {
    if (_miniController != null && _isPlaying) {
      _miniController!.pause();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _pauseVideo(); // Pause inline player before opening fullscreen
        widget.onTapExpand();
      },
      child: SizedBox(
        width: 180,
        height: 140,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isInitialized && _miniController != null)
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _miniController!.value.size.width,
                      height: _miniController!.value.size.height,
                      child: VideoPlayer(_miniController!),
                    ),
                  ),
                )
              else if (_thumbnailPath != null)
                Image.file(
                  File(_thumbnailPath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              else
                Container(
                  color: AppColors.background,
                  child: const Center(
                    child: Icon(
                      Icons.video_library,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (!_isPlaying)
                GestureDetector(
                  onTap: () {
                    _toggleMiniPlayer();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: AppColors.white,
                      size: 32,
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () {
                      _toggleMiniPlayer();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.54),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.pause,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              // Duration badge
              if (_isInitialized && _miniController != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(_miniController!.value.duration),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    _pauseVideo(); // Pause inline player before opening fullscreen
                    widget.onTapExpand();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.54),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: AppColors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

/// Inline video preview widget for cached videos.
/// Shows a thumbnail with play button, supports inline playback from local file.
class InlineCachedVideoPreview extends StatefulWidget {
  final FileInfo cachedFileInfo;
  final VoidCallback onTapExpand;
  final VoidCallback? onTapDownload;

  const InlineCachedVideoPreview({
    super.key,
    required this.cachedFileInfo,
    required this.onTapExpand,
    this.onTapDownload,
  });

  @override
  State<InlineCachedVideoPreview> createState() =>
      _InlineCachedVideoPreviewState();
}

class _InlineCachedVideoPreviewState extends State<InlineCachedVideoPreview> {
  String? _thumbnailPath;
  VideoPlayerController? _miniController;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _initializationFailed = false;
  File? _fileWithCorrectExt;
  VoidCallback? _videoListener;
  final _log = sl<AppLogger>();
  static const _tag = 'InlineCachedVideoPreview';

  @override
  void initState() {
    super.initState();
    _initializeWithCorrectExtension();
  }

  Future<void> _initializeWithCorrectExtension() async {
    try {
      if (!mounted) return;

      final file = widget.cachedFileInfo.file;

      if (!file.existsSync()) {
        _log.warning('Cached file does not exist', tag: _tag);
        if (mounted) setState(() => _initializationFailed = true);
        return;
      }

      setState(() => _fileWithCorrectExt = file);

      _generateThumbnail();
      _initializeController();
    } catch (e) {
      _log.error('Error initializing: $e', tag: _tag);
      if (mounted) {
        setState(() => _initializationFailed = true);
      }
    }
  }

  Future<void> _initializeController() async {
    if (_fileWithCorrectExt == null) return;

    _miniController = VideoPlayerController.file(_fileWithCorrectExt!);
    try {
      await _miniController!.initialize();
      await _miniController!.setVolume(1.0);

      // Add listener to sync _isPlaying with actual controller state
      _videoListener = () {
        if (mounted) {
          final isCurrentlyPlaying = _miniController!.value.isPlaying;
          if (_isPlaying != isCurrentlyPlaying) {
            setState(() {
              _isPlaying = isCurrentlyPlaying;
            });
          }
        }
      };
      _miniController!.addListener(_videoListener!);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _initializationFailed = false;
        });
      }
    } catch (e) {
      _log.error('Failed to initialize controller: $e', tag: _tag);
      if (mounted) {
        setState(() {
          _initializationFailed = true;
          _isInitialized = false;
        });
      }
    }
  }

  Future<void> _generateThumbnail() async {
    if (_fileWithCorrectExt == null) return;

    try {
      final thumbnailData = await video_thumbnail.VideoThumbnail.thumbnailData(
        video: _fileWithCorrectExt!.path,
        imageFormat: video_thumbnail.ImageFormat.PNG,
        maxWidth: 300,
        quality: 75,
      );
      if (thumbnailData != null && mounted) {
        final tempDir = await getTemporaryDirectory();
        final thumbnailFile = File(
          '${tempDir.path}/thumb_${_fileWithCorrectExt!.path.hashCode}.png',
        );
        await thumbnailFile.writeAsBytes(thumbnailData);
        setState(() => _thumbnailPath = thumbnailFile.path);
      }
    } catch (e) {
      _log.error('Failed to generate thumbnail: $e', tag: _tag);
    }
  }

  Future<void> _toggleMiniPlayer() async {
    if (_initializationFailed || _fileWithCorrectExt == null) {
      await launchUrl(
        Uri.file(_fileWithCorrectExt?.path ?? widget.cachedFileInfo.file.path),
        mode: LaunchMode.platformDefault,
      );
      return;
    }

    if (!_isInitialized || _miniController == null) {
      if (mounted) {
        SnackbarService.show('Video is still loading...');
      }
      return;
    }

    if (_isPlaying) {
      await _miniController!.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // Configure audio session before playing on iOS (native)
      await MediaAudioSessionHelper.configureForMediaPlayback();
      await _miniController!.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    if (_videoListener != null) {
      _miniController?.removeListener(_videoListener!);
    }
    _miniController?.dispose();
    super.dispose();
  }

  /// Pause the inline video player (called before opening fullscreen)
  void _pauseVideo() {
    if (_miniController != null && _isPlaying) {
      _miniController!.pause();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _pauseVideo(); // Pause inline player before opening fullscreen
        widget.onTapExpand();
      },
      child: SizedBox(
        width: 180,
        height: 140,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isInitialized && _miniController != null)
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _miniController!.value.size.width,
                      height: _miniController!.value.size.height,
                      child: VideoPlayer(_miniController!),
                    ),
                  ),
                )
              else if (_thumbnailPath != null)
                Image.file(
                  File(_thumbnailPath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              else
                Container(
                  color: AppColors.background,
                  child: const Center(
                    child: Icon(
                      Icons.video_library,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (!_isPlaying)
                GestureDetector(
                  onTap: () {
                    _toggleMiniPlayer();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: AppColors.white,
                      size: 32,
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () {
                      _toggleMiniPlayer();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.54),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.pause,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              // Duration badge
              if (_isInitialized && _miniController != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(_miniController!.value.duration),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    _pauseVideo(); // Pause inline player before opening fullscreen
                    widget.onTapExpand();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.54),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: AppColors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
