import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/shared/themes/app_icon_sizes.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/home/widgets/expert_card.dart';
import 'package:greenhive_app/utils/expert_search_utils.dart';
import 'package:greenhive_app/shared/widgets/shimmer_loading.dart';
import 'package:greenhive_app/shared/widgets/error_state_widget.dart';
import 'package:greenhive_app/shared/widgets/empty_state_widget.dart';

/// Reusable Experts List Tab widget.
///
/// Displays a list of experts with search/filtering capabilities.
/// Handles loading states, errors, and refresh functionality.
///
/// Usage:
/// ```dart
/// ExpertsListTab(
///   experts: _experts,
///   isLoading: _loadingExperts,
///   error: _error,
///   searchQuery: _searchQuery,
///   onSearchChanged: (query) => setState(() => _searchQuery = query),
///   onRefresh: () => _loadExperts(),
///   searchUtils: _searchUtils,
///   onChat: (id, name) => startChat(id, name),
///   onAudioCall: (id, name) => startAudioCall(id, name),
///   onVideoCall: (id, name) => startVideoCall(id, name),
///   onSearchFocusChanged: (focused) => setState(() => _hideBottomNav = focused),
/// )
/// ```
class ExpertsListTab extends StatefulWidget {
  /// List of experts to display
  final List<models.User> experts;

  /// Whether the list is currently loading
  final bool isLoading;

  /// Error message, if any
  final String? error;

  /// Current search query
  final String searchQuery;

  /// Callback when search query changes
  final Function(String) onSearchChanged;

  /// Callback when user pulls to refresh
  final Function() onRefresh;

  /// Search utilities for filtering
  final ExpertSearchUtils searchUtils;

  /// Callback when chat button is tapped
  /// Parameters: expertId, expertName
  final Function(String, String) onChat;

  /// Callback when audio call button is tapped
  /// Parameters: expertId, expertName
  final Function(String, String) onAudioCall;

  /// Callback when video call button is tapped
  /// Parameters: expertId, expertName
  final Function(String, String) onVideoCall;

  /// Callback when expert card is tapped (navigate to profile)
  final Function(models.User)? onExpertTap;

  /// Callback when search field focus changes
  final Function(bool)? onSearchFocusChanged;

  const ExpertsListTab({
    super.key,
    required this.experts,
    required this.isLoading,
    this.error,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.searchUtils,
    required this.onChat,
    required this.onAudioCall,
    required this.onVideoCall,
    this.onExpertTap,
    this.onSearchFocusChanged,
  });

  @override
  State<ExpertsListTab> createState() => _ExpertsListTabState();
}

class _ExpertsListTabState extends State<ExpertsListTab>
    with AutomaticKeepAliveClientMixin {
  static const String _tag = 'ExpertsListTab';
  final AppLogger _log = sl<AppLogger>();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChange);
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    widget.onSearchFocusChanged?.call(_searchFocusNode.hasFocus);
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearchChanged('');
    _searchFocusNode.unfocus();
  }

  void _onSearchChanged(String value) {
    widget.onSearchChanged(value);
    if (value.isEmpty) {
      _searchFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        // Experts list with top padding for floating search bar
        Padding(
          padding: const EdgeInsets.only(top: 69),
          child: RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            child: widget.isLoading
                ? _buildLoadingState()
                : widget.error != null
                ? _buildErrorState()
                : _buildExpertsList(context),
          ),
        ),

        // Floating search field
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: ClipRRect(
            borderRadius: AppBorders.borderRadiusPill,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.divider.withValues(alpha: 0.7),
                      AppColors.divider.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppBorders.borderRadiusPill,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or skills...',
                    hintStyle: AppTypography.messageText.copyWith(
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: widget.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.textPrimary,
                              size: AppIconSizes.medium,
                            ),
                            onPressed: _clearSearch,
                          )
                        : const Icon(
                            Icons.search,
                            color: AppColors.textMuted,
                            size: AppIconSizes.medium,
                          ),
                    suffixIcon: widget.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.textMuted,
                              size: AppIconSizes.medium,
                            ),
                            onPressed: _clearSearch,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppBorders.borderRadiusPill,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppBorders.borderRadiusPill,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppBorders.borderRadiusPill,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ShimmerLoading.list(
      itemCount: 6,
      itemBuilder: () => ShimmerLoading.expertCard(),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      children: [
        SizedBox(
          height: 400,
          child: ErrorStateWidget.server(
            title: 'Failed to load experts',
            message: widget.error ?? 'An unexpected error occurred',
            onRetry: widget.onRefresh,
          ),
        ),
      ],
    );
  }

  Widget _buildExpertsList(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          // Filter experts based on search query
          final filteredExperts = widget.searchUtils.filterExperts(
            widget.experts,
            widget.searchQuery,
          );

          if (filteredExperts.isEmpty) {
            return ListView(
              children: [
                SizedBox(
                  height: 400,
                  child: widget.searchQuery.isNotEmpty
                      ? EmptyStateWidget.search(query: widget.searchQuery)
                      : EmptyStateWidget.list(
                          title: 'No experts available',
                          description:
                              'Experts will appear here once they join',
                        ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: filteredExperts.length,
            itemBuilder: (context, index) {
              final expert = filteredExperts[index];
              final skillNames = widget.searchUtils.getSkillNames(expert.expertises);

              return ExpertCard(
                key: ValueKey(expert.id),
                expert: expert,
                skillNames: skillNames,
                averageRating: expert.averageRating,
                totalRatings: expert.totalRatings,
                onTap: widget.onExpertTap != null ? () => widget.onExpertTap!(expert) : () {},
                onChat: (expertId, name) => widget.onChat(expertId, name),
                onAudioCall: (expertId, name) => widget.onAudioCall(expertId, name),
                onVideoCall: (expertId, name) => widget.onVideoCall(expertId, name),
              );
            },
          );
        } catch (e) {
          // If there's an error during filtering/rendering, show error message
          ErrorHandler.handleSync(
            operation: () {},
            onError: (error) {
              _log.error('Error displaying experts: $e', tag: _tag);
            },
          );
          return ErrorStateWidget(
            title: 'Error displaying experts',
            message: e.toString(),
            icon: Icons.error_outline,
          );
        }
      },
    );
  }
}
