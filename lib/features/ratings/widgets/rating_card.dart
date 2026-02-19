import 'package:flutter/material.dart';
import 'package:greenhive_app/features/ratings/data/models/rating.dart';
import 'package:greenhive_app/features/ratings/widgets/star_rating_input.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:intl/intl.dart';

/// Card widget that displays a single rating/review.
///
/// Shows the reviewer's name (or "Anonymous"), star rating,
/// date, and optional comment.
///
/// Usage:
/// ```dart
/// RatingCard(
///   rating: rating,
///   onTap: () => showRatingDetails(rating),
/// )
/// ```
class RatingCard extends StatelessWidget {
  /// The rating to display
  final Rating rating;

  /// Optional tap callback
  final VoidCallback? onTap;

  /// Padding around the card content
  final EdgeInsets padding;

  /// Whether to show the comment (if present)
  final bool showComment;

  const RatingCard({
    super.key,
    required this.rating,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.showComment = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name, rating, date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User avatar placeholder
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceVariant,
                  child: Text(
                    rating.displayName.isNotEmpty
                        ? rating.displayName[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name and date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.displayName,
                        style: AppTypography.bodyRegular.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(rating.createdAt),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Star rating
                StarRatingDisplay(
                  rating: rating.stars.toDouble(),
                  size: 16,
                ),
              ],
            ),

            // Comment (if present and enabled)
            if (showComment && rating.hasComment) ...[
              const SizedBox(height: 12),
              Text(
                rating.comment!,
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

/// Compact version of RatingCard for lists.
class RatingCardCompact extends StatelessWidget {
  final Rating rating;
  final VoidCallback? onTap;

  const RatingCardCompact({
    super.key,
    required this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // Stars
            StarRatingDisplay(
              rating: rating.stars.toDouble(),
              size: 14,
            ),
            const SizedBox(width: 12),

            // Name and comment preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rating.displayName,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (rating.hasComment)
                    Text(
                      rating.comment!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Date
            Text(
              _formatDateShort(rating.createdAt),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return '1d';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
