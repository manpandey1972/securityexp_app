/// Expert Rating System
///
/// A complete rating system for users to rate experts after sessions.
///
/// ## Features
/// - 1-5 star rating with optional comment
/// - Anonymous rating option
/// - Duplicate prevention per booking/session
/// - Rating display on expert profiles
/// - Cloud Function for rating aggregation
///
/// ## Usage
///
/// ### Submitting a Rating
/// ```dart
/// import 'package:greenhive_app/features/ratings/ratings.dart';
///
/// // Submit a rating
/// final result = await sl<RatingService>().submitRating(
///   expertId: 'expert123',
///   expertName: 'John Expert',
///   bookingId: 'call456',
///   stars: 5,
///   comment: 'Great session!',
/// );
///
/// if (result.isSuccess) {
///   print('Rating submitted: ${result.value}');
/// }
/// ```
///
/// ### Displaying Ratings
/// ```dart
/// // Show rating summary on expert profile
/// ExpertRatingSummary(
///   averageRating: 4.5,
///   totalRatings: 42,
///   onTap: () => navigateToReviews(),
/// )
///
/// // Show rating badge on expert card
/// ExpertRatingBadge(
///   averageRating: 4.5,
///   totalRatings: 42,
/// )
/// ```
///
/// ### Post-Call Rating Prompt
/// ```dart
/// // Show rating dialog after call ends
/// PostCallRatingPrompt.showIfEligible(
///   context: context,
///   expertId: 'expert123',
///   expertName: 'John Expert',
///   callId: 'call456',
///   callDurationSeconds: 300,
/// );
/// ```
library;

// Models
export 'data/models/models.dart';

// Repository
export 'data/repositories/rating_repository.dart';

// Service
export 'services/rating_service.dart';

// ViewModels
export 'presentation/view_models/rating_view_model.dart';
export 'presentation/view_models/expert_reviews_view_model.dart';

// Pages
export 'pages/rating_page.dart';
export 'pages/expert_reviews_page.dart';

// Widgets
export 'widgets/star_rating_input.dart';
export 'widgets/rating_card.dart';
export 'widgets/expert_rating_summary.dart';

// Utilities
export 'utils/post_call_rating_prompt.dart';
