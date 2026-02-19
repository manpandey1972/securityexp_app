import 'package:flutter/material.dart';
import 'package:greenhive_app/features/ratings/widgets/star_rating_input.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

/// Widget that displays an expert's rating summary.
///
/// Shows the average rating, total number of reviews, and optional
/// rating distribution (bar chart).
///
/// Usage:
/// ```dart
/// ExpertRatingSummary(
///   averageRating: 4.5,
///   totalRatings: 42,
///   onTap: () => navigateToReviews(),
/// )
/// ```
class ExpertRatingSummary extends StatelessWidget {
  /// Average rating (0.0-5.0)
  final double averageRating;

  /// Total number of ratings
  final int totalRatings;

  /// Optional tap callback (e.g., to view all reviews)
  final VoidCallback? onTap;

  /// Size variant: 'compact', 'normal', or 'large'
  final String variant;

  /// Whether to show "No reviews yet" when totalRatings is 0
  final bool showEmptyState;

  const ExpertRatingSummary({
    super.key,
    required this.averageRating,
    required this.totalRatings,
    this.onTap,
    this.variant = 'normal',
    this.showEmptyState = true,
  });

  @override
  Widget build(BuildContext context) {
    // Handle no ratings case
    if (totalRatings == 0 && showEmptyState) {
      return _buildEmptyState();
    }

    if (totalRatings == 0) {
      return const SizedBox.shrink();
    }

    switch (variant) {
      case 'compact':
        return _buildCompact();
      case 'large':
        return _buildLarge();
      default:
        return _buildNormal();
    }
  }

  /// Compact variant: ★ 4.5/5 (42)
  Widget _buildCompact() {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            '${averageRating.toStringAsFixed(1)}/5',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($totalRatings)',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Normal variant: Stars + rating + count
  Widget _buildNormal() {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarRatingDisplay(
            rating: averageRating,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${averageRating.toStringAsFixed(1)}/5',
            style: AppTypography.bodyRegular.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($totalRatings ${totalRatings == 1 ? 'review' : 'reviews'})',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }

  /// Large variant: Big rating number with stars and count
  Widget _buildLarge() {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style: AppTypography.headingLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 48,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  '/5',
                  style: AppTypography.headingMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StarRatingDisplay(
            rating: averageRating,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'Based on $totalRatings ${totalRatings == 1 ? 'review' : 'reviews'}',
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state when no ratings
  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: variant == 'compact' ? 16 : 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            'No reviews yet',
            style: (variant == 'compact'
                    ? AppTypography.bodySmall
                    : AppTypography.bodyRegular)
                .copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline rating badge for expert cards.
///
/// Shows: ★ 4/5 (42) in a compact format.
class ExpertRatingBadge extends StatelessWidget {
  final double averageRating;
  final int totalRatings;

  const ExpertRatingBadge({
    super.key,
    required this.averageRating,
    required this.totalRatings,
  });

  @override
  Widget build(BuildContext context) {
    if (totalRatings == 0) {
      return const SizedBox.shrink();
    }

    // Round to nearest 0.5 for display purposes (e.g., 4.2 -> 4, 4.3 -> 4.5)
    final roundedRating = (averageRating * 2).round() / 2;
    final ratingInt = roundedRating.toInt();
    final hasHalf = roundedRating % 1 != 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          size: 14,
          color: AppColors.warning,
        ),
        const SizedBox(width: 4),
        Text(
          hasHalf ? '$ratingInt.${(roundedRating % 1 * 10).toInt()}/5' : '$ratingInt/5',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($totalRatings${totalRatings == 1 ? ' review' : ' reviews'})',
          style: AppTypography.captionSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
