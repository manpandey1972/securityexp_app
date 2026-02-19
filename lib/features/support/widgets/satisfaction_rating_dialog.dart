import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

/// Dialog for rating support experience.
///
/// Shows after ticket is resolved to collect user feedback.
class SatisfactionRatingDialog extends StatelessWidget {
  /// Currently selected rating (1-5).
  final int? selectedRating;

  /// Feedback comment.
  final String comment;

  /// Callback when rating changes.
  final ValueChanged<int> onRatingChanged;

  /// Callback when comment changes.
  final ValueChanged<String> onCommentChanged;

  /// Callback when submit is pressed.
  final VoidCallback onSubmit;

  /// Callback when dialog is dismissed.
  final VoidCallback onDismiss;

  /// Whether submitting is in progress.
  final bool isSubmitting;

  const SatisfactionRatingDialog({
    super.key,
    this.selectedRating,
    this.comment = '',
    required this.onRatingChanged,
    required this.onCommentChanged,
    required this.onSubmit,
    required this.onDismiss,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Rate Your Experience',
              style: AppTypography.headingSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How was your support experience?',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final rating = index + 1;
                final isSelected =
                    selectedRating != null && rating <= selectedRating!;
                return GestureDetector(
                  onTap: () => onRatingChanged(rating),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedScale(
                      scale: isSelected ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        isSelected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: isSelected ? AppColors.ratingStar : AppColors.textMuted,
                        size: 40,
                      ),
                    ),
                  ),
                );
              }),
            ),

            // Rating label
            const SizedBox(height: 8),
            Text(
              _getRatingLabel(),
              style: AppTypography.bodySmall.copyWith(
                color: selectedRating != null
                    ? AppColors.ratingStar
                    : AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Comment field
            TextField(
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Additional feedback (optional)',
                hintStyle: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: AppTypography.bodyRegular,
              onChanged: onCommentChanged,
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSubmitting ? null : onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Maybe Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedRating != null && !isSubmitting
                        ? onSubmit
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          )
                        : Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel() {
    switch (selectedRating) {
      case 1:
        return 'Very Unsatisfied';
      case 2:
        return 'Unsatisfied';
      case 3:
        return 'Neutral';
      case 4:
        return 'Satisfied';
      case 5:
        return 'Very Satisfied';
      default:
        return 'Tap to rate';
    }
  }
}
