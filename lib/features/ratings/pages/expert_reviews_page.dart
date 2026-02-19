import 'package:flutter/material.dart';
import 'package:securityexperts_app/features/ratings/presentation/view_models/expert_reviews_view_model.dart';
import 'package:securityexperts_app/features/ratings/widgets/rating_card.dart';
import 'package:securityexperts_app/features/ratings/widgets/expert_rating_summary.dart';
import 'package:securityexperts_app/features/ratings/services/rating_service.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/widgets/empty_state_widget.dart';
import 'package:securityexperts_app/shared/widgets/error_state_widget.dart';
import 'package:securityexperts_app/shared/widgets/shimmer_loading.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Page that displays all reviews for an expert.
///
/// Features:
/// - Rating summary header
/// - Paginated list of reviews
/// - Pull-to-refresh
/// - Empty state handling
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => ExpertReviewsPage(
///       expertId: 'expert123',
///       expertName: 'John Expert',
///     ),
///   ),
/// );
/// ```
class ExpertReviewsPage extends StatefulWidget {
  /// ID of the expert
  final String expertId;

  /// Name of the expert (for display)
  final String expertName;

  const ExpertReviewsPage({
    super.key,
    required this.expertId,
    required this.expertName,
  });

  @override
  State<ExpertReviewsPage> createState() => _ExpertReviewsPageState();
}

class _ExpertReviewsPageState extends State<ExpertReviewsPage> {
  late final ExpertReviewsViewModel _viewModel;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = ExpertReviewsViewModel(ratingService: sl<RatingService>());
    _viewModel.addListener(_onStateChanged);
    _viewModel.initialize(widget.expertId);

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onStateChanged);
    _viewModel.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await _viewModel.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = _viewModel.state;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.expertName}\'s Reviews'),
      ),
      body: state.isLoading
          ? _buildLoading()
          : state.errorMessage != null
              ? _buildError()
              : state.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary skeleton
        ShimmerLoading.shimmer(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Rating cards skeleton
        for (var i = 0; i < 5; i++) ...[
          ShimmerLoading.shimmer(
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildError() {
    return ErrorStateWidget(
      title: 'Error Loading Reviews',
      message: _viewModel.state.errorMessage ?? 'Failed to load reviews',
      onRetry: _viewModel.refresh,
    );
  }

  Widget _buildEmpty() {
    return const EmptyStateWidget(
      icon: Icons.rate_review_outlined,
      title: 'No Reviews Yet',
      description: 'This expert hasn\'t received any reviews yet.',
    );
  }

  Widget _buildContent() {
    final state = _viewModel.state;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: state.ratings.length + 2, // +1 header, +1 loading indicator
        itemBuilder: (context, index) {
          if (index == 0) {
            // Header with summary
            return _buildHeader();
          }

          if (index == state.ratings.length + 1) {
            // Loading more indicator
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          // Rating card
          final rating = state.ratings[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RatingCard(rating: rating),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final state = _viewModel.state;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Large rating display
          ExpertRatingSummary(
            averageRating: state.averageRating,
            totalRatings: state.totalRatings,
            variant: 'large',
          ),
        ],
      ),
    );
  }
}
