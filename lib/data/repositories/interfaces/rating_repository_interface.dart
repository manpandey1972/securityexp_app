import 'package:securityexperts_app/features/ratings/data/models/rating.dart';

/// Abstract interface for expert-rating operations.
///
/// Implementations handle storage details (Firestore, mocks, etc.).
abstract class IRatingRepository {
  // ── Create ───────────────────────────────────────────────────────────
  Future<Rating?> createRating(Rating rating);

  // ── Read ──────────────────────────────────────────────────────────────
  Future<Rating?> getRating(String ratingId);

  Future<Rating?> getRatingByBooking(String bookingId);

  Future<List<Rating>> getExpertRatings(
    String expertId, {
    int limit,
    Rating? lastRating,
  });

  Future<List<Rating>> getUserRatings(String userId);

  Future<bool> hasUserRatedBooking(String userId, String bookingId);

  // ── Streams ──────────────────────────────────────────────────────────
  Stream<List<Rating>> watchExpertRatings(String expertId, {int limit});

  // ── Aggregation ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getExpertRatingStats(String expertId);
}
