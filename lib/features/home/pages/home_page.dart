import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_borders.dart';
import 'package:securityexperts_app/shared/animations/page_transitions.dart';
import 'package:securityexperts_app/providers/auth_provider.dart';
import 'package:securityexperts_app/core/constants.dart';
import 'expert_details_page.dart';
import 'package:securityexperts_app/features/chat/pages/chat_conversation_page.dart';
import 'product_details_page.dart';
import 'package:securityexperts_app/features/profile/pages/user_profile_page.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/features/calling/services/call_coordinator.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/profile/widgets/profile_menu.dart';
import 'package:securityexperts_app/shared/widgets/profile_picture_widget.dart';
import 'package:securityexperts_app/features/home/widgets/experts_list_tab.dart';
import 'package:securityexperts_app/features/home/widgets/products_tab.dart';
import 'package:securityexperts_app/features/chat_list/widgets/chats_tab.dart';
import 'package:securityexperts_app/features/calling/widgets/calls_tab.dart';
import 'package:securityexperts_app/features/home/presentation/view_models/home_view_model.dart';
import 'package:securityexperts_app/data/models/models.dart' as models;
import '../constants/home_page_constants.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/shared/widgets/global_upload_indicator.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<HomeViewModel>(),
      child: const _HomePageView(),
    );
  }
}

class _HomePageView extends StatelessWidget {
  const _HomePageView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final state = viewModel.state;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _HomeAppBar(viewModel: viewModel),
      body: Stack(
        children: [
          _buildBody(context, state, viewModel),
          // Global upload indicator - shows when uploads are in progress
          const GlobalUploadIndicator(),
          // Floating pill-shaped navigation bar (hidden when search is focused)
          if (!state.isSearchFocused)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Consumer<HomeViewModel>(
                builder: (context, vm, child) =>
                    _HomeBottomNav(state: vm.state, viewModel: vm),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, state, HomeViewModel viewModel) {
    // Conditional rendering: only build the currently selected tab
    switch (state.selectedTabIndex) {
      case 0:
        return ExpertsListTab(
          experts: state.experts,
          isLoading: state.isLoadingExperts,
          error: state.expertsError,
          searchQuery: state.searchQuery,
          onSearchChanged: (query) {
            viewModel.updateSearchQuery(query);
          },
          onSearchFocusChanged: (focused) {
            viewModel.setSearchFocused(focused);
          },
          onRefresh: () => viewModel.loadExperts(),
          searchUtils: viewModel.searchUtils,
          onChat: (expertId, expertName) {
            // Find the expert object to get profile picture
            try {
              final expert = state.experts.firstWhere((e) => e.id == expertId);
              _startChatWithExpert(context, expert);
            } catch (e) {
              // Expert not found, create minimal expert object
              final minimalExpert = models.User(id: expertId, name: expertName);
              _startChatWithExpert(context, minimalExpert);
            }
          },
          onAudioCall: (expertId, expertName) {
            _startCallWithExpert(context, expertId, expertName, false);
          },
          onVideoCall: (expertId, expertName) {
            _startCallWithExpert(context, expertId, expertName, true);
          },
          onExpertTap: (expert) {
            Navigator.of(context).push(
              PageTransitions.fadeScale(
                page: ExpertDetailsPage(expert: expert),
              ),
            );
          },
        );
      case 1:
        return ChatsTab(
          onLoadRequested: () => viewModel.triggerChatLoad,
          onRegisterLoadCallback: (callback) =>
              viewModel.registerChatLoadCallback(callback),
        );
      case 2:
        return const CallsTab();
      case 3:
        return ProductsTab(
          products: state.products,
          isLoading: state.isLoadingProducts,
          error: state.productsError,
          onRefresh: () => viewModel.loadProducts(),
          onProductTap: (productData) {
            Navigator.of(context).push(
              PageTransitions.slideFromRight(
                page: ProductDetailsPage(product: productData),
              ),
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Start a call with an expert (audio or video)
  Future<void> _startCallWithExpert(
    BuildContext context,
    String expertId,
    String expertName,
    bool isVideo,
  ) async {
    final log = sl<AppLogger>();
    const tag = 'HomePage';
    log.debug(
      '_startCallWithExpert called - expertId: $expertId, isVideo: $isVideo',
      tag: tag,
    );
    await CallCoordinator.startCall(
      context: context,
      partnerId: expertId,
      partnerName: expertName,
      isVideo: isVideo,
    );
    log.debug('_startCallWithExpert completed', tag: tag);
  }

  /// Start a chat with an expert
  Future<void> _startChatWithExpert(
    BuildContext context,
    models.User expert,
  ) async {
    final authState = context.read<AuthState>();
    if (!authState.isAuthenticated) {
      if (context.mounted) {
        SnackbarService.show(AppStrings.pleaseSignInToChat);
      }
      return;
    }

    if (context.mounted) {
      await Navigator.of(context).push(
        PageTransitions.slideFromBottom(
          page: ChatConversationPage(
            partnerId: expert.id,
            partnerName: expert.name,
            peerProfilePictureUrl: expert.profilePictureUrl,
          ),
        ),
      );
    }
  }
}

/// Extracted AppBar widget for better code organization
class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final HomeViewModel viewModel;

  const _HomeAppBar({required this.viewModel});

  @override
  Size get preferredSize =>
      const Size.fromHeight(HomePageConstants.appBarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AppBar(
          backgroundColor: AppColors.background.withValues(alpha: 0.7),
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HomePageConstants.appBarPaddingHorizontal,
                vertical: HomePageConstants.appBarPaddingVertical,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First row: App title and profile icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    verticalDirection: VerticalDirection.down,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/icon/small_logo.png',
                            width: HomePageConstants.appLogoSize,
                            height: HomePageConstants.appLogoSize,
                            cacheWidth: 72,
                            cacheHeight: 72,
                          ),
                          const SizedBox(
                            width: HomePageConstants.appLogoSpacing,
                          ),
                          Text(
                            'Greenhive',
                            style: AppTypography.headingMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        icon: _buildProfileIcon(),
                        color: AppColors.surface,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppBorders.borderRadiusNormal,
                        ),
                        offset: const Offset(0, 50),
                        onSelected: (value) async {
                          await ProfileMenu.handleMenuSelection(
                            context,
                            value,
                            onEditProfile: () async {
                              if (!context.mounted) return;
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const UserProfilePage(),
                                ),
                              );
                              if (!context.mounted) return;
                              if (result == true) {
                                SnackbarService.show(
                                  'Profile saved successfully',
                                );
                              }
                              // ViewModel will handle refresh via event bus
                            },
                          );
                        },
                        itemBuilder: (menuContext) =>
                            ProfileMenu.buildMenuItems(
                              context,
                              onLogoutConfirmed: () {},
                              onDeleteAccountConfirmed: () {},
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileIcon() {
    // Use ListenableBuilder to listen to UserProfileService changes
    return ListenableBuilder(
      listenable: sl<UserProfileService>(),
      builder: (context, _) {
        final currentUser = sl<UserProfileService>().userProfile;

        if (currentUser != null) {
          return SizedBox(
            width: HomePageConstants.profileIconSize,
            height: HomePageConstants.profileIconSize,
            child: ProfilePictureWidget(
              user: currentUser,
              size: HomePageConstants.profileIconSize,
              showBorder: false,
              variant: 'thumbnail',
            ),
          );
        }

        return const Icon(
          Icons.person,
          color: AppColors.white,
          size: HomePageConstants.profileIconFallbackSize,
        );
      },
    );
  }
}

/// Extracted BottomNavigationBar widget for better code organization
class _HomeBottomNav extends StatelessWidget {
  final dynamic state;
  final HomeViewModel viewModel;

  const _HomeBottomNav({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppBorders.borderRadiusPill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.background.withValues(alpha: 0.7),
                AppColors.background.withValues(alpha: 0.5),
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.person_search, 'Experts'),
              _buildNavItem(1, Icons.forum, 'Chats'),
              _buildNavItem(2, Icons.call, 'Calls'),
              _buildNavItem(3, Icons.storefront, 'Products'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = state.selectedTabIndex == index;
    final isChatTab = index == 1;
    final showBadge = isChatTab && state.unreadCount > 0;

    return GestureDetector(
      onTap: () => viewModel.selectTab(index),
      child: SizedBox(
        width: HomePageConstants.bottomNavItemWidth,
        height: HomePageConstants.bottomNavItemHeight,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HomePageConstants.bottomNavItemPaddingHorizontal,
            vertical: HomePageConstants.bottomNavItemPaddingVertical,
          ),
          decoration: const BoxDecoration(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  if (showBadge)
                    Positioned(
                      right: HomePageConstants.badgePositionOffset,
                      top: HomePageConstants.badgePositionOffset,
                      child: Container(
                        padding: const EdgeInsets.all(
                          HomePageConstants.badgePadding,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: HomePageConstants.badgeBorderWidth,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: HomePageConstants.badgeSize,
                          minHeight: HomePageConstants.badgeSize,
                        ),
                        child: Center(
                          child: Text(
                            state.unreadCount > HomePageConstants.maxBadgeCount
                                ? '${HomePageConstants.maxBadgeCount}+'
                                : state.unreadCount.toString(),
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.background,
                              height: 1.0,
                              fontWeight: AppTypography.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.captionSmall.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: isSelected
                      ? AppTypography.semiBold
                      : AppTypography.regular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
