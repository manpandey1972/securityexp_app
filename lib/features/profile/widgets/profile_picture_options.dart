import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';

/// Photo option widget for profile picture selection modal.
class CircularPhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const CircularPhotoOption({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              // Label
              Text(
                label,
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for profile picture options.
class ProfilePictureOptionsSheet extends StatelessWidget {
  final bool hasProfilePicture;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickImage;
  final VoidCallback onDeletePhoto;

  const ProfilePictureOptionsSheet({
    super.key,
    required this.hasProfilePicture,
    required this.onTakePhoto,
    required this.onPickImage,
    required this.onDeletePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Options row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Take Photo option (only on mobile)
                if (!kIsWeb)
                  CircularPhotoOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.info,
                    onTap: onTakePhoto,
                  ),
                // Choose Photo option
                CircularPhotoOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: AppColors.primary,
                  onTap: onPickImage,
                ),
                // Delete Photo option (only if profile has picture)
                if (hasProfilePicture)
                  CircularPhotoOption(
                    icon: Icons.delete_rounded,
                    label: 'Remove',
                    color: AppColors.error,
                    onTap: onDeletePhoto,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Show profile picture options modal
Future<void> showProfilePictureOptions({
  required BuildContext context,
  required bool hasProfilePicture,
  required VoidCallback onTakePhoto,
  required VoidCallback onPickImage,
  required VoidCallback onDeletePhoto,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProfilePictureOptionsSheet(
      hasProfilePicture: hasProfilePicture,
      onTakePhoto: () {
        Navigator.pop(ctx);
        onTakePhoto();
      },
      onPickImage: () {
        Navigator.pop(ctx);
        onPickImage();
      },
      onDeletePhoto: () {
        Navigator.pop(ctx);
        onDeletePhoto();
      },
    ),
  );
}
