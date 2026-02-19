import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_card_styles.dart';

/// Full-screen cached video player page.
///
/// Displays a video from a local file with play/pause controls
/// and a progress indicator.
class CachedVideoPlayerPage extends StatefulWidget {
  final File file;
  const CachedVideoPlayerPage({super.key, required this.file});

  @override
  State<CachedVideoPlayerPage> createState() => _CachedVideoPlayerPageState();
}

class _CachedVideoPlayerPageState extends State<CachedVideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  // ignore: prefer_final_fields
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(1.0);
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        // Dispose the failed controller
        await _controller.dispose();
        // Navigate back and open with system player
        if (mounted) {
          Navigator.of(context).pop();
          launchUrl(
            Uri.file(widget.file.path),
            mode: LaunchMode.platformDefault,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Video')),
      body: Center(
        child: _error
            ? Text(
                'Failed to load video',
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textPrimary,
                ),
              )
            : !_ready
            ? const CircularProgressIndicator()
            : Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio == 0
                        ? 16 / 9
                        : _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                  _VideoPlayPauseOverlay(controller: _controller),
                  VideoProgressIndicator(_controller, allowScrubbing: true),
                ],
              ),
      ),
    );
  }
}

/// Play/pause overlay for video players.
class _VideoPlayPauseOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const _VideoPlayPauseOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
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
            child: controller.value.isPlaying
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
  }
}

/// Inline audio thumbnail with playback controls.
///
/// Displays a compact audio player with play/pause button and duration.
class InlineAudioThumbnail extends StatefulWidget {
  final File file;
  final FileInfo? fileInfo;

  const InlineAudioThumbnail({super.key, required this.file, this.fileInfo});

  @override
  State<InlineAudioThumbnail> createState() => _InlineAudioThumbnailState();
}

class _InlineAudioThumbnailState extends State<InlineAudioThumbnail> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    // Set volume to maximum for better audio playback
    _audioPlayer.setVolume(1.0);

    // Configure audio context for speaker output by default,
    // but allow automatic routing to Bluetooth/headset when connected
    _audioPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.allowBluetoothA2DP,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          audioMode: AndroidAudioMode.normal,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );

    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(DeviceFileSource(widget.file.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing audio: $e')));
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: AppCardStyle.subtle,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlayPause,
            child: Icon(
              _isPlaying ? Icons.pause_circle : Icons.play_circle,
              color: AppColors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              _formatDuration(_position),
              style: AppTypography.timestamp.copyWith(
                color: AppColors.white,
                fontWeight: AppTypography.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
