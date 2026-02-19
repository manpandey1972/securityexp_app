import 'package:firebase_auth/firebase_auth.dart';
import 'package:greenhive_app/features/ratings/data/models/rating.dart';
import 'package:greenhive_app/features/ratings/data/repositories/rating_repository.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/shared/services/user_profile_service.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
// ============================================================================
// Error Types
// ============================================================================

/// Errors that can occur during rating operations
enum RatingError {
  notAuthenticated,
  invalidStars,
  commentTooLong,
  alreadyRated,
  cannotRateSelf,
  targetNotExpert,
  expertNotFound,
  submissionFailed,
  unknown;

  String get message {
    switch (this) {
      case RatingError.notAuthenticated:
        return 'Please sign in to rate this expert';
      case RatingError.invalidStars:
        return 'Rating must be between 1 and 5 stars';
      case RatingError.commentTooLong:
        return 'Comment must be 200 characters or less';
      case RatingError.alreadyRated:
        return 'You have already rated this session';
      case RatingError.cannotRateSelf:
        return 'You cannot rate yourself';
      case RatingError.targetNotExpert:
        return 'Ratings can only be given to experts';
      case RatingError.expertNotFound:
        return 'Expert not found';
      case RatingError.submissionFailed:
        return 'Failed to submit rating. Please try again';
      case RatingError.unknown:
        return 'An unexpected error occurred';
    }
  }
}

/// Result wrapper for rating operations
class RatingResult<T> {
  final T? value;
  final RatingError? error;

  const RatingResult._({this.value, this.error});

  factory RatingResult.success(T value) => RatingResult._(value: value);
  factory RatingResult.failure(RatingError error) =>
      RatingResult._(error: error);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

// ============================================================================
// Rating Service
// ============================================================================

/// Service for managing expert ratings.
///
/// Provides high-level operations for rating experts, including
/// validation, duplicate prevention, and error handling.
///
/// Usage:
/// ```dart
/// final service = sl<RatingService>();
///
/// // Submit a rating
/// final result = await service.submitRating(
///   expertId: 'expert123',
///   expertName: 'John Expert',
///   bookingId: 'call456',
///   stars: 5,
///   comment: 'Great session!',
/// );
///
/// if (result.isSuccess) {
///   print('Rating submitted: ${result.value}');
/// } else {
///   print('Error: ${result.error?.message}');
/// }
/// ```
class RatingService {
  final RatingRepository _repository;
  final AppLogger _log;

  static const String _tag = 'RatingService';
  static const int maxCommentLength = 200;

  RatingService({
    required RatingRepository repository,
    required AppLogger log,
  })  : _repository = repository,
        _log = log;

  // ============= Submission =============

  /// Submits a rating for an expert.
  ///
  /// Validates the input and prevents duplicate ratings per booking.
  Future<RatingResult<Rating>> submitRating({
    required String expertId,
    required String expertName,
    required String bookingId,
    required int stars,
    String? comment,
    bool isAnonymous = false,
  }) async {
    _log.info(
      'Submitting rating: expertId=$expertId, stars=$stars, bookingId=$bookingId',
      tag: _tag,
    );

    // 1. Validate authentication
    final userId = _getCurrentUserId();
    if (userId == null) {
      _log.warning('Rating submission failed: not authenticated', tag: _tag);
      return RatingResult.failure(RatingError.notAuthenticated);
    }

    // 2. Prevent self-rating
    if (userId == expertId) {
      _log.warning('Rating submission failed: cannot rate yourself', tag: _tag);
      return RatingResult.failure(RatingError.cannotRateSelf);
    }

    // 3. Verify target user has Expert role
    try {
      final expertDoc = await FirestoreInstance()
          .db
          .collection('users')
          .doc(expertId)
          .get();
      if (!expertDoc.exists) {
        _log.warning(
          'Rating submission failed: expert $expertId not found',
          tag: _tag,
        );
        return RatingResult.failure(RatingError.expertNotFound);
      }
      final roles = List<String>.from(
        expertDoc.data()?['roles'] as List<dynamic>? ?? [],
      );
      if (!roles.contains('Expert')) {
        _log.warning(
          'Rating submission failed: target $expertId is not an expert (roles: $roles)',
          tag: _tag,
        );
        return RatingResult.failure(RatingError.targetNotExpert);
      }
    } catch (e) {
      _log.error(
        'Rating submission failed: error verifying expert role: $e',
        tag: _tag,
      );
      return RatingResult.failure(RatingError.expertNotFound);
    }

    // 4. Validate stars
    if (stars < 1 || stars > 5) {
      _log.warning('Rating submission failed: invalid stars ($stars)', tag: _tag);
      return RatingResult.failure(RatingError.invalidStars);
    }

    // 5. Validate comment length
    final trimmedComment = comment?.trim();
    if (trimmedComment != null && trimmedComment.length > maxCommentLength) {
      _log.warning(
        'Rating submission failed: comment too long (${trimmedComment.length})',
        tag: _tag,
      );
      return RatingResult.failure(RatingError.commentTooLong);
    }

    // 6. Check for duplicate rating
    final hasRated = await _repository.hasUserRatedBooking(userId, bookingId);
    if (hasRated) {
      _log.warning(
        'Rating submission failed: already rated booking $bookingId',
        tag: _tag,
      );
      return RatingResult.failure(RatingError.alreadyRated);
    }

    // 7. Get user name for non-anonymous ratings
    String? userName;
    if (!isAnonymous) {
      userName = _getCurrentUserName();
    }

    // 8. Create rating
    try {
      final rating = Rating(
        id: '', // Will be set by repository
        expertId: expertId,
        expertName: expertName,
        userId: userId,
        userName: userName,
        bookingId: bookingId,
        stars: stars,
        comment: trimmedComment?.isNotEmpty == true ? trimmedComment : null,
        isAnonymous: isAnonymous,
        createdAt: DateTime.now(),
      );

      final created = await _repository.createRating(rating);

      if (created == null) {
        _log.error('Rating submission failed: repository returned null', tag: _tag);
        return RatingResult.failure(RatingError.submissionFailed);
      }

      _log.info('Rating submitted successfully: ${created.id}', tag: _tag);
      return RatingResult.success(created);
    } catch (e) {
      _log.error('Rating submission failed: $e', tag: _tag);
      return RatingResult.failure(RatingError.unknown);
    }
  }

  // ============= Reading =============

  /// Gets ratings for an expert with pagination.
  Future<List<Rating>> getExpertRatings({
    required String expertId,
    int limit = 20,
    Rating? lastRating,
  }) async {
    _log.debug('Fetching expert ratings: expertId=$expertId, limit=$limit', tag: _tag);
    return _repository.getExpertRatings(expertId, limit: limit, lastRating: lastRating);
  }

  /// Gets all ratings submitted by the current user.
  Future<List<Rating>> getMyRatings() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _log.warning('Cannot get ratings: not authenticated', tag: _tag);
      return [];
    }

    _log.debug('Fetching user ratings: userId=$userId', tag: _tag);
    return _repository.getUserRatings(userId);
  }

  /// Checks if the current user has rated a specific booking.
  Future<bool> hasRatedBooking(String bookingId) async {
    final userId = _getCurrentUserId();
    if (userId == null) return false;

    return _repository.hasUserRatedBooking(userId, bookingId);
  }

  /// Gets the rating for a specific booking.
  Future<Rating?> getRatingForBooking(String bookingId) async {
    return _repository.getRatingByBooking(bookingId);
  }

  /// Gets the rating statistics for an expert.
  Future<Map<String, dynamic>> getExpertRatingStats(String expertId) async {
    return _repository.getExpertRatingStats(expertId);
  }

  // ============= Streams =============

  /// Streams ratings for an expert in real-time.
  Stream<List<Rating>> watchExpertRatings(String expertId, {int limit = 20}) {
    return _repository.watchExpertRatings(expertId, limit: limit);
  }

  // ============= Helpers =============

  String? _getCurrentUserId() {
    return sl<FirebaseAuth>().currentUser?.uid;
  }

  String? _getCurrentUserName() {
    // Get from cached user profile first (most reliable)
    final cachedUser = UserProfileService().userProfile;
    if (cachedUser?.name != null && cachedUser!.name.isNotEmpty) {
      return cachedUser.name;
    }
    
    // Fallback to Firebase Auth displayName
    final authUser = sl<FirebaseAuth>().currentUser;
    if (authUser?.displayName != null && authUser!.displayName!.isNotEmpty) {
      return authUser.displayName;
    }
    
    // Phone auth only - no email available, return null
    return null;
  }
}
