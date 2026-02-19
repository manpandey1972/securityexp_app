import 'package:flutter_test/flutter_test.dart';

import 'package:greenhive_app/data/models/models.dart';

/// Unit tests for UserRepository and User model
///
/// Tests cover model parsing, validation, role checking, and edge cases.
/// Integration tests with Firestore require FakeFirebaseFirestore setup.
void main() {
  group('User Model', () {
    group('fromJson', () {
      test('should parse complete user from JSON', () {
        final json = {
          'id': 'user-123',
          'name': 'Test User',
          'email': 'test@example.com',
          'phone': '+1234567890',
          'roles': ['Expert'],
          'langs': ['en', 'es'],
          'exps': ['gardening', 'landscaping'],
          'fcms': ['token1', 'token2'],
          'bio': 'Expert gardener with 10 years experience',
          'profile_picture_url': 'https://example.com/photo.jpg',
          'has_profile_picture': true,
          'notifications_enabled': true,
          'created_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'updated_at': Timestamp.fromDate(DateTime(2026, 1, 15)),
          'last_login': Timestamp.fromDate(DateTime(2026, 1, 20)),
          'rating': {
            'averageRating': 4.5,
            'totalRatings': 25,
          },
        };

        final user = User.fromJson(json);

        expect(user.id, equals('user-123'));
        expect(user.name, equals('Test User'));
        expect(user.email, equals('test@example.com'));
        expect(user.phone, equals('+1234567890'));
        expect(user.roles, contains('Expert'));
        expect(user.languages, containsAll(['en', 'es']));
        expect(user.expertises, containsAll(['gardening', 'landscaping']));
        expect(user.fcmTokens, hasLength(2));
        expect(user.bio, equals('Expert gardener with 10 years experience'));
        expect(user.profilePictureUrl, equals('https://example.com/photo.jpg'));
        expect(user.hasProfilePicture, equals(true));
        expect(user.notificationsEnabled, equals(true));
        expect(user.averageRating, equals(4.5));
        expect(user.totalRatings, equals(25));
      });

      test('should parse user with minimal required fields', () {
        final json = {
          'id': 'user-123',
          'name': 'Minimal User',
        };

        final user = User.fromJson(json);

        expect(user.id, equals('user-123'));
        expect(user.name, equals('Minimal User'));
        expect(user.email, isNull);
        expect(user.phone, isNull);
        expect(user.roles, isEmpty);
        expect(user.languages, isEmpty);
        expect(user.expertises, isEmpty);
        expect(user.fcmTokens, isEmpty);
        expect(user.bio, isNull);
        expect(user.hasProfilePicture, equals(false));
        expect(user.notificationsEnabled, equals(true)); // Default
        expect(user.averageRating, isNull);
        expect(user.totalRatings, isNull);
      });

      test('should handle missing id and name gracefully', () {
        final json = <String, dynamic>{};

        final user = User.fromJson(json);

        expect(user.id, equals(''));
        expect(user.name, equals(''));
      });

      test('should determine hasProfilePicture from URL presence', () {
        final jsonWithUrl = {
          'id': 'user-123',
          'name': 'User',
          'profile_picture_url': 'https://example.com/photo.jpg',
          'has_profile_picture': false, // Explicit flag is false
        };

        final user = User.fromJson(jsonWithUrl);

        // URL presence should override explicit flag
        expect(user.hasProfilePicture, equals(true));
      });

      test('should handle legacy int timestamps', () {
        final json = {
          'id': 'user-123',
          'name': 'User',
          'created_at': 1704067200000, // 2024-01-01 in milliseconds
        };

        final user = User.fromJson(json);

        expect(user.createdTime, isNotNull);
      });

      test('should parse admin permissions', () {
        final json = {
          'id': 'admin-123',
          'name': 'Admin User',
          'roles': ['Admin'],
          'adminPermissions': ['manage_users', 'view_reports'],
        };

        final user = User.fromJson(json);

        expect(user.adminPermissions, containsAll(['manage_users', 'view_reports']));
      });
    });

    group('toJson', () {
      test('should convert user to JSON', () {
        final user = User(
          id: 'user-123',
          name: 'Test User',
          email: 'test@example.com',
          roles: ['Expert'],
          languages: ['en'],
          expertises: ['gardening'],
          fcmTokens: ['token1'],
          bio: 'Test bio',
          hasProfilePicture: true,
          notificationsEnabled: false,
        );

        final json = user.toJson();

        // Note: 'id' is not included in toJson() because in Firestore
        // the document ID is stored separately from the document data
        expect(json.containsKey('id'), equals(false));
        expect(json['name'], equals('Test User'));
        expect(json['email'], equals('test@example.com'));
        expect(json['roles'], contains('Expert'));
        expect(json['langs'], contains('en'));
        expect(json['exps'], contains('gardening'));
        expect(json['fcms'], contains('token1'));
        expect(json['bio'], equals('Test bio'));
        expect(json['has_profile_picture'], equals(true));
        expect(json['notifications_enabled'], equals(false));
      });

      test('should omit null/empty optional fields', () {
        final user = User(
          id: 'user-123',
          name: 'Test User',
        );

        final json = user.toJson();

        expect(json.containsKey('email'), equals(false));
        expect(json.containsKey('phone'), equals(false));
        expect(json.containsKey('bio'), equals(false));
        expect(json.containsKey('rating'), equals(false));
      });

      test('should include rating when present', () {
        final user = User(
          id: 'user-123',
          name: 'Test User',
          averageRating: 4.5,
          totalRatings: 10,
        );

        final json = user.toJson();

        expect(json.containsKey('rating'), equals(true));
        expect(json['rating']['averageRating'], equals(4.5));
        expect(json['rating']['totalRatings'], equals(10));
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = User(
          id: 'user-123',
          name: 'Original Name',
          email: 'original@example.com',
          roles: ['User'],
        );

        final updated = original.copyWith(
          name: 'Updated Name',
          roles: ['Expert'],
        );

        expect(updated.id, equals('user-123'));
        expect(updated.name, equals('Updated Name'));
        expect(updated.email, equals('original@example.com'));
        expect(updated.roles, contains('Expert'));
        expect(original.name, equals('Original Name')); // Original unchanged
      });

      test('should preserve all fields when no updates provided', () {
        final original = User(
          id: 'user-123',
          name: 'User',
          email: 'test@example.com',
          phone: '+1234567890',
          roles: ['Expert'],
          languages: ['en'],
          expertises: ['gardening'],
          bio: 'Bio text',
          hasProfilePicture: true,
          notificationsEnabled: false,
        );

        final copy = original.copyWith();

        expect(copy.id, equals(original.id));
        expect(copy.name, equals(original.name));
        expect(copy.email, equals(original.email));
        expect(copy.phone, equals(original.phone));
        expect(copy.roles, equals(original.roles));
        expect(copy.languages, equals(original.languages));
        expect(copy.expertises, equals(original.expertises));
        expect(copy.bio, equals(original.bio));
        expect(copy.hasProfilePicture, equals(original.hasProfilePicture));
        expect(copy.notificationsEnabled, equals(original.notificationsEnabled));
      });
    });

    group('Role Checking', () {
      test('should identify expert role', () {
        final user = User(
          id: 'user-123',
          name: 'Expert User',
          roles: ['Expert'],
        );

        expect(user.roles.contains('Expert'), equals(true));
        expect(user.roles.contains('Admin'), equals(false));
      });

      test('should handle multiple roles', () {
        final user = User(
          id: 'user-123',
          name: 'Multi-role User',
          roles: ['Expert', 'Merchant', 'Admin'],
        );

        expect(user.roles.contains('Expert'), equals(true));
        expect(user.roles.contains('Merchant'), equals(true));
        expect(user.roles.contains('Admin'), equals(true));
        expect(user.roles.length, equals(3));
      });

      test('should handle empty roles', () {
        final user = User(
          id: 'user-123',
          name: 'Basic User',
          roles: [],
        );

        expect(user.roles, isEmpty);
        expect(user.roles.contains('Expert'), equals(false));
      });
    });

    group('Profile Picture URL Generation', () {
      test('should generate profile picture URL from user ID', () {
        final user = User(
          id: 'user-123',
          name: 'User',
        );

        final url = user.getProfilePictureUrl(bucket: 'test-bucket');

        expect(url, contains('user-123'));
        expect(url, contains('profile_pictures'));
        expect(url, contains('display'));
      });

      test('should return empty string for empty user ID', () {
        final user = User(
          id: '',
          name: 'User',
        );

        final url = user.getProfilePictureUrl();

        expect(url, equals(''));
      });

      test('should use custom variant', () {
        final user = User(
          id: 'user-123',
          name: 'User',
        );

        final url = user.getProfilePictureUrl(variant: 'thumbnail', bucket: 'test-bucket');

        expect(url, contains('thumbnail'));
      });
    });
  });

  group('User JSON Roundtrip', () {
    test('should survive JSON roundtrip', () {
      final original = User(
        id: 'user-123',
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        roles: ['Expert', 'Merchant'],
        languages: ['en', 'es'],
        expertises: ['gardening', 'landscaping'],
        fcmTokens: ['token1', 'token2'],
        bio: 'Expert bio here',
        hasProfilePicture: true,
        notificationsEnabled: false,
        averageRating: 4.8,
        totalRatings: 50,
      );

      final json = original.toJson();
      // Add the ID manually since toJson() doesn't include it
      // (in Firestore, ID is the document key, not part of document data)
      json['id'] = original.id;
      final restored = User.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.email, equals(original.email));
      expect(restored.phone, equals(original.phone));
      expect(restored.roles, equals(original.roles));
      expect(restored.languages, equals(original.languages));
      expect(restored.expertises, equals(original.expertises));
      expect(restored.fcmTokens, equals(original.fcmTokens));
      expect(restored.bio, equals(original.bio));
      expect(restored.hasProfilePicture, equals(original.hasProfilePicture));
      expect(restored.notificationsEnabled, equals(original.notificationsEnabled));
      expect(restored.averageRating, equals(original.averageRating));
      expect(restored.totalRatings, equals(original.totalRatings));
    });
  });

  group('User Equality', () {
    test('should have same properties for identical users', () {
      final user1 = User(
        id: 'user-123',
        name: 'Test User',
        email: 'test@example.com',
      );

      final user2 = User(
        id: 'user-123',
        name: 'Test User',
        email: 'test@example.com',
      );

      expect(user1.id, equals(user2.id));
      expect(user1.name, equals(user2.name));
      expect(user1.email, equals(user2.email));
    });
  });

  group('User Default Values', () {
    test('should have correct defaults', () {
      final user = User(
        id: 'user-123',
        name: 'User',
      );

      expect(user.roles, isEmpty);
      expect(user.languages, isEmpty);
      expect(user.expertises, isEmpty);
      expect(user.fcmTokens, isEmpty);
      expect(user.hasProfilePicture, equals(false));
      expect(user.notificationsEnabled, equals(true));
      expect(user.adminPermissions, isNull);
    });
  });
}
