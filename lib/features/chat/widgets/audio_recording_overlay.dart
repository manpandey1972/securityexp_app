import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

/// Compact audio recording bar - inline with chat input
/// Sleek, single-row design similar to modern messaging apps
class AudioRecordingOverlay extends StatefulWidget {
  final VoidCallback onDiscard;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool isRecording;
  final Duration duration;
  final String? recordingPath;

  const AudioRecordingOverlay({
    super.key,
    required this.onDiscard,
    required this.onSend,
    required this.onStop,
    required this.isRecording,
    required this.duration,
    this.recordingPath,
  });

  @override
  State<AudioRecordingOverlay> createState() => _AudioRecordingOverlayState();
}

class _AudioRecordingOverlayState extends State<AudioRecordingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _waveformTimer;
  final List<double> _waveformHeights = List.generate(20, (_) => 0.3);
  int _currentWaveformIndex = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completeSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    if (widget.isRecording) {
      _startWaveformAnimation();
    }

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _playbackPosition = position);
    });

    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    _pulseController.dispose();
    _waveformTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AudioRecordingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _startWaveformAnimation();
      } else {
        _waveformTimer?.cancel();
      }
    }
  }

  void _startWaveformAnimation() {
    _waveformTimer?.cancel();
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (widget.isRecording && mounted) {
        setState(() {
          _currentWaveformIndex =
              (_currentWaveformIndex + 1) % _waveformHeights.length;
          _waveformHeights[_currentWaveformIndex] =
              0.2 + (0.8 * (DateTime.now().millisecond % 100) / 100);
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (widget.recordingPath == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.recordingPath!));
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: AppColors.background,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Discard/Cancel button
                _buildIconButton(
                  icon: Icons.close_rounded,
                  color: AppColors.error,
                  onTap: widget.onDiscard,
                  size: 36,
                ),
                const SizedBox(width: 8),

                // Recording indicator or Play button
                if (widget.isRecording)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.error,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error
                                  .withValues(alpha: 0.6 * _pulseController.value),
                              blurRadius: 6 * _pulseController.value,
                              spreadRadius: 2 * _pulseController.value,
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  _buildIconButton(
                    icon:
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    onTap: _togglePlayPause,
                    size: 36,
                  ),
                const SizedBox(width: 12),

                // Waveform / Duration section
                Expanded(
                  child: widget.isRecording
                      ? _buildWaveform()
                      : _buildPreviewInfo(),
                ),
                const SizedBox(width: 12),

                // Duration text
                Text(
                  _formatDuration(
                      _isPlaying ? _playbackPosition : widget.duration),
                  style: AppTypography.bodySmall.copyWith(
                    color: widget.isRecording
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),

                // Stop or Send button
                if (widget.isRecording)
                  _buildIconButton(
                    icon: Icons.stop_rounded,
                    color: AppColors.error,
                    onTap: widget.onStop,
                    size: 40,
                    filled: true,
                  )
                else
                  _buildIconButton(
                    icon: Icons.send_rounded,
                    color: AppColors.primaryLight,
                    onTap: widget.onSend,
                    size: 40,
                    filled: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_waveformHeights.length, (index) {
          final height = _waveformHeights[index];
          final distance = (index - _currentWaveformIndex).abs();
          final isActive = distance < 4;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 2.5,
            height: 32 * height,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.error.withValues(alpha: 1.0 - (distance * 0.15))
                  : AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPreviewInfo() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Voice message',
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double size,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : color.withValues(alpha: 0.15),
        ),
        child: Icon(
          icon,
          size: size * 0.55,
          color: filled ? AppColors.white : color,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
