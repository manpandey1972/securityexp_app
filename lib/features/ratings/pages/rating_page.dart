import 'package:flutter/material.dart';
import 'package:securityexperts_app/features/ratings/presentation/view_models/rating_view_model.dart';
import 'package:securityexperts_app/features/ratings/widgets/star_rating_input.dart';
import 'package:securityexperts_app/features/ratings/services/rating_service.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Page for submitting a rating for an expert.
///
/// Shows:
/// - Expert name
/// - Star rating input (1-5)
/// - Optional comment field (max 200 chars)
/// - Anonymous toggle
/// - Submit button
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => RatingPage(
///       expertId: 'expert123',
///       expertName: 'John Expert',
///       bookingId: 'call456',
///     ),
///   ),
/// );
/// ```
class RatingPage extends StatefulWidget {
  /// ID of the expert being rated
  final String expertId;

  /// Name of the expert (for display)
  final String expertName;

  /// ID of the booking/session being rated
  final String bookingId;

  /// Optional session date (for display)
  final DateTime? sessionDate;

  /// Callback when rating is submitted successfully
  final VoidCallback? onRatingSubmitted;

  const RatingPage({
    super.key,
    required this.expertId,
    required this.expertName,
    required this.bookingId,
    this.sessionDate,
    this.onRatingSubmitted,
  });

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  late final RatingViewModel _viewModel;
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();

  static const int _maxCommentLength = 200;

  @override
  void initState() {
    super.initState();
    _viewModel = RatingViewModel(ratingService: sl<RatingService>());
    _viewModel.initialize(
      expertId: widget.expertId,
      expertName: widget.expertName,
      bookingId: widget.bookingId,
    );
    _viewModel.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onStateChanged);
    _viewModel.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});

    // Show error snackbar
    if (_viewModel.state.errorMessage != null) {
      SnackbarService.show(_viewModel.state.errorMessage!);
      _viewModel.clearError();
    }
  }

  Future<void> _handleSubmit() async {
    // Unfocus comment field
    _commentFocusNode.unfocus();

    final success = await _viewModel.submitRating();

    if (success && mounted) {
      SnackbarService.show('Thank you for your feedback!');
      widget.onRatingSubmitted?.call();
      Navigator.of(context).pop(true); // Return true to indicate success
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _viewModel.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Expert'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Expert name
            Text(
              'How was your session with',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.expertName,
              style: AppTypography.headingMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Session date (if provided)
            if (widget.sessionDate != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(widget.sessionDate!),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Star rating
            Text(
              'Tap to rate',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            StarRatingInput(
              rating: state.selectedStars,
              onRatingChanged: _viewModel.setStars,
              size: 48,
              enabled: !state.isLoading && !state.isSubmitted,
            ),

            // Rating label
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _getRatingLabel(state.selectedStars),
                key: ValueKey(state.selectedStars),
                style: AppTypography.bodyRegular.copyWith(
                  color: state.selectedStars > 0
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Comment field
            TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              maxLength: _maxCommentLength,
              maxLines: 4,
              enabled: !state.isLoading && !state.isSubmitted,
              decoration: InputDecoration(
                hintText: 'Share your experience (optional)',
                hintStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1,
                  ),
                ),
                counterStyle: TextStyle(color: AppColors.textMuted),
              ),
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textPrimary,
              ),
              onChanged: _viewModel.setComment,
            ),

            const SizedBox(height: 16),

            // Anonymous toggle
            InkWell(
              onTap: !state.isLoading && !state.isSubmitted
                  ? () => _viewModel.setAnonymous(!state.isAnonymous)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: state.isAnonymous,
                      onChanged: !state.isLoading && !state.isSubmitted
                          ? (value) => _viewModel.setAnonymous(value ?? false)
                          : null,
                      activeColor: AppColors.primary,
                    ),
                    Expanded(
                      child: Text(
                        'Submit anonymously',
                        style: AppTypography.bodyRegular.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: state.canSubmit ? _handleSubmit : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  disabledForegroundColor: AppColors.textMuted,
                  side: BorderSide(
                    color: state.canSubmit ? AppColors.primary : AppColors.textMuted,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      )
                    : Text(
                        'Submit Rating',
                        style: AppTypography.bodyEmphasis,
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Skip button
            if (!state.isSubmitted)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Maybe later',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(int stars) {
    switch (stars) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
