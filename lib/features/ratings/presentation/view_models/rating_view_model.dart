import 'package:flutter/foundation.dart';
import 'package:securityexperts_app/features/ratings/services/rating_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/validators/pii_validator.dart';

/// State for the rating submission page.
class RatingState {
  final int selectedStars;
  final String comment;
  final bool isAnonymous;
  final bool isLoading;
  final bool isSubmitted;
  final String? errorMessage;

  const RatingState({
    this.selectedStars = 0,
    this.comment = '',
    this.isAnonymous = false,
    this.isLoading = false,
    this.isSubmitted = false,
    this.errorMessage,
  });

  bool get canSubmit => selectedStars > 0 && !isLoading && !isSubmitted;

  RatingState copyWith({
    int? selectedStars,
    String? comment,
    bool? isAnonymous,
    bool? isLoading,
    bool? isSubmitted,
    String? errorMessage,
  }) {
    return RatingState(
      selectedStars: selectedStars ?? this.selectedStars,
      comment: comment ?? this.comment,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isLoading: isLoading ?? this.isLoading,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      errorMessage: errorMessage,
    );
  }
}

/// ViewModel for rating submission.
///
/// Manages the state and business logic for submitting an expert rating.
class RatingViewModel extends ChangeNotifier {
  final RatingService _ratingService;
  final AppLogger _log;
  static const String _tag = 'RatingViewModel';

  RatingState _state = const RatingState();
  RatingState get state => _state;

  // Expert info passed during initialization
  late final String _expertId;
  late final String _expertName;
  late final String _bookingId;

  RatingViewModel({
    required RatingService ratingService,
    AppLogger? log,
  })  : _ratingService = ratingService,
        _log = log ?? sl<AppLogger>();

  /// Initialize with expert and booking info.
  void initialize({
    required String expertId,
    required String expertName,
    required String bookingId,
  }) {
    _expertId = expertId;
    _expertName = expertName;
    _bookingId = bookingId;
    _log.debug('RatingViewModel initialized: expertId=$expertId, bookingId=$bookingId', tag: _tag);
  }

  /// Updates the selected star rating.
  void setStars(int stars) {
    if (stars >= 1 && stars <= 5) {
      _state = _state.copyWith(selectedStars: stars, errorMessage: null);
      notifyListeners();
    }
  }

  /// Updates the comment text.
  void setComment(String comment) {
    _state = _state.copyWith(comment: comment, errorMessage: null);
    notifyListeners();
  }

  /// Toggles the anonymous option.
  void setAnonymous(bool isAnonymous) {
    _state = _state.copyWith(isAnonymous: isAnonymous);
    notifyListeners();
  }

  /// Submits the rating.
  ///
  /// Returns true if submission was successful.
  Future<bool> submitRating() async {
    if (!_state.canSubmit) {
      _log.warning('Cannot submit: canSubmit=false', tag: _tag);
      return false;
    }

    // Check comment for PII (phone numbers, emails)
    if (_state.comment.trim().isNotEmpty) {
      final piiResult = PIIValidator().validate(_state.comment);
      if (!piiResult.isValid) {
        _state = _state.copyWith(errorMessage: piiResult.message);
        notifyListeners();
        return false;
      }
    }

    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    _log.info('Submitting rating: stars=${_state.selectedStars}', tag: _tag);

    final result = await _ratingService.submitRating(
      expertId: _expertId,
      expertName: _expertName,
      bookingId: _bookingId,
      stars: _state.selectedStars,
      comment: _state.comment.trim().isNotEmpty ? _state.comment.trim() : null,
      isAnonymous: _state.isAnonymous,
    );

    if (result.isSuccess) {
      _state = _state.copyWith(
        isLoading: false,
        isSubmitted: true,
      );
      notifyListeners();
      _log.info('Rating submitted successfully', tag: _tag);
      return true;
    } else {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: result.error?.message ?? 'Failed to submit rating',
      );
      notifyListeners();
      _log.warning('Rating submission failed: ${result.error}', tag: _tag);
      return false;
    }
  }

  /// Clears any error message.
  void clearError() {
    if (_state.errorMessage != null) {
      _state = _state.copyWith(errorMessage: null);
      notifyListeners();
    }
  }
}
