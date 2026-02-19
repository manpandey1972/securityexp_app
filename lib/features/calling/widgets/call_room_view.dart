import 'package:flutter/material.dart';
import 'dart:async';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/calling/widgets/call_control_buttons.dart';
import 'package:securityexperts_app/data/models/models.dart' as models;
import 'package:securityexperts_app/features/calling/pages/call_controller.dart';
import 'package:securityexperts_app/features/calling/widgets/call_room_constants.dart';
import 'package:securityexperts_app/features/calling/widgets/audio_call_view.dart';
import 'package:securityexperts_app/features/calling/widgets/remote_video_placeholder.dart';
import 'package:securityexperts_app/features/calling/widgets/pip_video_layer.dart';
import 'package:securityexperts_app/features/calling/widgets/call_status_bar.dart';
import 'package:securityexperts_app/features/calling/widgets/mute_indicator_badge.dart';
import 'package:securityexperts_app/features/calling/widgets/breathing_avatar.dart';
import 'package:securityexperts_app/features/calling/services/audio_device_service.dart';
import 'package:securityexperts_app/core/di/call_dependencies.dart';

/// Main view for an active call room, supporting both audio and video calls.
/// Orchestrates sub-widgets for fullscreen video, PiP, controls, and status bar.
class CallRoomView extends StatefulWidget {
  final CallController controller;
  final String displayName;
  final void Function({String position}) onMinimize;
  final models.User? peerUser;
  final models.User? currentUser;

  const CallRoomView({
    super.key,
    required this.controller,
    required this.displayName,
    required this.onMinimize,
    this.peerUser,
    this.currentUser,
  });

  @override
  State<CallRoomView> createState() => _CallRoomViewState();
}

class _CallRoomViewState extends State<CallRoomView> {
  // UI state
  bool _controlsVisible = true;
  bool _swapVideos = false;
  Offset? _pipPosition;
  double _dragStartY = 0;
  double _currentDragY = 0;

  // Auto-hide controls state
  late Timer _controlsHideTimer;
  static const Duration _controlsVisibilityDuration = Duration(seconds: 10);

  // GlobalKey to preserve PiP video state across control visibility changes
  final GlobalKey _pipLayerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _controlsHideTimer.cancel();
    super.dispose();
  }

  void _startHideControlsTimer() {
    _controlsHideTimer = Timer(_controlsVisibilityDuration, () {
      if (mounted && _controlsVisible) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _resetHideControlsTimer() {
    _controlsHideTimer.cancel();
    _startHideControlsTimer();
  }

  void _onScreenTap() {
    _controlsHideTimer.cancel();
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _startHideControlsTimer();
    }
  }

  void _toggleSwapVideos() {
    _resetHideControlsTimer();
    setState(() => _swapVideos = !_swapVideos);
  }

  void _onPipPan(DragUpdateDetails details) {
    setState(() {
      final size = MediaQuery.of(context).size;
      double dx =
          (_pipPosition?.dx ??
              size.width -
                  CallRoomConstants.pipWidth -
                  CallRoomConstants.pipMargin) +
          details.delta.dx;
      double dy = (_pipPosition?.dy ?? 64.0) + details.delta.dy;

      dx = dx.clamp(
        CallRoomConstants.pipMargin,
        size.width - CallRoomConstants.pipWidth - CallRoomConstants.pipMargin,
      );
      dy = dy.clamp(
        CallRoomConstants.topOffset,
        size.height - CallRoomConstants.pipHeight - CallRoomConstants.pipMargin,
      );

      _pipPosition = Offset(dx, dy);
    });
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _currentDragY = _dragStartY;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _currentDragY = details.globalPosition.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final dragDistance = _currentDragY - _dragStartY;
    if (dragDistance.abs() > CallRoomConstants.swipeThreshold) {
      final position = dragDistance > 0 ? 'bottom' : 'top';
      widget.onMinimize(position: position);
    }
    setState(() {
      _dragStartY = 0;
      _currentDragY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.mediaManager == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Fullscreen Layer
          Positioned.fill(
            child: GestureDetector(
              onTap: _onScreenTap,
              onDoubleTap: _toggleSwapVideos,
              onVerticalDragStart: _onVerticalDragStart,
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              behavior: HitTestBehavior.opaque,
              child: _buildFullscreenContent(),
            ),
          ),

          // 2. Gradient Overlay
          if (_controlsVisible) _buildGradientOverlay(),

          // 3. Top Status Bar
          if (_controlsVisible)
            Positioned(
              top: CallRoomConstants.topOffset,
              left: 0,
              right: 0,
              child: CallStatusBar(
                durationSeconds: widget.controller.durationSeconds,
                callQuality: widget.controller.callQuality,
                isVideoCall: widget.controller.isVideo,
              ),
            ),

          // 4. PiP Layer (video calls only)
          if (widget.controller.isVideo) _buildPipLayer(),

          // 5. Bottom Controls
          if (_controlsVisible)
            Positioned(
              bottom: CallRoomConstants.bottomOffset,
              left: 0,
              right: 0,
              child: _buildControls(),
            ),
        ],
      ),
    );
  }

  Widget _buildFullscreenContent() {
    // Audio calls show AudioCallView
    if (!widget.controller.isVideo) {
      return AudioCallView(
        displayName: widget.displayName,
        peerUser: widget.peerUser,
        durationSeconds: widget.controller.durationSeconds,
        isRemoteAudioMuted: widget.controller.mediaManager!.isRemoteAudioMuted,
      );
    }

    // Video calls: show local or remote based on swap state
    return _buildVideoFullscreen();
  }

  Widget _buildVideoFullscreen() {
    final mediaManager = widget.controller.mediaManager!;

    if (_swapVideos) {
      // Local video fullscreen
      return ValueListenableBuilder<bool>(
        valueListenable: mediaManager.isVideoEnabled,
        builder: (ctx, localVideoEnabled, _) {
          if (!localVideoEnabled) {
            return Container(
              color: AppColors.background,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BreathingAvatar(user: widget.currentUser),
                    const SizedBox(height: 16),
                    Text(
                      "Camera off",
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return mediaManager.buildLocalPreview(
            fit: BoxFit.cover,
            mirror: true,
          );
        },
      );
    }

    // Remote video fullscreen (default)
    return _buildRemoteVideoFullscreen();
  }

  Widget _buildRemoteVideoFullscreen() {
    final mediaManager = widget.controller.mediaManager!;
    final hasRemoteStreamNotifier = mediaManager.hasRemoteStream;

    if (hasRemoteStreamNotifier == null) {
      // Fallback if not supported
      return ValueListenableBuilder<bool>(
        valueListenable: mediaManager.isRemoteVideoEnabled,
        builder: (ctx, remoteVideoEnabled, _) {
          if (!remoteVideoEnabled) {
            return RemoteVideoPlaceholder(
              displayName: widget.displayName,
              peerUser: widget.peerUser,
              hasStream: true,
              showConnecting: false,
              isRemoteAudioMuted: mediaManager.isRemoteAudioMuted,
            );
          }
          return _buildRemoteVideoWithMute();
        },
      );
    }

    // Listen to both hasRemoteStream and isRemoteVideoEnabled
    return ListenableBuilder(
      listenable: Listenable.merge([
        hasRemoteStreamNotifier,
        mediaManager.isRemoteVideoEnabled,
      ]),
      builder: (context, _) {
        final hasStream = hasRemoteStreamNotifier.value;
        final remoteVideoEnabled = mediaManager.isRemoteVideoEnabled.value;

        if (!hasStream || !remoteVideoEnabled) {
          return RemoteVideoPlaceholder(
            displayName: widget.displayName,
            peerUser: widget.peerUser,
            hasStream: hasStream,
            showConnecting: !hasStream,
            isRemoteAudioMuted: mediaManager.isRemoteAudioMuted,
          );
        }
        return _buildRemoteVideoWithMute();
      },
    );
  }

  Widget _buildRemoteVideoWithMute() {
    final mediaManager = widget.controller.mediaManager!;
    return Stack(
      children: [
        mediaManager.buildRemoteVideo(
          fit: BoxFit.cover,
          placeholderName: widget.displayName,
        ),
        if (mediaManager.isRemoteAudioMuted != null)
          Positioned(
            top: 16,
            left: 16,
            child: MuteIndicatorBadge(
              isMutedNotifier: mediaManager.isRemoteAudioMuted,
              style: MuteBadgeStyle.circleLarge,
            ),
          ),
      ],
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.background.withValues(alpha: 0.5),
                Colors.transparent,
                AppColors.background.withValues(alpha: 0.5),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPipLayer() {
    final size = MediaQuery.of(context).size;
    final position =
        _pipPosition ??
        Offset(
          size.width - CallRoomConstants.pipWidth - CallRoomConstants.pipMargin,
          64.0,
        );

    return PipVideoLayer(
      key: _pipLayerKey,
      mediaManager: widget.controller.mediaManager!,
      currentUser: widget.currentUser,
      peerUser: widget.peerUser,
      displayName: widget.displayName,
      position: position,
      swapVideos: _swapVideos,
      onPanUpdate: _onPipPan,
      onDoubleTap: _toggleSwapVideos,
    );
  }

  Widget _buildControls() {
    final manager = widget.controller.mediaManager;
    if (manager == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 50.0, end: 0.0),
        duration: CallRoomConstants.controlsAnimationDuration,
        curve: Curves.easeOut,
        builder: (context, offset, child) => Transform.translate(
          offset: Offset(0, offset),
          child: Opacity(opacity: (50.0 - offset) / 50.0, child: child),
        ),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            manager.isMuted,
            manager.isVideoEnabled,
            manager.isSpeakerOn,
          ]),
          builder: (ctx, _) {
            return CallControlButtons(
              onToggleMute: widget.controller.toggleMute,
              onToggleVideo: widget.controller.toggleVideo,
              onToggleSpeaker: widget.controller.toggleSpeaker,
              onEndCall: widget.controller.endCall,
              onFlipCamera: widget.controller.switchCamera,
              isMuted: manager.isMuted.value,
              isVideoEnabled: manager.isVideoEnabled.value,
              isSpeakerEnabled: manager.isSpeakerOn.value,
              isVideoCall: widget.controller.isVideo,
              isMinimized: false,
              onMinimize: widget.onMinimize,
              audioDeviceService: sl<AudioDeviceService>(),
            );
          },
        ),
      ),
    );
  }
}
