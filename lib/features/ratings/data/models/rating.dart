import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user's rating for an expert.
///
/// Ratings are tied to specific bookings (call sessions) to prevent duplicates.
/// Users can optionally submit anonymous ratings and add brief comments.
///
/// Firestore document structure:
/// ```json
/// {
///   "expertId": "expert123",
///   "expertName": "John Expert",
///   "userId": "user456",
///   "userName": "Jane User",
///   "bookingId": "call789",
///   "stars": 5,
///   "comment": "Great session!",
///   "isAnonymous": false,
///   "createdAt": Timestamp
/// }
/// ```
class Rating {
  // ============= Identifiers =============
  /// Unique identifier for the rating (Firestore document ID)
  final String id;

  /// ID of the expert being rated
  final String expertId;

  /// Name of the expert (denormalized for display)
  final String expertName;

  /// ID of the user who submitted the rating
  final String userId;

  /// Name of the user (null if anonymous)
  final String? userName;

  /// ID of the booking/call session this rating is for
  /// Used to prevent duplicate ratings for the same session
  final String? bookingId;

  // ============= Rating Data =============
  /// Star rating (1-5)
  final int stars;

  /// Optional comment (max 200 characters)
  final String? comment;

  /// Whether the rating should be displayed as anonymous
  final bool isAnonymous;

  // ============= Metadata =============
  /// When the rating was created
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.expertId,
    required this.expertName,
    required this.userId,
    this.userName,
    this.bookingId,
    required this.stars,
    this.comment,
    this.isAnonymous = false,
    required this.createdAt,
  });

  /// Display name for the rating
  /// Returns "Anonymous" if isAnonymous is true, otherwise returns userName
  String get displayName => isAnonymous ? 'Anonymous' : (userName ?? 'User');

  /// Whether this rating has a comment
  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  /// Creates a Rating from a Firestore document
  factory Rating.fromJson(Map<String, dynamic> json, {String? docId}) {
    return Rating(
      id: docId ?? json['id'] as String? ?? '',
      expertId: json['expertId'] as String? ?? '',
      expertName: json['expertName'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String?,
      bookingId: json['bookingId'] as String?,
      stars: _parseStars(json['stars']),
      comment: json['comment'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  /// Converts the Rating to a JSON map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'expertId': expertId,
      'expertName': expertName,
      'userId': userId,
      'userName': userName,
      'bookingId': bookingId,
      'stars': stars,
      'comment': comment,
      'isAnonymous': isAnonymous,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Creates a copy of this Rating with the given fields replaced
  Rating copyWith({
    String? id,
    String? expertId,
    String? expertName,
    String? userId,
    String? userName,
    String? bookingId,
    int? stars,
    String? comment,
    bool? isAnonymous,
    DateTime? createdAt,
  }) {
    return Rating(
      id: id ?? this.id,
      expertId: expertId ?? this.expertId,
      expertName: expertName ?? this.expertName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      bookingId: bookingId ?? this.bookingId,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ============= Helper Methods =============

  /// Parses a timestamp from various formats
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  /// Parses stars value ensuring it's between 1-5
  static int _parseStars(dynamic value) {
    if (value == null) return 1;
    final stars = value is int ? value : int.tryParse(value.toString()) ?? 1;
    return stars.clamp(1, 5);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rating && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Rating(id: $id, expertId: $expertId, userId: $userId, stars: $stars, '
        'isAnonymous: $isAnonymous, bookingId: $bookingId)';
  }
}
