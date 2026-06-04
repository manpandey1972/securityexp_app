import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
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
  ///
  /// Uses [ImagePicker] instead of [FilePicker] so that Android opens the
  /// native Photos / Gallery picker (matching iOS behavior). `file_picker`
  /// with `FileType.media` falls back to the Storage Access Framework
  /// document UI on Android, which is the same surface used for documents
  /// and is not the desired experience for the "Photos" action.
  Future<void> handleAttachMedia({required BuildContext context}) async {
    debugPrint('[ChatMediaHandler] handleAttachMedia: opening ImagePicker.pickMultipleMedia');
    _enableAndroidPhotoPicker();
    final picker = ImagePicker();
    final List<XFile> files = await picker.pickMultipleMedia();
    debugPrint('[ChatMediaHandler] handleAttachMedia: picked ${files.length} files');
    if (files.isEmpty) return;

    for (final f in files) {
      final String? filePath = kIsWeb ? null : f.path;
      final Uint8List? bytes = kIsWeb ? await f.readAsBytes() : null;
      await _startUpload(filePath: filePath, bytes: bytes, filename: f.name);
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

  /// Opt in to Android's system Photo Picker for [ImagePicker] calls.
  ///
  /// `image_picker_android` defaults to the legacy `ACTION_GET_CONTENT` intent
  /// (which surfaces the SAF / Files / Downloads UI). Setting this flag
  /// switches it to `PickVisualMedia` on Android 13+ so the native Photo
  /// Picker is shown — matching the iOS Photos picker UX.
  static bool _photoPickerEnabled = false;
  void _enableAndroidPhotoPicker() {
    if (_photoPickerEnabled || kIsWeb || !Platform.isAndroid) return;
    final platform = ImagePickerPlatform.instance;
    if (platform is ImagePickerAndroid) {
      platform.useAndroidPhotoPicker = true;
      _photoPickerEnabled = true;
      debugPrint('[ChatMediaHandler] Enabled Android system Photo Picker');
    }
  }
}
