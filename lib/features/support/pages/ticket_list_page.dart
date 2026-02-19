import 'package:flutter/material.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/widgets/empty_state_widget.dart';
import 'package:securityexperts_app/shared/widgets/error_state_widget.dart';
import 'package:securityexperts_app/shared/widgets/shimmer_loading.dart';

import '../data/models/models.dart';
import '../services/support_service.dart';
import '../presentation/view_models/ticket_list_view_model.dart';
import '../widgets/ticket_card.dart';
import 'new_ticket_page.dart';
import 'ticket_detail_page.dart';

/// Page displaying list of user's support tickets.
class TicketListPage extends StatefulWidget {
  const TicketListPage({super.key});

  @override
  State<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends State<TicketListPage> {
  late final TicketListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = TicketListViewModel(supportService: sl<SupportService>());
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('My Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToNewTicket,
            tooltip: 'New Ticket',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final state = _viewModel.state;

          if (state.isLoading && state.tickets.isEmpty) {
            return _buildLoading();
          }

          if (state.hasError && state.tickets.isEmpty) {
            return _buildError(state.error!);
          }

          if (!state.hasTickets) {
            return _buildEmptyState();
          }

          return _buildTicketList();
        },
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerLoading.shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 20,
                    color: AppColors.white,
                  ),
                  const SizedBox(height: 12),
                  Container(width: 150, height: 16, color: AppColors.white),
                  const SizedBox(height: 8),
                  Container(width: 100, height: 14, color: AppColors.white),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(String error) {
    return ErrorStateWidget(
      title: 'Something went wrong',
      message: error,
      onRetry: _viewModel.refresh,
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.support_agent_outlined,
      title: 'No Tickets Yet',
      description:
          'Need help? Create a support ticket and we\'ll get back to you.',
    );
  }

  Widget _buildTicketList() {
    final state = _viewModel.state;

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      color: AppColors.primary,
      child: Column(
        children: [
          // Filter chips
          _buildFilterChips(),
          // Ticket list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: state.tickets.length,
              itemBuilder: (context, index) {
                final ticket = state.tickets[index];
                return TicketCard(
                  ticket: ticket,
                  onTap: () => _navigateToTicketDetail(ticket),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final state = _viewModel.state;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              isSelected: state.statusFilter == null,
              onSelected: () => _viewModel.clearStatusFilter(),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Open',
              isSelected: state.statusFilter == TicketStatus.open,
              onSelected: () => _viewModel.setStatusFilter(TicketStatus.open),
              count: state.openCount,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'In Progress',
              isSelected: state.statusFilter == TicketStatus.inProgress,
              onSelected: state.inProgressCount > 0
                  ? () => _viewModel.setStatusFilter(TicketStatus.inProgress)
                  : null,
              count: state.inProgressCount,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Resolved',
              isSelected: state.statusFilter == TicketStatus.resolved,
              onSelected: state.resolvedCount > 0
                  ? () => _viewModel.setStatusFilter(TicketStatus.resolved)
                  : null,
              count: state.resolvedCount,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Closed',
              isSelected: state.statusFilter == TicketStatus.closed,
              onSelected: state.closedCount > 0
                  ? () => _viewModel.setStatusFilter(TicketStatus.closed)
                  : null,
              count: state.closedCount,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToNewTicket() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const NewTicketPage()));
  }

  void _navigateToTicketDetail(SupportTicket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TicketDetailPage(ticketId: ticket.id),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onSelected;
  final int? count;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onSelected == null;
    return GestureDetector(
      onTap: isDisabled ? null : onSelected,
      child: OutlinedButton(
        onPressed: isDisabled ? null : onSelected,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          backgroundColor: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.badge.copyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.captionTiny.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
