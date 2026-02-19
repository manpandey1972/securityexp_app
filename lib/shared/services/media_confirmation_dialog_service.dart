import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/media_audio_session_helper.dart';
import 'dart:io';

/// Unified service for showing media confirmation dialogs (audio/video)
class MediaConfirmationDialogService {
  static final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'MediaConfirmDialog';

  /// Shows audio confirmation dialog with preview
  static Future<bool> showAudioConfirmationDialog(
    BuildContext context,
    File audioFile,
  ) async {
    final audioPlayer = AudioPlayer();
    bool result = false;
    bool isDisposed = false;

    // Small delay to allow recording service to fully release audio session
    await Future.delayed(const Duration(milliseconds: 200));

    // Configure audio context for speaker output by default,
    // but allow automatic routing to Bluetooth/headset when connected
    // Let audioplayers handle the audio session configuration
    try {
      await audioPlayer.setAudioContext(
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
    } catch (e, stackTrace) {
      _log.error('Failed to set audio context: $e', tag: _tag, stackTrace: stackTrace);
      // Continue anyway, player will use defaults
    }

    // Set player mode and volume
    await audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await audioPlayer.setVolume(1.0);

    // Pre-load the source
    await audioPlayer.setSource(DeviceFileSource(audioFile.path));

    if (!context.mounted) return result;

    // Track player state and position with local variables
    PlayerState currentPlayerState = PlayerState.stopped;
    Duration currentPosition = Duration.zero;
    Duration totalDuration = Duration.zero;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Set up listeners once
          audioPlayer.onPlayerStateChanged.listen((state) {
            if (!isDisposed && context.mounted) {
              setDialogState(() {
                currentPlayerState = state;
              });
            }
          });

          audioPlayer.onPositionChanged.listen((position) {
            if (!isDisposed && context.mounted) {
              setDialogState(() {
                currentPosition = position;
              });
            }
          });

          audioPlayer.onDurationChanged.listen((duration) {
            if (!isDisposed && context.mounted) {
              setDialogState(() {
                totalDuration = duration;
              });
            }
          });

          final isPlayingNow = currentPlayerState == PlayerState.playing;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Audio Preview',
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${currentPosition.inMinutes}:${(currentPosition.inSeconds % 60).toString().padLeft(2, '0')} / ${totalDuration.inMinutes}:${(totalDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GestureDetector(
                      onTap: () async {
                        if (isDisposed) return;

                        try {
                          if (isPlayingNow) {
                            await audioPlayer.pause();
                          } else if (currentPlayerState ==
                                  PlayerState.completed ||
                              currentPlayerState == PlayerState.stopped ||
                              (totalDuration > Duration.zero &&
                                  currentPosition >= totalDuration)) {
                            // Audio finished or stopped - need to play from start
                            await audioPlayer.stop();
                            await audioPlayer.play(
                              DeviceFileSource(audioFile.path),
                            );
                          } else {
                            // Paused - just resume
                            await audioPlayer.resume();
                          }
                        } catch (e, stackTrace) {
                          _log.error(
                            'Error controlling audio: $e',
                            tag: _tag,
                            stackTrace: stackTrace,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: Icon(
                          isPlayingNow ? Icons.pause : Icons.play_arrow,
                          color: AppColors.white,
                          size: AppIconSizes.display,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Listen to your message before sending',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  isDisposed = true;
                  try {
                    await audioPlayer.stop();
                    await audioPlayer.dispose();
                  } catch (_) {
                    // Ignore disposal errors
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                  await ErrorHandler.handle<void>(
                    operation: () async {
                      await audioFile.delete();
                    },
                    onError: (error) => _log.error(
                      'Failed to delete audio file: $error',
                      tag: _tag,
                    ),
                  );
                  SnackbarService.show('Audio discarded');
                },
                child: Text(
                  'Discard',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  isDisposed = true;
                  try {
                    await audioPlayer.stop();
                    await audioPlayer.dispose();
                  } catch (_) {
                    // Ignore disposal errors
                  }
                  result = true;
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  'Send',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Ensure cleanup if not already done
    if (!isDisposed) {
      isDisposed = true;
      try {
        await audioPlayer.dispose();
      } catch (_) {
        // Ignore
      }
    }
    return result;
  }

  /// Shows video confirmation dialog with preview
  static Future<bool> showVideoConfirmationDialog(
    BuildContext context,
    File videoFile,
    Duration videoDuration,
  ) async {
    VideoPlayerController? videoController;
    bool result = false;

    try {
      // Small delay to allow camera to fully release audio session
      await Future.delayed(const Duration(milliseconds: 100));

      // Configure iOS audio session for media playback (native - forces speaker)
      await MediaAudioSessionHelper.configureForMediaPlayback();
    } catch (e, stackTrace) {
      // If native audio session config fails, continue anyway
      // The video_player package will configure it
      _log.error(
        'Native audio session config failed, continuing: $e',
        tag: _tag,
        stackTrace: stackTrace,
      );
    }

    videoController = await ErrorHandler.handle<VideoPlayerController?>(
      operation: () async {
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();
        await controller.setVolume(1.0); // Max volume
        await controller.setLooping(false);
        return controller;
      },
      fallback: null,
      onError: (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading video preview: $error')),
          );
        }
      },
    );

    if (videoController == null || !context.mounted) return result;

    final controller = videoController; // Non-null reference for closure

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Listen to video player state changes
          controller.addListener(() {
            if (controller.value.position >= controller.value.duration) {
              // Video finished playing
              setDialogState(() {});
            } else if (controller.value.isPlaying) {
              // Update UI during playback
              setDialogState(() {});
            }
          });

          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Video Preview',
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    () {
                      if (!controller.value.isInitialized) {
                        return '${videoDuration.inMinutes}:${(videoDuration.inSeconds % 60).toString().padLeft(2, '0')}';
                      }
                      // Clamp position to not exceed duration
                      final currentPosition =
                          controller.value.position > videoDuration
                          ? videoDuration
                          : controller.value.position;
                      return '${currentPosition.inMinutes}:${(currentPosition.inSeconds % 60).toString().padLeft(2, '0')} / ${videoDuration.inMinutes}:${(videoDuration.inSeconds % 60).toString().padLeft(2, '0')}';
                    }(),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: controller.value.isInitialized
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: controller.value.size.width,
                                    height: controller.value.size.height,
                                    child: VideoPlayer(controller),
                                  ),
                                ),
                              ),
                              FloatingActionButton(
                                heroTag: 'media_confirmation_video_fab',
                                mini: true,
                                backgroundColor: AppColors.info,
                                onPressed: () {
                                  setDialogState(() {
                                    if (controller.value.isPlaying) {
                                      controller.pause();
                                    } else {
                                      // If video finished, restart from beginning
                                      if (controller.value.position >=
                                          controller.value.duration) {
                                        controller.seekTo(Duration.zero);
                                      }
                                      controller.play();
                                    }
                                  });
                                },
                                child: Icon(
                                  controller.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await controller.dispose();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                  await ErrorHandler.handle<void>(
                    operation: () async {
                      await videoFile.delete();
                    },
                    onError: (error) => _log.error(
                      'Failed to delete video file: $error',
                      tag: _tag,
                    ),
                  );
                  SnackbarService.show('Video discarded');
                },
                child: Text(
                  'Discard',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  await controller.dispose();
                  result = true;
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  'Send',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }
}
