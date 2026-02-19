import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_section_wrapper.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_tickets_view_model.dart';
import 'package:securityexperts_app/features/admin/presentation/state/admin_state.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';
import 'package:securityexperts_app/features/admin/pages/admin_ticket_detail_page.dart';
import 'package:securityexperts_app/shared/animations/page_transitions.dart';
import 'package:intl/intl.dart';

/// Admin tickets list page with filters.
class AdminTicketsPage extends StatelessWidget {
  final TicketStatus? initialStatus;
  final TicketPriority? initialPriority;
  final bool initialUnassignedOnly;

  const AdminTicketsPage({
    super.key,
    this.initialStatus,
    this.initialPriority,
    this.initialUnassignedOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return AdminRouteGuard(
      minimumRole: UserRole.support,
      child: ChangeNotifierProvider(
        create: (_) {
          final vm = AdminTicketsViewModel();
          // Apply initial filters
          if (initialStatus != null ||
              initialPriority != null ||
              initialUnassignedOnly) {
            vm.updateFilters(
              AdminTicketFilters(
                status: initialStatus,
                priority: initialPriority,
                unassignedOnly: initialUnassignedOnly,
              ),
            );
          } else {
            vm.initialize();
          }
          return vm;
        },
        child: const _AdminTicketsView(),
      ),
    );
  }
}

class _AdminTicketsView extends StatefulWidget {
  const _AdminTicketsView();

  @override
  State<_AdminTicketsView> createState() => _AdminTicketsViewState();
}

class _AdminTicketsViewState extends State<_AdminTicketsView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<AdminTicketsViewModel>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminTicketsViewModel>();
    final state = viewModel.state;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Support Tickets',
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.filter_list,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => _showFiltersSheet(context, viewModel),
              ),
              if (state.filters.activeFilterCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      state.filters.activeFilterCount.toString(),
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: viewModel.setSearchQuery,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search tickets...',
                hintStyle: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          viewModel.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Active filters chips
          if (state.filters.hasActiveFilters)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (state.filters.status != null)
                    _FilterChip(
                      label: _getStatusLabel(state.filters.status!),
                      onRemove: () => viewModel.setStatusFilter(null),
                    ),
                  if (state.filters.priority != null)
                    _FilterChip(
                      label: _getPriorityLabel(state.filters.priority!),
                      onRemove: () => viewModel.setPriorityFilter(null),
                    ),
                  if (state.filters.category != null)
                    _FilterChip(
                      label: _getCategoryLabel(state.filters.category!),
                      onRemove: () => viewModel.setCategoryFilter(null),
                    ),
                  if (state.filters.unassignedOnly)
                    _FilterChip(
                      label: 'Unassigned',
                      onRemove: viewModel.toggleUnassignedOnly,
                    ),
                  TextButton(
                    onPressed: viewModel.clearFilters,
                    child: Text(
                      'Clear all',
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Tickets list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                ? _buildErrorState(state.error!, viewModel)
                : state.filteredTickets.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: viewModel.refresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount:
                          state.filteredTickets.length +
                          (state.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.filteredTickets.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return _TicketListItem(
                          ticket: state.filteredTickets[index],
                          onTap: () => _navigateToDetail(
                            context,
                            state.filteredTickets[index],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, AdminTicketsViewModel viewModel) {
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No tickets found',
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showFiltersSheet(
    BuildContext context,
    AdminTicketsViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FiltersSheet(
        filters: viewModel.state.filters,
        onApply: (filters) {
          viewModel.updateFilters(filters);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _navigateToDetail(BuildContext context, SupportTicket ticket) {
    Navigator.of(context).push(
      PageTransitions.slideFromRight(
        page: AdminTicketDetailPage(ticketId: ticket.id),
      ),
    );
  }

  String _getStatusLabel(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.inReview:
        return 'In Review';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
    }
  }

  String _getPriorityLabel(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.critical:
        return 'Critical';
    }
  }

  String _getCategoryLabel(TicketCategory category) {
    return category.displayName;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          label,
          style: AppTypography.captionSmall.copyWith(color: AppColors.primary),
        ),
        deleteIcon: const Icon(Icons.close, size: 16),
        deleteIconColor: AppColors.primary,
        onDeleted: onRemove,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

class _TicketListItem extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;

  const _TicketListItem({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: ticket number, status, priority
                Row(
                  children: [
                    Text(
                      ticket.ticketNumber,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(),
                    const SizedBox(width: 8),
                    _buildPriorityBadge(),
                  ],
                ),
                const SizedBox(height: 8),

                // Subject
                Text(
                  ticket.subject,
                  style: AppTypography.bodyEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Footer: user info, category, date
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ticket.userName ?? ticket.userEmail,
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryBadge(),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(ticket.lastActivityAt),
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),

                // Assigned badge if assigned
                if (ticket.assignedTo != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.assignment_ind, size: 14, color: AppColors.info),
                      const SizedBox(width: 4),
                      Text(
                        'Assigned',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String label;

    switch (ticket.status) {
      case TicketStatus.open:
        bgColor = AppColors.warning.withValues(alpha: 0.2);
        textColor = AppColors.warning;
        label = 'Open';
        break;
      case TicketStatus.inProgress:
        bgColor = AppColors.info.withValues(alpha: 0.2);
        textColor = AppColors.info;
        label = 'In Progress';
        break;
      case TicketStatus.inReview:
        bgColor = AppColors.info.withValues(alpha: 0.2);
        textColor = AppColors.info;
        label = 'In Review';
        break;
      case TicketStatus.resolved:
        bgColor = AppColors.primary.withValues(alpha: 0.2);
        textColor = AppColors.primary;
        label = 'Resolved';
        break;
      case TicketStatus.closed:
        bgColor = AppColors.textMuted.withValues(alpha: 0.2);
        textColor = AppColors.textMuted;
        label = 'Closed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.captionSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge() {
    if (ticket.priority == TicketPriority.low ||
        ticket.priority == TicketPriority.medium) {
      return const SizedBox.shrink();
    }

    final isCritical = ticket.priority == TicketPriority.critical;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isCritical ? AppColors.error : AppColors.warning).withValues(
          alpha: 0.2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isCritical ? 'CRITICAL' : 'HIGH',
        style: AppTypography.captionSmall.copyWith(
          color: isCritical ? AppColors.error : AppColors.warning,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        ticket.category.name,
        style: AppTypography.captionSmall.copyWith(
          color: AppColors.textSecondary,
          fontSize: 10,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}

class _FiltersSheet extends StatefulWidget {
  final AdminTicketFilters filters;
  final Function(AdminTicketFilters) onApply;

  const _FiltersSheet({required this.filters, required this.onApply});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late AdminTicketFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.filters;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filters = const AdminTicketFilters();
                    });
                  },
                  child: Text(
                    'Reset',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status filter
            Text(
              'Status',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TicketStatus.values.map((status) {
                final isSelected = _filters.status == status;
                return ChoiceChip(
                  label: Text(_getStatusLabel(status)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _filters = _filters.copyWith(
                        status: selected ? status : null,
                        clearStatus: !selected,
                      );
                    });
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  labelStyle: AppTypography.captionSmall.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Priority filter
            Text(
              'Priority',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TicketPriority.values.map((priority) {
                final isSelected = _filters.priority == priority;
                return ChoiceChip(
                  label: Text(_getPriorityLabel(priority)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _filters = _filters.copyWith(
                        priority: selected ? priority : null,
                        clearPriority: !selected,
                      );
                    });
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  labelStyle: AppTypography.captionSmall.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Unassigned only toggle
            SwitchListTile(
              title: Text(
                'Unassigned only',
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              value: _filters.unassignedOnly,
              onChanged: (value) {
                setState(() {
                  _filters = _filters.copyWith(unassignedOnly: value);
                });
              },
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: AppButtonVariants.secondary(
                onPressed: () => widget.onApply(_filters),
                label: 'Apply Filters',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.inReview:
        return 'In Review';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
    }
  }

  String _getPriorityLabel(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.critical:
        return 'Critical';
    }
  }
}
