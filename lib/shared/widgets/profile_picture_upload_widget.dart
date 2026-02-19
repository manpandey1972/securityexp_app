import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:securityexperts_app/features/profile/services/profile_picture_service.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

class ProfilePictureUploadWidget extends StatefulWidget {
  final String userId;
  final Function(String)? onUploadSuccess;
  final Function()? onDeleteSuccess;

  const ProfilePictureUploadWidget({
    super.key,
    required this.userId,
    this.onUploadSuccess,
    this.onDeleteSuccess,
  });

  @override
  State<ProfilePictureUploadWidget> createState() =>
      _ProfilePictureUploadWidgetState();
}

class _ProfilePictureUploadWidgetState
    extends State<ProfilePictureUploadWidget> {
  late final ProfilePictureService _service;
  bool _isUploading = false;
  final _log = sl<AppLogger>();
  static const _tag = 'ProfilePictureUploadWidget';

  @override
  void initState() {
    super.initState();
    _service = sl<ProfilePictureService>();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Camera icon button in a round circle
        GestureDetector(
          onTap: _isUploading ? null : _showEditMenu,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isUploading
                  ? AppColors.surfaceVariant
                  : AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: _isUploading
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Icon(
                    Icons.camera_alt,
                    color: AppColors.textPrimary,
                    size: AppIconSizes.medium,
                  ),
          ),
        ),
        if (_isUploading)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Uploading...',
              style: AppTypography.captionSmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  void _showEditMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Edit Profile Picture',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const Divider(),
              // Take Photo - only on mobile
              if (!kIsWeb)
                ListTile(
                  title: const Text('Take Photo'),
                  trailing: const Icon(
                    Icons.camera_alt,
                    color: AppColors.info,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
              // Choose Photo
              ListTile(
                title: const Text('Choose Photo'),
                trailing: const Icon(Icons.image, color: AppColors.primary),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              // Delete Photo
              ListTile(
                title: Text(
                  'Delete Photo',
                  style: AppTypography.bodyRegular.copyWith(color: AppColors.error),
                ),
                trailing: const Icon(Icons.delete, color: AppColors.error),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfilePicture();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    final imageFile = await _service.takePhotoWithCamera();
    if (imageFile != null) {
      _uploadImage(imageFile);
    }
  }

  Future<void> _pickImage() async {
    final imageFile = await _service.pickImageFromGallery();
    if (imageFile != null) {
      _uploadImage(imageFile);
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        setState(() => _isUploading = true);

        final downloadUrl = await _service.uploadProfilePicture(
          widget.userId,
          imageFile,
        );

        if (!mounted) return;
        SnackbarService.show('Profile picture updated successfully');
        widget.onUploadSuccess?.call(downloadUrl ?? '');
      },
      onError: (error) {
        if (!mounted) return;
        SnackbarService.show('Failed to upload picture: $error');
        _log.error('Upload error: $error', tag: _tag);
      },
    );

    if (mounted) {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteProfilePicture() async {
    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Profile Picture?',
          style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete your profile picture?',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.bodyRegular.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: AppTypography.bodyRegular.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isUploading = true);

      final firestore = FirestoreInstance().db;

      if (widget.userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      // Update Firestore to remove profile picture
      await firestore.collection('users').doc(widget.userId).update({
        'hasProfilePicture': false,
        'profilePictureUrl': FieldValue.delete(),
        'profilePictureUpdatedAt': FieldValue.delete(),
      });

      if (!mounted) return;
      SnackbarService.show('Profile picture deleted successfully');
      widget.onDeleteSuccess?.call();
    } catch (e, stackTrace) {
      if (!mounted) return;
      SnackbarService.show('Failed to delete picture: $e');
      _log.error('Delete error: $e', tag: _tag, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}
