import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';

/// A simple avatar widget for displaying profile pictures or initials.
///
/// Use this for simple cases where you don't have a full User object.
/// For User objects, prefer [ProfilePictureWidget] which handles cache busting
/// and fallback URLs automatically.
///
/// Example:
/// ```dart
/// AvatarWidget(
///   imageUrl: 'https://example.com/avatar.jpg',
///   name: 'John Doe',
///   size: 40,
/// )
/// ```
class AvatarWidget extends StatelessWidget {
  /// The URL of the profile picture. If null or empty, shows initials.
  final String? imageUrl;

  /// The name to derive initials from when no image is available.
  final String name;

  /// The size (width and height) of the avatar.
  final double size;

  /// Optional callback when avatar is tapped.
  final VoidCallback? onTap;

  /// Whether to show a border around the avatar.
  final bool showBorder;

  /// Border color (defaults to AppColors.divider).
  final Color? borderColor;

  /// Border width.
  final double borderWidth;

  /// Background color for placeholder (defaults to AppColors.surfaceVariant).
  final Color? backgroundColor;

  /// Text color for initials (defaults to AppColors.textPrimary).
  final Color? textColor;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(
                  color: borderColor ?? AppColors.divider,
                  width: borderWidth,
                )
              : null,
        ),
        child: ClipOval(child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final initials = _getInitials(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTypography.headingMedium.copyWith(
            fontSize: size * 0.4,
            color: textColor ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// Extract initials from a name.
  /// Returns first letter of first name, or first two letters if single name.
  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      // First letter of first and last name
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else {
      // Single name - just first letter
      return parts.first[0].toUpperCase();
    }
  }
}
