import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_borders.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_section_wrapper.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_dashboard_view_model.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_users_view_model.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_skills_view_model.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_faqs_view_model.dart';
import 'package:securityexperts_app/features/admin/services/admin_ticket_service.dart';
import 'package:securityexperts_app/features/admin/presentation/state/admin_state.dart';
import 'package:securityexperts_app/features/admin/pages/admin_tickets_page.dart';
import 'package:securityexperts_app/features/admin/pages/admin_ticket_detail_page.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_users_content.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_skills_content.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_faqs_content.dart';
import 'package:securityexperts_app/shared/animations/page_transitions.dart';

/// Admin dashboard page with bottom navigation for Tickets, Users, Skills, and FAQs.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminRouteGuard(
      minimumRole: UserRole.support,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AdminDashboardViewModel()..initialize(),
          ),
          ChangeNotifierProvider(
            create: (_) => AdminUsersViewModel()..initialize(),
          ),
          ChangeNotifierProvider(
            create: (_) => AdminSkillsViewModel()..initialize(),
          ),
          ChangeNotifierProvider(
            create: (_) => AdminFaqsViewModel()..initialize(),
          ),
        ],
        child: const _AdminDashboardView(),
      ),
    );
  }
}

class _AdminDashboardView extends StatefulWidget {
  const _AdminDashboardView();

  @override
  State<_AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<_AdminDashboardView> {
  int _selectedIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number,
      label: 'Tickets',
    ),
    _NavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Users',
    ),
    _NavItem(
      icon: Icons.psychology_outlined,
      activeIcon: Icons.psychology,
      label: 'Skills',
    ),
    _NavItem(icon: Icons.help_outline, activeIcon: Icons.help, label: 'FAQs'),
  ];

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  String get _appBarTitle {
    switch (_selectedIndex) {
      case 0:
        return 'Ticket Dashboard';
      case 1:
        return 'User Management';
      case 2:
        return 'Skills Management';
      case 3:
        return 'FAQ Management';
      default:
        return 'Admin Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminDashboardViewModel>();
    final state = viewModel.state;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _appBarTitle,
          style: AppTypography.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _selectedIndex == 0 && state.isLoading
                ? null
                : () => _refreshCurrentTab(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Content area with padding for bottom nav
          Padding(
            padding: const EdgeInsets.only(bottom: 70),
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildTicketDashboard(viewModel, state),
                const AdminUsersContent(),
                const AdminSkillsContent(),
                const AdminFaqsContent(),
              ],
            ),
          ),
          // Floating pill-shaped navigation bar
          Positioned(bottom: 12, left: 12, right: 12, child: _buildBottomNav()),
        ],
      ),
    );
  }

  void _refreshCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        context.read<AdminDashboardViewModel>().refresh();
        break;
      case 1:
        context.read<AdminUsersViewModel>().initialize();
        break;
      case 2:
        context.read<AdminSkillsViewModel>().initialize();
        break;
      case 3:
        context.read<AdminFaqsViewModel>().initialize();
        break;
    }
  }

  Widget _buildBottomNav() {
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
            border: Border.all(color: AppColors.white.withValues(alpha: 0.3), width: 1.5),
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
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _selectedIndex == index;
              return _buildNavItem(item, index, isSelected);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavItemTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
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

  Widget _buildTicketDashboard(
    AdminDashboardViewModel viewModel,
    AdminDashboardState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _buildErrorState(state.error!, viewModel);
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(context, state.stats),
            const SizedBox(height: 24),
            _buildRecentTickets(context, state.recentTickets),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, AdminDashboardViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            error,
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          AppButtonVariants.secondary(
            onPressed: () => viewModel.refresh(),
            label: 'Retry',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, TicketStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary stats row - most important metrics
        Row(
          children: [
            Expanded(
              child: _CompactStatCard(
                title: 'Open',
                value: stats.openTickets.toString(),
                icon: Icons.inbox,
                color: AppColors.warning,
                onTap: () => _navigateToTickets(context, TicketStatus.open),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactStatCard(
                title: 'In Progress',
                value: stats.inProgressTickets.toString(),
                icon: Icons.pending_actions,
                color: AppColors.info,
                onTap: () =>
                    _navigateToTickets(context, TicketStatus.inProgress),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactStatCard(
                title: 'Resolved',
                value: stats.resolvedTickets.toString(),
                icon: Icons.check_circle,
                color: AppColors.primary,
                onTap: () => _navigateToTickets(context, TicketStatus.resolved),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Secondary stats row - additional filters
        Row(
          children: [
            Expanded(
              child: _CompactStatCard(
                title: 'High Priority',
                value: stats.highPriorityTickets.toString(),
                icon: Icons.priority_high,
                color: AppColors.error,
                onTap: () => _navigateToTicketsWithPriority(
                  context,
                  TicketPriority.high,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactStatCard(
                title: 'Unassigned',
                value: stats.unassignedTickets.toString(),
                icon: Icons.person_off,
                color: AppColors.textSecondary,
                onTap: () => _navigateToUnassigned(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactStatCard(
                title: 'Today',
                value: stats.ticketsToday.toString(),
                icon: Icons.today,
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _navigateToTickets(BuildContext context, TicketStatus status) {
    Navigator.of(context).push(
      PageTransitions.slideFromRight(
        page: AdminTicketsPage(initialStatus: status),
      ),
    );
  }

  void _navigateToTicketsWithPriority(
    BuildContext context,
    TicketPriority priority,
  ) {
    Navigator.of(context).push(
      PageTransitions.slideFromRight(
        page: AdminTicketsPage(initialPriority: priority),
      ),
    );
  }

  void _navigateToUnassigned(BuildContext context) {
    Navigator.of(context).push(
      PageTransitions.slideFromRight(
        page: const AdminTicketsPage(initialUnassignedOnly: true),
      ),
    );
  }

  Widget _buildRecentTickets(
    BuildContext context,
    List<SupportTicket> tickets,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with integrated action
        InkWell(
          onTap: () => Navigator.of(context).push(
            PageTransitions.slideFromRight(page: const AdminTicketsPage()),
          ),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Tickets',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (tickets.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent tickets',
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...tickets.map((ticket) => _RecentTicketCard(ticket: ticket)),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _CompactStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CompactStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTicketCard extends StatelessWidget {
  final SupportTicket ticket;

  const _RecentTicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _navigateToDetail(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildStatusIndicator(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            ticket.ticketNumber,
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPriorityBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ticket.subject,
                        style: AppTypography.bodyRegular.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ticket.userEmail,
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color color;
    switch (ticket.status) {
      case TicketStatus.open:
        color = AppColors.warning;
        break;
      case TicketStatus.inProgress:
      case TicketStatus.inReview:
        color = AppColors.info;
        break;
      case TicketStatus.resolved:
        color = AppColors.primary;
        break;
      case TicketStatus.closed:
        color = AppColors.textMuted;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildPriorityBadge() {
    if (ticket.priority == TicketPriority.low ||
        ticket.priority == TicketPriority.medium) {
      return const SizedBox.shrink();
    }

    final isCritical = ticket.priority == TicketPriority.critical;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isCritical ? AppColors.error : AppColors.warning)
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isCritical ? 'CRITICAL' : 'HIGH',
        style: AppTypography.captionSmall.copyWith(
          color: isCritical ? AppColors.error : AppColors.warning,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.of(context).push(
      PageTransitions.slideFromRight(
        page: AdminTicketDetailPage(ticketId: ticket.id),
      ),
    );
  }
}
