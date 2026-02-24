import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/services/media_audio_session_helper.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

class InlineAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final String filename;
  final bool fromMe;
  final String roomId;
  final VoidCallback? onTapDownload;
  final String? mediaKey;
  final String? mediaHash;
  final String? mediaType;

  const InlineAudioPlayer({
    super.key,
    required this.audioUrl,
    required this.filename,
    required this.fromMe,
    required this.roomId,
    this.onTapDownload,
    this.mediaKey,
    this.mediaHash,
    this.mediaType,
  });

  @override
  State<InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<InlineAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AppLogger _log = sl<AppLogger>();
  final MediaCacheService _cacheService = sl<MediaCacheService>();
  static const String _tag = 'InlineAudioPlayer';

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Set player mode to media player for full volume output
    await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);

    // Set volume to maximum for better audio message playback
    await _audioPlayer.setVolume(1.0);

    // Configure audio context for playback
    // For playback category, we don't need any special options - audio routes automatically
    await _audioPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {},
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

    _durationSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted && duration.inMilliseconds > 0) {
        setState(() => _duration = duration);
      }
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);

        // Manual completion detection: if position >= duration and duration > 0
        if (_duration.inMilliseconds > 0 &&
            position.inMilliseconds >= _duration.inMilliseconds - 100) {
          _handleCompletion();
        }
      }
    });

    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      _handleCompletion();
    });

    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _handleCompletion();
        } else if (state == PlayerState.playing) {
          if (!_isPlaying) {
            setState(() => _isPlaying = true);
          }
        } else if (state == PlayerState.paused) {
          if (_isPlaying) {
            setState(() => _isPlaying = false);
          }
        }
      }
    });

    // Pre-load the audio source to get duration
    await _setSourceAndGetDuration();
  }

  void _handleCompletion() {
    if (mounted && _isPlaying) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    }
  }

  bool get _isEncrypted => widget.mediaKey != null;

  Future<void> _setSourceAndGetDuration() async {
    // Check if URL looks like a video file (data integrity issue from past uploads)
    final lowerUrl = widget.audioUrl.toLowerCase();
    if (lowerUrl.contains('.mov') ||
        lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.avi') ||
        lowerUrl.contains('.mkv') ||
        lowerUrl.contains('.webm')) {
      // Log for data cleanup - video file incorrectly tagged as audio
      _log.warning(
        'DATA_INTEGRITY: Video file incorrectly tagged as audio. URL: ${widget.audioUrl}',
        tag: _tag,
      );
      return;
    }

    try {
      if (_isEncrypted) {
        await _setEncryptedSource();
      } else if (kIsWeb) {
        // Web: Always use network URL (no local file system)
        await _audioPlayer.setSource(UrlSource(widget.audioUrl));
      } else {
        // Mobile: Check cache first for faster playback
        final cachedFile = await _cacheService.getMediaFile(widget.roomId, widget.audioUrl);
        
        if (cachedFile != null && cachedFile.file.existsSync()) {
          _log.debug('Using cached audio file: ${cachedFile.file.path}', tag: _tag);
          await _audioPlayer.setSource(DeviceFileSource(cachedFile.file.path));
        } else {
          _log.debug('No cache, using network URL', tag: _tag);
          await _audioPlayer.setSource(UrlSource(widget.audioUrl));
        }
      }

      // Try to get duration after setting source
      final duration = await _audioPlayer.getDuration();

      if (mounted && duration != null && duration.inMilliseconds > 0) {
        setState(() => _duration = duration);
      }
    } catch (e) {
      // Log only for unexpected errors, not for format issues
      if (!e.toString().contains('No element')) {
        _log.error('Error setting audio source: $e', tag: _tag);
      }
    }
  }

  /// Download, decrypt, and set the audio source for encrypted media.
  Future<void> _setEncryptedSource() async {
    try {
      if (kIsWeb) {
        // Web: decrypt to bytes, use BytesSource
        final bytes = await _cacheService.getDecryptedMediaBytes(
          widget.audioUrl,
          mediaKey: widget.mediaKey!,
          mediaHash: widget.mediaHash,
        );
        if (bytes != null) {
          await _audioPlayer.setSource(BytesSource(bytes));
          return;
        }
        _log.error('Failed to decrypt audio on web', tag: _tag);
      } else {
        // Native: decrypt to cached file
        final ext = _audioExtension();
        final fileInfo = await _cacheService.getEncryptedMediaFile(
          widget.roomId,
          widget.audioUrl,
          mediaKey: widget.mediaKey!,
          mediaHash: widget.mediaHash,
          fileExtension: ext,
        );
        if (fileInfo != null && fileInfo.file.existsSync()) {
          _log.debug('Using decrypted cached audio: ${fileInfo.file.path}', tag: _tag);
          await _audioPlayer.setSource(DeviceFileSource(fileInfo.file.path));
          return;
        }
        _log.error('Failed to decrypt audio on native', tag: _tag);
      }
    } catch (e) {
      _log.error('Error decrypting audio: $e', tag: _tag);
    }
  }

  String _audioExtension() {
    switch (widget.mediaType) {
      case 'audio/aac':
        return '.aac';
      case 'audio/mp4':
      case 'audio/m4a':
        return '.m4a';
      case 'audio/mpeg':
        return '.mp3';
      case 'audio/wav':
        return '.wav';
      case 'audio/ogg':
        return '.ogg';
      default:
        return '.m4a';
    }
  }

  Future<void> _togglePlayPause() async {
    _log.debug(
      '_togglePlayPause called (current isPlaying: $_isPlaying)',
      tag: _tag,
    );

    if (_isPlaying) {
      _log.debug('Pausing playback', tag: _tag);
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      _log.debug('Starting playback', tag: _tag);
      // Configure iOS audio session for media playback (native)
      await MediaAudioSessionHelper.configureForMediaPlayback();

      // Always stop and play fresh to ensure clean state
      await _audioPlayer.stop();

      if (_isEncrypted) {
        // For encrypted audio, decrypt then play from cached decrypted file
        await _playEncryptedAudio();
      } else if (kIsWeb) {
        // Web: Always play from network URL (no local file system)
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      } else {
        // Mobile: Check cache first for instant playback
        final cachedFile = await _cacheService.getMediaFile(widget.roomId, widget.audioUrl);
        
        if (cachedFile != null && cachedFile.file.existsSync()) {
          _log.debug('Playing from cache: ${cachedFile.file.path}', tag: _tag);
          await _audioPlayer.play(DeviceFileSource(cachedFile.file.path));
        } else {
          _log.debug('Playing from network URL', tag: _tag);
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        }
      }
      
      setState(() => _isPlaying = true);
      _log.debug('Playback started, isPlaying set to true', tag: _tag);
    }
  }

  /// Play encrypted audio by decrypting first, then playing from decrypted source.
  Future<void> _playEncryptedAudio() async {
    try {
      if (kIsWeb) {
        final bytes = await _cacheService.getDecryptedMediaBytes(
          widget.audioUrl,
          mediaKey: widget.mediaKey!,
          mediaHash: widget.mediaHash,
        );
        if (bytes != null) {
          await _audioPlayer.play(BytesSource(bytes));
          return;
        }
        _log.error('Failed to decrypt audio for playback on web', tag: _tag);
      } else {
        final ext = _audioExtension();
        final fileInfo = await _cacheService.getEncryptedMediaFile(
          widget.roomId,
          widget.audioUrl,
          mediaKey: widget.mediaKey!,
          mediaHash: widget.mediaHash,
          fileExtension: ext,
        );
        if (fileInfo != null && fileInfo.file.existsSync()) {
          _log.debug('Playing decrypted audio: ${fileInfo.file.path}', tag: _tag);
          await _audioPlayer.play(DeviceFileSource(fileInfo.file.path));
          return;
        }
        _log.error('Failed to decrypt audio for playback on native', tag: _tag);
      }
    } catch (e) {
      _log.error('Error playing encrypted audio: $e', tag: _tag);
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
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const iconColor = AppColors.white;
    const textColor = AppColors.textSecondary;

    // Collapsed state when not playing
    if (!_isPlaying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.filename,
                  style: AppTypography.captionEmphasis,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_duration.inMilliseconds > 0)
                  Text(
                    _formatDuration(_duration),
                    style: AppTypography.badge.copyWith(color: textColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_position.inMilliseconds > 0) ...[
            GestureDetector(
              onTap: () async {
                await _audioPlayer.seek(Duration.zero);
                setState(() {
                  _position = Duration.zero;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.replay, color: iconColor, size: 16),
              ),
            ),
            const SizedBox(width: 4),
          ],
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.fromMe
                    ? AppColors.white.withValues(alpha: 0.24)
                    : AppColors.background.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_arrow, color: iconColor, size: 16),
            ),
          ),
        ],
      );
    }

    // Expanded state when playing
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.filename,
                style: AppTypography.badge.copyWith(color: AppColors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: AppTypography.badge.copyWith(color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.replay, color: iconColor, size: 20),
                onPressed: () async {
                  await _audioPlayer.seek(Duration.zero);
                  setState(() {
                    _position = Duration.zero;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28),
                tooltip: 'Restart',
              ),
              IconButton(
                icon: const Icon(Icons.replay_10, color: iconColor, size: 20),
                onPressed: () async {
                  final newPosition = _position - const Duration(seconds: 10);
                  await _audioPlayer.seek(
                    newPosition < Duration.zero ? Duration.zero : newPosition,
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28),
                tooltip: 'Rewind 10s',
              ),
              IconButton(
                icon: const Icon(
                  Icons.pause_circle_filled,
                  color: iconColor,
                  size: 32,
                ),
                onPressed: _togglePlayPause,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, color: iconColor, size: 20),
                onPressed: () async {
                  final newPosition = _position + const Duration(seconds: 10);
                  await _audioPlayer.seek(
                    newPosition > _duration ? _duration : newPosition,
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28),
                tooltip: 'Forward 10s',
              ),
            ],
          ),
          if (_duration.inMilliseconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0,
                  backgroundColor: AppColors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
