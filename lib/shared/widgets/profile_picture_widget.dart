import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/core/service_locator.dart';

class ProfilePictureWidget extends StatelessWidget {
  final User user;
  final double size;
  final Function()? onTap;
  final bool showBorder;
  final String
  variant; // 'thumbnail' for UI elements, 'display' for profile view

  const ProfilePictureWidget({
    super.key,
    required this.user,
    this.size = 80,
    this.onTap,
    this.showBorder = true,
    this.variant = 'display',
  });

  @override
  Widget build(BuildContext context) {
    // Get the latest cached user data instead of using stale prop
    final userCache = sl<UserCacheService>();
    final cachedUser = userCache.get(user.id) ?? user;

    return StreamBuilder<User>(
      stream: userCache.getUserStream(user.id),
      initialData: cachedUser,
      builder: (context, snapshot) {
        final currentUser = snapshot.data ?? cachedUser;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: showBorder
                  ? Border.all(color: AppColors.divider, width: 2)
                  : null,
            ),
            child: ClipOval(child: _buildProfilePicture(currentUser)),
          ),
        );
      },
    );
  }

  Widget _buildProfilePicture(User currentUser) {
    // Show profile picture if we have a valid URL (contains auth token)
    final imageUrl = currentUser.profilePictureUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      String cacheKey = '${currentUser.id}_profile_picture_$variant';
      if (currentUser.profilePictureUpdatedAt != null) {
        final timestamp =
            currentUser.profilePictureUpdatedAt!.millisecondsSinceEpoch;
        cacheKey = '${currentUser.id}_profile_picture_${variant}_$timestamp';
      }

      return CachedNetworkImage(
        key: ValueKey(cacheKey),
        imageUrl: imageUrl,
        cacheKey: cacheKey,
        httpHeaders: {'Accept': 'image/*'},
        imageBuilder: (context, imageProvider) {
          return SizedBox.expand(
            child: Image(image: imageProvider, fit: BoxFit.cover),
          );
        },
        placeholder: (context, url) => _buildPlaceholder(currentUser),
        errorWidget: (context, url, error) {
          return _buildPlaceholder(currentUser);
        },
      );
    }

    // No URL yet - show placeholder (StreamBuilder will update when cache populates)
    return _buildPlaceholder(currentUser);
  }

  Widget _buildPlaceholder(User currentUser) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.surfaceVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          currentUser.name.isNotEmpty ? currentUser.name[0].toUpperCase() : '?',
          style: AppTypography.headingLarge.copyWith(
            fontSize: size * 0.4,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
