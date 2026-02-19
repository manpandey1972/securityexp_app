import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_spacing.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/shared/widgets/profanity_filtered_text_field.dart';
import 'package:securityexperts_app/features/chat/widgets/camera_widgets.dart';

class ChatInputConstants {
  static const double inputPadding = AppSpacing.spacing8;
  static const double iconButtonSize = 48.0;
  static const double iconSize = 28.0;
}

/// Reusable message input component with recording and attachment support
class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final ValueNotifier<bool> hasTextNotifier;
  final ValueNotifier<bool> showAttachmentSheetNotifier;
  final ValueNotifier<Duration> recordingDuration;
  final VoidCallback onAttachmentTap;
  final VoidCallback onSendTap;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final Future<void> Function(String filePath, List<int> bytes, String fileName)
  onCameraCapture;
  final bool isRecording;
  final bool isRecordingStopped;
  final Widget? replyPreviewBar;
  final Function(bool)? attachmentSheetBuilder;

  // ignore: prefer_const_constructors_in_immutables
  ChatInputWidget({
    super.key,
    required this.controller,
    required this.hasTextNotifier,
    required this.showAttachmentSheetNotifier,
    required this.recordingDuration,
    required this.onAttachmentTap,
    required this.onSendTap,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCameraCapture,
    required this.isRecording,
    required this.isRecordingStopped,
    this.replyPreviewBar,
    this.attachmentSheetBuilder,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview bar
          if (widget.replyPreviewBar != null) widget.replyPreviewBar!,
          // Input row with buttons (hide when recording or in preview)
          if (!widget.isRecording && !widget.isRecordingStopped)
            Padding(
              padding: const EdgeInsets.all(ChatInputConstants.inputPadding),
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.hasTextNotifier,
                builder: (context, hasText, child) {
                  return Row(
                    children: [
                      // Attachment button
                      IconButton(
                        onPressed: widget.onAttachmentTap,
                        icon: const Icon(Icons.add),
                        iconSize: ChatInputConstants.iconSize,
                        tooltip: 'Attach',
                      ),
                      // Text input field
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 8.0),
                          child: ProfanityFilteredTextField(
                            controller: widget.controller,
                            context: 'chat',
                            decoration: const InputDecoration(
                              hintText: 'Type a message',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
                              ),
                            ),
                            textInputAction: TextInputAction.newline,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                          ),
                        ),
                      ),
                      // Send button or media buttons
                      if (hasText)
                        IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: AppColors.primaryLight,
                          ),
                          iconSize: ChatInputConstants.iconSize,
                          onPressed: widget.onSendTap,
                          tooltip: 'Send',
                        ),
                      // Camera and microphone buttons (hidden when typing)
                      if (!kIsWeb && !hasText) ...[
                        IconButton(
                          icon: const Icon(Icons.camera_alt),
                          iconSize: ChatInputConstants.iconSize,
                          onPressed: _handleCameraCapture,
                          tooltip: 'Camera',
                        ),
                        IconButton(
                          onPressed: widget.onStartRecording,
                          icon: const Icon(Icons.mic),
                          iconSize: ChatInputConstants.iconSize,
                          tooltip: 'Record audio',
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          // Attachment sheet
          ValueListenableBuilder<bool>(
            valueListenable: widget.showAttachmentSheetNotifier,
            builder: (context, showSheet, _) {
              if (widget.attachmentSheetBuilder == null) {
                return const SizedBox.shrink();
              }
              return widget.attachmentSheetBuilder!(showSheet);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleCameraCapture() async {
    try {
      // Request camera permission
      final cameraPermission = await Permission.camera.request();

      if (cameraPermission.isDenied) {
        if (mounted) {
          SnackbarService.show('Camera permission is required');
        }
        return;
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          SnackbarService.show('No camera available');
        }
        return;
      }

      // Open live camera screen
      if (!mounted) return;
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveCameraScreen(
              cameras: cameras,
              onPhotoCapture: (file) async {
                final bytes = await file.readAsBytes();
                await widget.onCameraCapture(file.path, bytes, file.name);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.show('Failed to open camera: $e');
      }
    }
  }
}
