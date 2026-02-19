import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' show FileInfo;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/media_audio_session_helper.dart';
import 'package:greenhive_app/features/chat/widgets/cached_media_widgets.dart';
import 'package:greenhive_app/shared/services/media_cache_service.dart';

// Re-export inline video preview widgets
export 'inline_video_preview.dart';

class VideoPlayerPage extends StatefulWidget {
  final String url;
  final String roomId;
  const VideoPlayerPage({super.key, required this.url, this.roomId = 'global'});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _error = false;
  bool _showControls = true;
  late final MediaCacheService _mediaCacheService;
  File? _cachedFile;

  static const String _tag = 'VideoPlayer';
  final AppLogger _log = sl<AppLogger>();

  @override
  void initState() {
    super.initState();
    _mediaCacheService = sl<MediaCacheService>();
    WidgetsBinding.instance.addObserver(this);

    _initializeController();
    _setupFullscreen();
  }

  Future<void> _initializeController() async {
    // Try to load from cache first
    await _loadFromCacheOrNetwork();
  }

  Future<void> _loadFromCacheOrNetwork() async {
    try {
      // On web, video_player doesn't support local files, so always use network URL
      if (kIsWeb) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      } else {
        // Try to get from cache (use room ID for proper cache isolation)
        final fileInfo = await _mediaCacheService.getMediaFile(
          widget.roomId,
          widget.url,
        );

        if (fileInfo != null && fileInfo.file.existsSync()) {
          _cachedFile = fileInfo.file;
          _controller = VideoPlayerController.file(_cachedFile!);
        } else {
          _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
        }
      }

      _initialize();
    } catch (e) {
      _log.warning('Cache check failed, falling back to network', tag: _tag);
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _initialize();
    }
  }

  Future<void> _setupFullscreen() async {
    // Small delay to ensure widget is mounted
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    try {
      // Allow all orientations for fullscreen
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      // Hide status bar and navigation bar for true fullscreen
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );

      _log.debug('Fullscreen mode enabled', tag: _tag);
    } catch (e) {
      _log.error('Error setting fullscreen: $e', tag: _tag);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Re-apply fullscreen when app resumes
      _setupFullscreen();
    }
  }

  Future<void> _initialize() async {
    try {
      _log.debug('Starting initialization...', tag: _tag);
      // Configure audio session for speaker output on iOS (native)
      await MediaAudioSessionHelper.configureForMediaPlayback();
      await _controller.initialize();
      _log.debug('Controller initialized successfully', tag: _tag);
      await _controller.setVolume(1.0);
      await _controller.setLooping(true);
      await _controller.play();
      _log.debug('Video playing', tag: _tag);
      if (mounted) {
        setState(() => _ready = true);
        _log.debug('Ready state set to true', tag: _tag);
      } else {
        _log.warning('Widget not mounted after initialization', tag: _tag);
      }
    } catch (e) {
      _log.error('Error initializing: $e', tag: _tag);
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();

    // Reset to portrait only
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Re-enable system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building page - ready=$_ready, error=$_error', tag: _tag);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _log.debug('onPopInvokedWithResult - didPop=$didPop', tag: _tag);
        if (didPop) {
          // Reset system UI when popping
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.edgeToEdge,
            overlays: SystemUiOverlay.values,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: GestureDetector(
          onTap: () {
            setState(() => _showControls = !_showControls);
          },
          child: Center(
            child: _error
                ? const Text(
                    'Failed to load video',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                  )
                : !_ready
                ? const CircularProgressIndicator()
                : Stack(
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio == 0
                              ? 16 / 9
                              : _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                      // Top bar with back button
                      if (_showControls)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.background.withValues(alpha: 0.7),
                                  AppColors.background.withValues(alpha: 0),
                                ],
                              ),
                            ),
                            child: SafeArea(
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      color: AppColors.white,
                                    ),
                                    onPressed: () {
                                      _log.debug(
                                        'Back button pressed',
                                        tag: _tag,
                                      );
                                      Navigator.pop(context);
                                    },
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Video',
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Center play/pause overlay
                      PlayPauseOverlay(controller: _controller),
                      // Bottom controls
                      if (_showControls)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _VideoControls(controller: _controller),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background.withValues(alpha: 0.7),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: widget.controller,
              builder: (context, value, child) {
                return Column(
                  children: [
                    // Time indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(value.position),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(value.duration),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Slider
                    SliderTheme(
                      data: SliderThemeData(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        trackHeight: 3,
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.white.withValues(
                          alpha: 0.3,
                        ),
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      child: Slider(
                        value: value.position.inMilliseconds.toDouble().clamp(
                          0.0,
                          value.duration.inMilliseconds.toDouble(),
                        ),
                        min: 0.0,
                        max: value.duration.inMilliseconds.toDouble(),
                        onChanged: (newValue) {
                          widget.controller.seekTo(
                            Duration(milliseconds: newValue.toInt()),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.replay_10,
                    color: AppColors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    final currentPosition = widget.controller.value.position;
                    widget.controller.seekTo(
                      Duration(
                        milliseconds: (currentPosition.inMilliseconds - 10000)
                            .clamp(0, currentPosition.inMilliseconds),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 24),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, child) {
                    return IconButton(
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: AppColors.white,
                        size: 40,
                      ),
                      onPressed: () {
                        if (value.isPlaying) {
                          widget.controller.pause();
                        } else {
                          widget.controller.play();
                        }
                      },
                    );
                  },
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(
                    Icons.forward_10,
                    color: AppColors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    final currentPosition = widget.controller.value.position;
                    final duration = widget.controller.value.duration;
                    widget.controller.seekTo(
                      Duration(
                        milliseconds: (currentPosition.inMilliseconds + 10000)
                            .clamp(0, duration.inMilliseconds),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
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

class PlayPauseOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const PlayPauseOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return GestureDetector(
          onTap: () {
            if (value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
          child: Stack(
            children: <Widget>[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                reverseDuration: const Duration(milliseconds: 200),
                child: value.isPlaying
                    ? const SizedBox.shrink()
                    : Container(
                        color: AppColors.background.withValues(alpha: 0.26),
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow,
                            color: AppColors.white,
                            size: 64.0,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CachedVideoPlayerFullScreen extends StatefulWidget {
  final FileInfo cachedFileInfo;

  const CachedVideoPlayerFullScreen({super.key, required this.cachedFileInfo});

  @override
  State<CachedVideoPlayerFullScreen> createState() =>
      _CachedVideoPlayerFullScreenState();
}

class _CachedVideoPlayerFullScreenState
    extends State<CachedVideoPlayerFullScreen> {
  File? _fileWithCorrectExt;
  bool _isLoading = true;
  final _log = sl<AppLogger>();
  static const _tag = 'CachedVideoPlayerFullScreen';

  @override
  void initState() {
    super.initState();
    _prepareFile();
  }

  Future<void> _prepareFile() async {
    try {
      // Files now have proper extensions from ExtensionAwareHttpFileService
      if (mounted) {
        setState(() {
          _fileWithCorrectExt = widget.cachedFileInfo.file;
          _isLoading = false;
        });
      }
    } catch (e) {
      _log.error('Error preparing file: $e', tag: _tag);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_fileWithCorrectExt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Failed to load video file')),
      );
    }

    return CachedVideoPlayerPage(file: _fileWithCorrectExt!);
  }
}
