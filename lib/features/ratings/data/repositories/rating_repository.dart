import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/data/repositories/interfaces/rating_repository_interface.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/features/ratings/data/models/rating.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Repository for managing expert ratings in Firestore.
///
/// Handles CRUD operations for the `ratings` collection.
/// Ratings are indexed by expertId and userId for efficient querying.
///
/// Collection structure:
/// ```
/// ratings/{ratingId}
///   - expertId: string
///   - expertName: string
///   - userId: string
///   - userName: string?
///   - bookingId: string?
///   - stars: int (1-5)
///   - comment: string?
///   - isAnonymous: bool
///   - createdAt: timestamp
/// ```
class RatingRepository implements IRatingRepository {
  final FirestoreInstance _firestoreService = FirestoreInstance();
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'RatingRepository';
  static const String _ratingsCollection = 'ratings';

  FirebaseFirestore get _db => _firestoreService.db;

  // ============= Document References =============

  CollectionReference<Map<String, dynamic>> get _ratingsRef =>
      _db.collection(_ratingsCollection);

  DocumentReference<Map<String, dynamic>> _ratingRef(String ratingId) =>
      _ratingsRef.doc(ratingId);

  // ============= Create =============

  /// Creates a new rating in Firestore.
  ///
  /// Returns the created Rating with its assigned ID, or null on failure.
  @override
  Future<Rating?> createRating(Rating rating) async {
    return await ErrorHandler.handle<Rating?>(
      operation: () async {
        final docRef = _ratingsRef.doc();
        final now = DateTime.now();
        final newRating = rating.copyWith(
          id: docRef.id,
          createdAt: now,
        );

        await docRef.set(newRating.toJson());

        _log.info(
          'Rating created: ${docRef.id} for expert ${rating.expertId}',
          tag: _tag,
        );

        return newRating;
      },
      fallback: null,
      onError: (error) => _log.error('Error creating rating: $error', tag: _tag),
    );
  }

  // ============= Read =============

  /// Gets a rating by its ID.
  @override
  Future<Rating?> getRating(String ratingId) async {
    return await ErrorHandler.handle<Rating?>(
      operation: () async {
        final doc = await _ratingRef(ratingId).get();
        if (!doc.exists || doc.data() == null) return null;
        return Rating.fromJson(doc.data()!, docId: doc.id);
      },
      fallback: null,
      onError: (error) => _log.error('Error getting rating: $error', tag: _tag),
    );
  }

  /// Gets a rating for a specific booking.
  ///
  /// Used to check if user has already rated a session.
  @override
  Future<Rating?> getRatingByBooking(String bookingId) async {
    return await ErrorHandler.handle<Rating?>(
      operation: () async {
        final querySnapshot = await _ratingsRef
            .where('bookingId', isEqualTo: bookingId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) return null;

        final doc = querySnapshot.docs.first;
        return Rating.fromJson(doc.data(), docId: doc.id);
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error getting rating by booking: $error', tag: _tag),
    );
  }

  /// Gets all ratings for an expert with pagination.
  ///
  /// Results are ordered by createdAt descending (newest first).
  @override
  Future<List<Rating>> getExpertRatings(
    String expertId, {
    int limit = 20,
    Rating? lastRating,
  }) async {
    return await ErrorHandler.handle<List<Rating>>(
      operation: () async {
        Query<Map<String, dynamic>> query = _ratingsRef
            .where('expertId', isEqualTo: expertId)
            .orderBy('createdAt', descending: true)
            .limit(limit);

        if (lastRating != null) {
          query = query.startAfter([Timestamp.fromDate(lastRating.createdAt)]);
        }

        final querySnapshot = await query.get();

        return querySnapshot.docs
            .map((doc) => Rating.fromJson(doc.data(), docId: doc.id))
            .toList();
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error getting expert ratings: $error', tag: _tag),
    );
  }

  /// Gets all ratings submitted by a user.
  @override
  Future<List<Rating>> getUserRatings(String userId) async {
    return await ErrorHandler.handle<List<Rating>>(
      operation: () async {
        final querySnapshot = await _ratingsRef
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

        return querySnapshot.docs
            .map((doc) => Rating.fromJson(doc.data(), docId: doc.id))
            .toList();
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error getting user ratings: $error', tag: _tag),
    );
  }

  /// Checks if a user has already rated a specific booking.
  @override
  Future<bool> hasUserRatedBooking(String userId, String bookingId) async {
    return await ErrorHandler.handle<bool>(
      operation: () async {
        final querySnapshot = await _ratingsRef
            .where('userId', isEqualTo: userId)
            .where('bookingId', isEqualTo: bookingId)
            .limit(1)
            .get();

        return querySnapshot.docs.isNotEmpty;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error checking rating existence: $error', tag: _tag),
    );
  }

  // ============= Streams =============

  /// Streams all ratings for an expert in real-time.
  @override
  Stream<List<Rating>> watchExpertRatings(String expertId, {int limit = 20}) {
    return _ratingsRef
        .where('expertId', isEqualTo: expertId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Rating.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  // ============= Aggregation Helpers =============

  /// Gets the rating statistics for an expert.
  ///
  /// Returns a map with 'averageRating' and 'totalRatings'.
  /// This is typically handled by Cloud Functions, but useful for fallback.
  @override
  Future<Map<String, dynamic>> getExpertRatingStats(String expertId) async {
    return await ErrorHandler.handle<Map<String, dynamic>>(
      operation: () async {
        final querySnapshot = await _ratingsRef
            .where('expertId', isEqualTo: expertId)
            .get();

        if (querySnapshot.docs.isEmpty) {
          return {'averageRating': 0.0, 'totalRatings': 0};
        }

        final ratings = querySnapshot.docs
            .map((doc) => Rating.fromJson(doc.data(), docId: doc.id))
            .toList();

        final totalStars = ratings.fold<int>(0, (acc, r) => acc + r.stars);
        final average = totalStars / ratings.length;

        return {
          'averageRating': double.parse(average.toStringAsFixed(1)),
          'totalRatings': ratings.length,
        };
      },
      fallback: {'averageRating': 0.0, 'totalRatings': 0},
      onError: (error) =>
          _log.error('Error getting rating stats: $error', tag: _tag),
    );
  }
}
