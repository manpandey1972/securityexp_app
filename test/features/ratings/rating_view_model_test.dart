import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/ratings/data/models/rating.dart';
import 'package:greenhive_app/features/ratings/presentation/view_models/rating_view_model.dart';
import 'package:greenhive_app/features/ratings/services/rating_service.dart';

import 'rating_view_model_test.mocks.dart';

// Helper to create a mock Rating for successful submission
Rating _createMockRating({
  int stars = 5,
  String? comment,
  bool isAnonymous = false,
}) {
  return Rating(
    id: 'rating-123',
    expertId: 'expert-123',
    expertName: 'Test Expert',
    userId: 'user-456',
    userName: isAnonymous ? null : 'Test User',
    bookingId: 'booking-456',
    stars: stars,
    comment: comment,
    isAnonymous: isAnonymous,
    createdAt: DateTime.now(),
  );
}

@GenerateMocks([RatingService, AppLogger])
void main() {
  late RatingViewModel viewModel;
  late MockRatingService mockRatingService;
  late MockAppLogger mockAppLogger;

  setUp(() {
    mockRatingService = MockRatingService();
    mockAppLogger = MockAppLogger();

    // Register AppLogger in service locator
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);

    viewModel = RatingViewModel(
      ratingService: mockRatingService,
      log: mockAppLogger,
    );

    // Initialize with test data
    viewModel.initialize(
      expertId: 'expert-123',
      expertName: 'Test Expert',
      bookingId: 'booking-456',
    );
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('RatingViewModel - Initial State', () {
    test('should have initial state with default values', () {
      expect(viewModel.state.selectedStars, equals(0));
      expect(viewModel.state.comment, equals(''));
      expect(viewModel.state.isAnonymous, equals(false));
      expect(viewModel.state.isLoading, equals(false));
      expect(viewModel.state.isSubmitted, equals(false));
      expect(viewModel.state.errorMessage, isNull);
    });

    test('canSubmit should be false initially (no stars selected)', () {
      expect(viewModel.state.canSubmit, equals(false));
    });
  });

  group('RatingViewModel - setStars', () {
    test('should update star rating when valid value provided', () {
      viewModel.setStars(4);
      expect(viewModel.state.selectedStars, equals(4));
    });

    test('should allow star values from 1 to 5', () {
      for (var stars = 1; stars <= 5; stars++) {
        viewModel.setStars(stars);
        expect(viewModel.state.selectedStars, equals(stars));
      }
    });

    test('should not update stars for invalid values (0)', () {
      viewModel.setStars(3);
      viewModel.setStars(0);
      expect(viewModel.state.selectedStars, equals(3)); // unchanged
    });

    test('should not update stars for invalid values (6)', () {
      viewModel.setStars(3);
      viewModel.setStars(6);
      expect(viewModel.state.selectedStars, equals(3)); // unchanged
    });

    test('should not update stars for negative values', () {
      viewModel.setStars(3);
      viewModel.setStars(-1);
      expect(viewModel.state.selectedStars, equals(3)); // unchanged
    });

    test('canSubmit should be true after setting valid stars', () {
      viewModel.setStars(5);
      expect(viewModel.state.canSubmit, equals(true));
    });

    test('should clear error message when setting stars', () {
      // Simulate an error state
      viewModel.setComment('test');
      // Then set stars - should clear any error
      viewModel.setStars(4);
      expect(viewModel.state.errorMessage, isNull);
    });
  });

  group('RatingViewModel - setComment', () {
    test('should update comment text', () {
      viewModel.setComment('Great session!');
      expect(viewModel.state.comment, equals('Great session!'));
    });

    test('should allow empty comment', () {
      viewModel.setComment('');
      expect(viewModel.state.comment, equals(''));
    });

    test('should clear error message when setting comment', () {
      viewModel.setComment('New comment');
      expect(viewModel.state.errorMessage, isNull);
    });
  });

  group('RatingViewModel - setAnonymous', () {
    test('should enable anonymous mode', () {
      viewModel.setAnonymous(true);
      expect(viewModel.state.isAnonymous, equals(true));
    });

    test('should disable anonymous mode', () {
      viewModel.setAnonymous(true);
      viewModel.setAnonymous(false);
      expect(viewModel.state.isAnonymous, equals(false));
    });
  });

  group('RatingViewModel - submitRating', () {
    test('should return false if no stars selected', () async {
      final result = await viewModel.submitRating();
      expect(result, equals(false));
      verifyNever(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('should call ratingService.submitRating on valid submission', () async {
      viewModel.setStars(5);
      viewModel.setComment('Excellent!');

      when(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async => RatingResult.success(_createMockRating()));

      final result = await viewModel.submitRating();

      expect(result, equals(true));
      expect(viewModel.state.isSubmitted, equals(true));
      expect(viewModel.state.isLoading, equals(false));

      verify(mockRatingService.submitRating(
        expertId: 'expert-123',
        expertName: 'Test Expert',
        bookingId: 'booking-456',
        stars: 5,
        comment: 'Excellent!',
        isAnonymous: false,
      )).called(1);
    });

    test('should handle submission failure', () async {
      viewModel.setStars(4);

      when(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async => RatingResult.failure(RatingError.submissionFailed));

      final result = await viewModel.submitRating();

      expect(result, equals(false));
      expect(viewModel.state.isSubmitted, equals(false));
      expect(viewModel.state.errorMessage, isNotNull);
      expect(viewModel.state.isLoading, equals(false));
    });

    test('should reject comments with PII (phone numbers)', () async {
      viewModel.setStars(4);
      viewModel.setComment('Call me at 555-123-4567');

      final result = await viewModel.submitRating();

      expect(result, equals(false));
      expect(viewModel.state.errorMessage, isNotNull);
      verifyNever(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('should reject comments with PII (email)', () async {
      viewModel.setStars(4);
      viewModel.setComment('Email me at test@example.com');

      final result = await viewModel.submitRating();

      expect(result, equals(false));
      expect(viewModel.state.errorMessage, isNotNull);
    });

    test('should not submit when already loading', () async {
      viewModel.setStars(5);

      // First call - starts loading
      when(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return RatingResult.success(_createMockRating());
      });

      // Start first submission
      final future1 = viewModel.submitRating();

      // Try second submission while first is loading
      // canSubmit is false during loading, so this should return false immediately
      final result2 = await viewModel.submitRating();

      await future1;

      expect(result2, equals(false));
    });

    test('should not submit when already submitted', () async {
      viewModel.setStars(5);

      when(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async => RatingResult.success(_createMockRating()));

      await viewModel.submitRating();
      final secondResult = await viewModel.submitRating();

      expect(secondResult, equals(false));
      verify(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1); // Only called once
    });

    test('should pass isAnonymous flag correctly', () async {
      viewModel.setStars(5);
      viewModel.setAnonymous(true);

      when(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async => RatingResult.success(_createMockRating()));

      await viewModel.submitRating();

      verify(mockRatingService.submitRating(
        expertId: 'expert-123',
        expertName: 'Test Expert',
        bookingId: 'booking-456',
        stars: 5,
        comment: null,
        isAnonymous: true,
      )).called(1);
    });

    test('should trim comment whitespace', () async {
      viewModel.setStars(5);
      viewModel.setComment('  Great session!  ');

      when(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async => RatingResult.success(_createMockRating()));

      await viewModel.submitRating();

      verify(mockRatingService.submitRating(
        expertId: 'expert-123',
        expertName: 'Test Expert',
        bookingId: 'booking-456',
        stars: 5,
        comment: 'Great session!',
        isAnonymous: false,
      )).called(1);
    });

    test('should pass null comment when empty string', () async {
      viewModel.setStars(5);
      viewModel.setComment('   '); // Only whitespace

      when(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async => RatingResult.success(_createMockRating()));

      await viewModel.submitRating();

      verify(mockRatingService.submitRating(
        expertId: 'expert-123',
        expertName: 'Test Expert',
        bookingId: 'booking-456',
        stars: 5,
        comment: null,
        isAnonymous: false,
      )).called(1);
    });
  });

  group('RatingViewModel - clearError', () {
    test('should clear error message', () async {
      viewModel.setStars(4);

      when(mockRatingService.submitRating(
        expertId: anyNamed('expertId'),
        expertName: anyNamed('expertName'),
        bookingId: anyNamed('bookingId'),
        stars: anyNamed('stars'),
        comment: anyNamed('comment'),
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async => RatingResult.failure(RatingError.submissionFailed));

      await viewModel.submitRating();
      expect(viewModel.state.errorMessage, isNotNull);

      viewModel.clearError();
      expect(viewModel.state.errorMessage, isNull);
    });

    test('should do nothing when no error exists', () {
      expect(viewModel.state.errorMessage, isNull);
      viewModel.clearError();
      expect(viewModel.state.errorMessage, isNull);
    });
  });

  group('RatingState - copyWith', () {
    test('should preserve other values when updating single field', () {
      viewModel.setStars(4);
      viewModel.setComment('Test');
      viewModel.setAnonymous(true);

      expect(viewModel.state.selectedStars, equals(4));
      expect(viewModel.state.comment, equals('Test'));
      expect(viewModel.state.isAnonymous, equals(true));
    });

    test('canSubmit should reflect correct conditions', () {
      // No stars = can't submit
      expect(viewModel.state.canSubmit, equals(false));

      // With stars = can submit
      viewModel.setStars(3);
      expect(viewModel.state.canSubmit, equals(true));
    });
  });
}
