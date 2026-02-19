import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_borders.dart';
import 'package:greenhive_app/shared/themes/app_spacing.dart';

/// Shimmer loading widgets for modern loading states
/// Provides reusable shimmer components that match app theme
class ShimmerLoading {
  ShimmerLoading._();

  /// Base shimmer wrapper with app theme colors
  static Widget shimmer({required Widget child, bool enabled = true}) {
    if (!enabled) return child;

    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceVariant,
      child: child,
    );
  }

  /// Shimmer for chat list items
  static Widget chatListItem() {
    return shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar placeholder
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: AppSpacing.spacing12),
            // Content placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: AppColors.white,
                  ),
                  SizedBox(height: AppSpacing.spacing8),
                  Container(height: 14, width: 200, color: AppColors.white),
                ],
              ),
            ),
            // Timestamp placeholder
            Container(height: 12, width: 40, color: AppColors.white),
          ],
        ),
      ),
    );
  }

  /// Shimmer for call history items
  static Widget callHistoryItem() {
    return shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar placeholder
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: AppSpacing.spacing12),
            // Content placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 150,
                    color: AppColors.white,
                  ),
                  SizedBox(height: AppSpacing.spacing8),
                  Container(height: 14, width: 100, color: AppColors.white),
                ],
              ),
            ),
            // Action buttons placeholder
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: AppSpacing.spacing8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shimmer for expert card
  static Widget expertCard() {
    return shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppBorders.borderRadiusNormal,
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              // Profile picture placeholder
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: AppSpacing.spacing12),
              // Content placeholder
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      color: AppColors.white,
                    ),
                    SizedBox(height: AppSpacing.spacing8),
                    Container(height: 14, width: 150, color: AppColors.white),
                  ],
                ),
              ),
              // Action buttons placeholder
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: AppSpacing.spacing16),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: AppSpacing.spacing16),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shimmer for product card
  static Widget productCard() {
    return shimmer(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppBorders.borderRadiusNormal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Container(
                height: 150,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      color: AppColors.white,
                    ),
                    SizedBox(height: AppSpacing.spacing8),
                    Container(height: 14, width: 100, color: AppColors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Generic shimmer list
  static Widget list({
    required int itemCount,
    required Widget Function() itemBuilder,
  }) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => itemBuilder(),
    );
  }

  /// Shimmer for rectangular content blocks
  static Widget rectangle({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return shimmer(
      child: Container(
        width: width,
        height: height ?? 16,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: borderRadius ?? AppBorders.borderRadiusXSmall,
        ),
      ),
    );
  }

  /// Shimmer for circular content (avatars, etc.)
  static Widget circle({double size = 48}) {
    return shimmer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
