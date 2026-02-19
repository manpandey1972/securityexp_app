import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/media_confirmation_dialog_service.dart';
import 'package:securityexperts_app/shared/services/media_audio_session_helper.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'dart:async';

class LiveCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(XFile) onPhotoCapture;

  const LiveCameraScreen({
    super.key,
    required this.cameras,
    required this.onPhotoCapture,
  });

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isVideoMode = false;
  bool _isRecording = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  int _selectedCameraIndex = 0;
  // Video recording timer
  Timer? _videoRecordingTimer;
  Duration _videoDuration = Duration.zero;

  static const String _tag = 'LiveCameraScreen';
  final AppLogger _log = sl<AppLogger>();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Configure audio session for media playback (speaker output)
      await MediaAudioSessionHelper.configureForMediaPlayback();
      
      final controller = CameraController(
        widget.cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: _isVideoMode,
      );
      await controller.initialize();
      if (mounted) {
        _cameraController = controller;
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = (await controller.getMaxZoomLevel()).clamp(
          15.0,
          double.infinity,
        );
        _currentZoom = _minZoom;
        setState(() {
          _isCameraInitialized = true;
        });
      } else {
        // Dispose if widget is no longer mounted
        await controller.dispose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  bool _isFlipping = false;

  Future<void> _flipCamera() async {
    if (widget.cameras.length < 2) return;
    if (_isFlipping) return; // Prevent multiple flips at once
    if (_cameraController == null) return;
    
    _isFlipping = true;
    
    try {
      // Stop any ongoing recording
      if (_isRecording) {
        _videoRecordingTimer?.cancel();
        _videoRecordingTimer = null;
        await _cameraController?.stopVideoRecording();
        if (mounted) setState(() => _isRecording = false);
      }
      
      // Find the other camera (front vs back)
      final currentLensDirection = widget.cameras[_selectedCameraIndex].lensDirection;
      int newIndex = _selectedCameraIndex;
      
      for (int i = 0; i < widget.cameras.length; i++) {
        if (widget.cameras[i].lensDirection != currentLensDirection) {
          newIndex = i;
          break;
        }
      }
      
      // If no different camera found, cycle through
      if (newIndex == _selectedCameraIndex) {
        newIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
      }
      
      _selectedCameraIndex = newIndex;
      
      // Dispose old controller
      await _cameraController?.dispose();
      
      // Configure audio session for media playback
      await MediaAudioSessionHelper.configureForMediaPlayback();
      
      // Create and initialize new controller
      final newController = CameraController(
        widget.cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: _isVideoMode,
      );
      
      await newController.initialize();
      
      if (mounted) {
        _cameraController = newController;
        _minZoom = await newController.getMinZoomLevel();
        _maxZoom = (await newController.getMaxZoomLevel()).clamp(
          15.0,
          double.infinity,
        );
        _currentZoom = _minZoom;
        setState(() {});
      } else {
        await newController.dispose();
      }
    } catch (e) {
      _log.error('Error flipping camera: $e', tag: _tag);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error flipping camera: $e')),
        );
      }
    } finally {
      _isFlipping = false;
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null) return;
    try {
      final image = await _cameraController!.takePicture();
      if (mounted) {
        await _showPhotoPreviewDialog(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
      }
    }
  }

  Future<void> _showPhotoPreviewDialog(XFile photoFile) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Photo Preview',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.normal),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(photoFile.path),
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        actions: [
          AppButtonVariants.dialogDestructive(
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                await File(photoFile.path).delete();
              } catch (e) {
                _log.error('Failed to delete photo file: $e', tag: _tag);
              }
              if (mounted) {
                navigator.pop();
                SnackbarService.show('Photo discarded');
              }
            },
            label: 'Discard',
          ),
          AppButtonVariants.dialogConfirm(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator
                  .pop(); // Close camera screen (using navigator context captured before async)
              await widget.onPhotoCapture(photoFile);
            },
            label: 'Send',
          ),
        ],
      ),
    );
  }

  Future<void> _toggleVideoRecording() async {
    final controller = _cameraController;
    if (controller == null || !_isCameraInitialized) return;
    
    try {
      if (_isRecording) {
        _videoRecordingTimer?.cancel();
        _videoRecordingTimer = null;

        final video = await controller.stopVideoRecording();
        if (mounted) {
          setState(() => _isRecording = false);
          await _showVideoPreviewDialog(video);
        }
      } else {
        await controller.startVideoRecording();

        // Start video recording timer
        _videoDuration = Duration.zero;
        _videoRecordingTimer?.cancel();
        _videoRecordingTimer = Timer.periodic(
          const Duration(milliseconds: 100),
          (timer) {
            if (mounted) {
              setState(() {
                _videoDuration += const Duration(milliseconds: 100);
              });
            }
          },
        );

        if (mounted) {
          setState(() => _isRecording = true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error with video: $e')));
      }
    }
  }

  Future<void> _showVideoPreviewDialog(XFile videoFile) async {
    final confirmed =
        await MediaConfirmationDialogService.showVideoConfirmationDialog(
          context,
          File(videoFile.path),
          _videoDuration,
        );

    if (confirmed && mounted) {
      Navigator.of(context).pop(); // Close camera screen
      await widget.onPhotoCapture(videoFile);
    }
  }

  Future<void> _switchMode(bool toVideoMode) async {
    try {
      _videoRecordingTimer?.cancel();
      _videoRecordingTimer = null;

      await _cameraController?.dispose();
      
      // Configure audio session for media playback
      await MediaAudioSessionHelper.configureForMediaPlayback();
      
      final controller = CameraController(
        widget.cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: toVideoMode,
      );
      _cameraController = controller;
      await controller.initialize();
      if (mounted) {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = (await controller.getMaxZoomLevel()).clamp(
          15.0,
          double.infinity,
        );
        _currentZoom = _minZoom;
        _isCameraInitialized = true;
        setState(() => _isVideoMode = toVideoMode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error switching mode: $e')));
      }
    }
  }

  Future<void> _setZoom(double zoom) async {
    final controller = _cameraController;
    if (controller == null || !_isCameraInitialized) return;
    
    try {
      // Clamp zoom between min and max, with max capped at 15x
      final maxZoom = _maxZoom > 15.0 ? 15.0 : _maxZoom;
      final clampedZoom = zoom.clamp(_minZoom, maxZoom);
      await controller.setZoomLevel(clampedZoom);
      if (mounted) {
        setState(() => _currentZoom = clampedZoom);
      }
    } catch (e) {
      _log.error('Zoom error: $e', tag: _tag);
    }
  }

  /// Build a control button similar to call page buttons
  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required bool isActive,
    String? tooltip,
  }) {
    // Special color for recording state
    final bool isRecordingButton = icon == Icons.stop;
    final buttonColor = isRecordingButton
        ? AppColors.error
        : (isActive 
            ? AppColors.info
            : AppColors.surface.withValues(alpha: 0.7));
    final shadowColor = isRecordingButton
        ? AppColors.error
        : AppColors.info;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
          boxShadow: (isActive || isRecordingButton)
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            icon,
            color: AppColors.white,
            size: AppIconSizes.large,
          ),
        ),
      ),
    );
  }

  /// Build the capture/record button with white circle design
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isVideoMode ? _toggleVideoRecording : _capturePhoto,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _isRecording ? AppColors.error : AppColors.white,
          shape: BoxShape.circle,
          boxShadow: _isRecording
              ? [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoRecordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final controller = _cameraController!;
    final screenSize = MediaQuery.of(context).size;
    final previewSize = controller.value.previewSize!;
    
    // Camera preview is in landscape, phone is portrait
    // So we need to calculate scale to fill the screen
    final cameraAspectRatio = previewSize.height / previewSize.width;
    final screenAspectRatio = screenSize.width / screenSize.height;
    
    // Calculate scale to fill screen (cover mode)
    double scale;
    if (cameraAspectRatio > screenAspectRatio) {
      scale = screenSize.height / (screenSize.width / cameraAspectRatio);
    } else {
      scale = screenSize.width / (screenSize.height * cameraAspectRatio);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live camera preview - properly scaled to fill screen
          Center(
            child: GestureDetector(
              onScaleUpdate: (details) {
                // Pinch zoom gesture - slow down by reducing scale sensitivity
                final scaleFactor = 1.0 + (details.scale - 1.0) * 0.1;
                _setZoom(_currentZoom * scaleFactor);
              },
              child: Transform.scale(
                scale: scale,
                child: CameraPreview(controller),
              ),
            ),
          ),

          // Top bar with close button and zoom indicator
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.white,
                        size: AppIconSizes.large,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (_isRecording && _isVideoMode)
                      // Recording indicator with timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'REC ${_videoDuration.inMinutes}:${(_videoDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      if (_currentZoom > 1.0)
                        Text(
                          'Zoom: ${_currentZoom.toStringAsFixed(1)}x',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    const SizedBox(width: 48), // Placeholder for balance
                  ],
                ),
              ),
            ),
          ),

          // Bottom control panel - positioned at absolute bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.54),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flip camera button (only if multiple cameras available)
                      if (widget.cameras.length > 1)
                        _buildControlButton(
                          onPressed: _flipCamera,
                          icon: Icons.flip_camera_ios,
                          isActive: false,
                          tooltip: 'Flip camera',
                        )
                      else
                        const SizedBox(width: 56),
                      const SizedBox(width: 16),
                      // Photo/Video mode toggle button
                      _buildControlButton(
                        onPressed: () => _switchMode(!_isVideoMode),
                        icon: _isVideoMode ? Icons.videocam : Icons.camera_alt,
                        isActive: false,
                        tooltip: _isVideoMode ? 'Video mode' : 'Photo mode',
                      ),
                      const SizedBox(width: 16),
                      // Capture/Record button
                      _buildCaptureButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
