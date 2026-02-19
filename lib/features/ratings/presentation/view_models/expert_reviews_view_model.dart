import 'package:flutter/foundation.dart';
import 'package:greenhive_app/features/ratings/data/models/rating.dart';
import 'package:greenhive_app/features/ratings/services/rating_service.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// State for the expert reviews page.
class ExpertReviewsState {
  final List<Rating> ratings;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreData;
  final double averageRating;
  final int totalRatings;
  final String? errorMessage;

  const ExpertReviewsState({
    this.ratings = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMoreData = true,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.errorMessage,
  });

  bool get isEmpty => ratings.isEmpty && !isLoading;
  bool get hasRatings => ratings.isNotEmpty;

  ExpertReviewsState copyWith({
    List<Rating>? ratings,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreData,
    double? averageRating,
    int? totalRatings,
    String? errorMessage,
  }) {
    return ExpertReviewsState(
      ratings: ratings ?? this.ratings,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      errorMessage: errorMessage,
    );
  }
}

/// ViewModel for the expert reviews page.
///
/// Manages loading and pagination of ratings for an expert.
class ExpertReviewsViewModel extends ChangeNotifier {
  final RatingService _ratingService;
  final AppLogger _log;
  static const String _tag = 'ExpertReviewsViewModel';
  static const int _pageSize = 20;

  ExpertReviewsState _state = const ExpertReviewsState();
  ExpertReviewsState get state => _state;

  late final String _expertId;

  ExpertReviewsViewModel({
    required RatingService ratingService,
    AppLogger? log,
  })  : _ratingService = ratingService,
        _log = log ?? sl<AppLogger>();

  /// Initialize with expert ID and load initial data.
  Future<void> initialize(String expertId) async {
    _expertId = expertId;
    _log.debug('Initializing ExpertReviewsViewModel: expertId=$expertId', tag: _tag);
    await _loadInitialData();
  }

  /// Loads the initial ratings and stats.
  Future<void> _loadInitialData() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      // Load stats and ratings in parallel
      final statsFuture = _ratingService.getExpertRatingStats(_expertId);
      final ratingsFuture = _ratingService.getExpertRatings(
        expertId: _expertId,
        limit: _pageSize,
      );

      final results = await Future.wait([statsFuture, ratingsFuture]);

      final stats = results[0] as Map<String, dynamic>;
      final ratings = results[1] as List<Rating>;

      _state = _state.copyWith(
        isLoading: false,
        ratings: ratings,
        averageRating: (stats['averageRating'] as num?)?.toDouble() ?? 0.0,
        totalRatings: (stats['totalRatings'] as int?) ?? 0,
        hasMoreData: ratings.length >= _pageSize,
      );
      notifyListeners();

      _log.debug('Loaded ${ratings.length} ratings, avg=${_state.averageRating}', tag: _tag);
    } catch (e) {
      _log.error('Error loading ratings: $e', tag: _tag);
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load reviews',
      );
      notifyListeners();
    }
  }

  /// Loads more ratings (pagination).
  Future<void> loadMore() async {
    if (_state.isLoadingMore || !_state.hasMoreData) return;

    _state = _state.copyWith(isLoadingMore: true);
    notifyListeners();

    try {
      final lastRating = _state.ratings.isNotEmpty ? _state.ratings.last : null;

      final moreRatings = await _ratingService.getExpertRatings(
        expertId: _expertId,
        limit: _pageSize,
        lastRating: lastRating,
      );

      _state = _state.copyWith(
        isLoadingMore: false,
        ratings: [..._state.ratings, ...moreRatings],
        hasMoreData: moreRatings.length >= _pageSize,
      );
      notifyListeners();

      _log.debug('Loaded ${moreRatings.length} more ratings', tag: _tag);
    } catch (e) {
      _log.error('Error loading more ratings: $e', tag: _tag);
      _state = _state.copyWith(isLoadingMore: false);
      notifyListeners();
    }
  }

  /// Refreshes the ratings list.
  Future<void> refresh() async {
    _log.debug('Refreshing ratings', tag: _tag);
    await _loadInitialData();
  }

  /// Clears the error message.
  void clearError() {
    if (_state.errorMessage != null) {
      _state = _state.copyWith(errorMessage: null);
      notifyListeners();
    }
  }
}
