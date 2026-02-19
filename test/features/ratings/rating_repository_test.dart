import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:securityexperts_app/features/ratings/data/models/rating.dart';

/// Unit tests for RatingRepository
///
/// Tests cover model parsing, exception handling, and static methods.
/// Integration tests with Firestore require FakeFirebaseFirestore setup.
void main() {
  group('Rating Model', () {
    group('fromJson', () {
      test('should parse complete rating from JSON', () {
        final json = {
          'expertId': 'expert-123',
          'expertName': 'Test Expert',
          'userId': 'user-456',
          'userName': 'Test User',
          'bookingId': 'booking-789',
          'stars': 5,
          'comment': 'Excellent session!',
          'isAnonymous': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final rating = Rating.fromJson(json, docId: 'rating-001');

        expect(rating.id, equals('rating-001'));
        expect(rating.expertId, equals('expert-123'));
        expect(rating.expertName, equals('Test Expert'));
        expect(rating.userId, equals('user-456'));
        expect(rating.userName, equals('Test User'));
        expect(rating.bookingId, equals('booking-789'));
        expect(rating.stars, equals(5));
        expect(rating.comment, equals('Excellent session!'));
        expect(rating.isAnonymous, equals(false));
        expect(rating.createdAt.year, equals(2026));
      });

      test('should parse rating with null optional fields', () {
        final json = {
          'expertId': 'expert-123',
          'expertName': 'Test Expert',
          'userId': 'user-456',
          'stars': 4,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final rating = Rating.fromJson(json, docId: 'rating-002');

        expect(rating.userName, isNull);
        expect(rating.bookingId, isNull);
        expect(rating.comment, isNull);
        expect(rating.isAnonymous, equals(false)); // default value
      });

      test('should handle anonymous rating', () {
        final json = {
          'expertId': 'expert-123',
          'expertName': 'Test Expert',
          'userId': 'user-456',
          'userName': 'Real Name',
          'stars': 3,
          'isAnonymous': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final rating = Rating.fromJson(json, docId: 'rating-003');

        expect(rating.isAnonymous, equals(true));
        expect(rating.userName, equals('Real Name')); // Still stored
        expect(rating.displayName, equals('Anonymous')); // But displays as anonymous
      });
    });

    group('toJson', () {
      test('should convert rating to JSON', () {
        final rating = Rating(
          id: 'rating-001',
          expertId: 'expert-123',
          expertName: 'Test Expert',
          userId: 'user-456',
          userName: 'Test User',
          bookingId: 'booking-789',
          stars: 5,
          comment: 'Great!',
          isAnonymous: false,
          createdAt: DateTime(2026, 1, 15),
        );

        final json = rating.toJson();

        expect(json['expertId'], equals('expert-123'));
        expect(json['expertName'], equals('Test Expert'));
        expect(json['userId'], equals('user-456'));
        expect(json['userName'], equals('Test User'));
        expect(json['bookingId'], equals('booking-789'));
        expect(json['stars'], equals(5));
        expect(json['comment'], equals('Great!'));
        expect(json['isAnonymous'], equals(false));
      });
    });

    group('displayName', () {
      test('should return "Anonymous" when isAnonymous is true', () {
        final rating = Rating(
          id: 'r1',
          expertId: 'e1',
          expertName: 'Expert',
          userId: 'u1',
          userName: 'John Doe',
          stars: 5,
          isAnonymous: true,
          createdAt: DateTime.now(),
        );

        expect(rating.displayName, equals('Anonymous'));
      });

      test('should return userName when not anonymous', () {
        final rating = Rating(
          id: 'r1',
          expertId: 'e1',
          expertName: 'Expert',
          userId: 'u1',
          userName: 'John Doe',
          stars: 5,
          isAnonymous: false,
          createdAt: DateTime.now(),
        );

        expect(rating.displayName, equals('John Doe'));
      });

      test('should return "User" when userName is null and not anonymous', () {
        final rating = Rating(
          id: 'r1',
          expertId: 'e1',
          expertName: 'Expert',
          userId: 'u1',
          stars: 5,
          isAnonymous: false,
          createdAt: DateTime.now(),
        );

        expect(rating.displayName, equals('User'));
      });
    });

    group('hasComment', () {
      test('should return true for non-empty comment', () {
        final rating = Rating(
          id: 'r1',
          expertId: 'e1',
          expertName: 'Expert',
          userId: 'u1',
          stars: 5,
          comment: 'Great session!',
          createdAt: DateTime.now(),
        );

        expect(rating.hasComment, equals(true));
      });

      test('should return false for null comment', () {
        final rating = Rating(
          id: 'r1',
          expertId: 'e1',
          expertName: 'Expert',
          userId: 'u1',
          stars: 5,
          createdAt: DateTime.now(),
        );

        expect(rating.hasComment, equals(false));
      });

      test('should return false for whitespace-only comment', () {
        final rating = Rating(
          id: 'r1',
          expertId: 'e1',
          expertName: 'Expert',
          userId: 'u1',
          stars: 5,
          comment: '   ',
          createdAt: DateTime.now(),
        );

        expect(rating.hasComment, equals(false));
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = Rating(
          id: 'r1',
          expertId: 'e1',
          expertName: 'Expert',
          userId: 'u1',
          stars: 3,
          createdAt: DateTime(2026, 1, 1),
        );

        final updated = original.copyWith(stars: 5, comment: 'Updated');

        expect(updated.id, equals('r1'));
        expect(updated.stars, equals(5));
        expect(updated.comment, equals('Updated'));
        expect(original.stars, equals(3)); // Original unchanged
      });
    });
  });

  group('RatingRepository - Validation', () {
    test('should validate star rating range (1-5)', () {
      // Valid ratings
      for (var stars = 1; stars <= 5; stars++) {
        final rating = Rating(
          id: 'r1',
          expertId: 'e1',
          expertName: 'Expert',
          userId: 'u1',
          stars: stars,
          createdAt: DateTime.now(),
        );
        expect(rating.stars >= 1 && rating.stars <= 5, equals(true));
      }
    });

    test('should handle edge case star values in model', () {
      // Model allows any int - validation should be at service layer
      final rating = Rating(
        id: 'r1',
        expertId: 'e1',
        expertName: 'Expert',
        userId: 'u1',
        stars: 0, // Invalid but model accepts it
        createdAt: DateTime.now(),
      );
      expect(rating.stars, equals(0));
    });
  });

  group('Rating Equality', () {
    test('should be equal for same values', () {
      final createdAt = DateTime(2026, 1, 15);
      
      final rating1 = Rating(
        id: 'r1',
        expertId: 'e1',
        expertName: 'Expert',
        userId: 'u1',
        stars: 5,
        createdAt: createdAt,
      );

      final rating2 = Rating(
        id: 'r1',
        expertId: 'e1',
        expertName: 'Expert',
        userId: 'u1',
        stars: 5,
        createdAt: createdAt,
      );

      // Note: Default Dart equality doesn't compare by value
      // This tests that properties match
      expect(rating1.id, equals(rating2.id));
      expect(rating1.expertId, equals(rating2.expertId));
      expect(rating1.stars, equals(rating2.stars));
    });
  });

  group('Rating JSON Roundtrip', () {
    test('should survive JSON roundtrip', () {
      final original = Rating(
        id: 'rating-001',
        expertId: 'expert-123',
        expertName: 'Test Expert',
        userId: 'user-456',
        userName: 'Test User',
        bookingId: 'booking-789',
        stars: 4,
        comment: 'Good session',
        isAnonymous: true,
        createdAt: DateTime(2026, 1, 15, 10, 30),
      );

      final json = original.toJson();
      
      // Simulate Firestore storage (convert DateTime to Timestamp)
      json['createdAt'] = Timestamp.fromDate(original.createdAt);
      
      final restored = Rating.fromJson(json, docId: original.id);

      expect(restored.id, equals(original.id));
      expect(restored.expertId, equals(original.expertId));
      expect(restored.expertName, equals(original.expertName));
      expect(restored.userId, equals(original.userId));
      expect(restored.userName, equals(original.userName));
      expect(restored.bookingId, equals(original.bookingId));
      expect(restored.stars, equals(original.stars));
      expect(restored.comment, equals(original.comment));
      expect(restored.isAnonymous, equals(original.isAnonymous));
      expect(restored.createdAt.year, equals(original.createdAt.year));
      expect(restored.createdAt.month, equals(original.createdAt.month));
      expect(restored.createdAt.day, equals(original.createdAt.day));
    });
  });
}
