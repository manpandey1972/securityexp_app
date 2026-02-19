import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/shared/services/upload_manager.dart';
import 'package:securityexperts_app/shared/services/media_confirmation_dialog_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Handles media-related operations in chat (file picking, uploading, audio confirmation)
///
/// Uses [UploadManager] for background uploads that survive navigation.
class ChatMediaHandler {
  final UploadManager _uploadManager;
  final String roomId;
  final Message? Function() getReplyToMessage;
  final Function() clearReply;

  ChatMediaHandler({
    UploadManager? uploadManager,
    required this.roomId,
    required this.getReplyToMessage,
    required this.clearReply,
  }) : _uploadManager = uploadManager ?? sl<UploadManager>();

  /// Pick and upload files (documents) - supports multiple selection
  Future<void> handleAttachFile({required BuildContext context}) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;

    // Upload all selected files
    for (final f in result.files) {
      final String? filePath = kIsWeb ? null : f.path;
      await _startUpload(filePath: filePath, bytes: f.bytes, filename: f.name);
    }
  }

  /// Pick and upload media (images/videos) - supports multiple selection
  Future<void> handleAttachMedia({required BuildContext context}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;

    // Upload all selected files
    for (final f in result.files) {
      final String? filePath = kIsWeb ? null : f.path;
      await _startUpload(filePath: filePath, bytes: f.bytes, filename: f.name);
    }
  }

  /// Show audio confirmation dialog and upload if confirmed
  Future<void> showAudioConfirmationDialog({
    required BuildContext context,
    required File audioFile,
  }) async {
    if (!context.mounted) return;

    final confirmed =
        await MediaConfirmationDialogService.showAudioConfirmationDialog(
          context,
          audioFile,
        );

    if (confirmed && context.mounted) {
      await _startUpload(
        filePath: audioFile.path,
        bytes: null,
        filename: audioFile.path.split('/').last,
      );
    }
  }

  /// Handle audio file - upload directly without confirmation
  Future<void> handleAudioFile({
    required File audioFile,
  }) async {
    await _startUpload(
      filePath: audioFile.path,
      bytes: null,
      filename: audioFile.path.split('/').last,
    );
  }

  /// Handle camera capture - uploads captured photo/video directly
  Future<void> handleCameraCapture({
    required BuildContext context,
    required String? filePath,
    required List<int> bytes,
    required String filename,
  }) async {
    await _startUpload(
      filePath: filePath,
      bytes: Uint8List.fromList(bytes),
      filename: filename,
    );
  }

  /// Start upload using UploadManager
  /// Returns immediately - upload continues in background
  Future<void> _startUpload({
    required String? filePath,
    required Uint8List? bytes,
    required String filename,
  }) async {
    await _uploadManager.startUpload(
      roomId: roomId,
      filePath: filePath,
      bytes: bytes,
      filename: filename,
      replyToMessage: getReplyToMessage(),
    );
    // Clear reply after starting upload
    clearReply();
  }
}
