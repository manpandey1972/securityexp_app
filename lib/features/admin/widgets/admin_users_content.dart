import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_users_view_model.dart';
import 'package:securityexperts_app/features/admin/services/admin_user_service.dart';
import 'package:securityexperts_app/features/admin/widgets/user/user_widgets.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

/// Embeddable content widget for user management.
/// Used in the admin dashboard's IndexedStack.
class AdminUsersContent extends StatefulWidget {
  const AdminUsersContent({super.key});

  @override
  State<AdminUsersContent> createState() => _AdminUsersContentState();
}

class _AdminUsersContentState extends State<AdminUsersContent> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleSuspension(
    AdminUsersViewModel viewModel,
    AdminUser user,
  ) async {
    final action = user.isSuspended ? 'unsuspend' : 'suspend';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${action.substring(0, 1).toUpperCase()}${action.substring(1)} User',
        ),
        content: Text(
          'Are you sure you want to $action ${user.name.isNotEmpty ? user.name : user.email ?? 'this user'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: user.isSuspended
                ? null
                : FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              action.substring(0, 1).toUpperCase() + action.substring(1),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      bool success;
      if (user.isSuspended) {
        success = await viewModel.unsuspendUser(user.id);
      } else {
        success = await viewModel.suspendUser(user.id, 'Admin action');
      }

      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('User ${action}ed')));
      }
    }
  }

  void _showUserDetails(AdminUsersViewModel viewModel, AdminUser user) {
    showUserDetailsSheet(
      context,
      user: user,
      onEditRoles: () {
        Navigator.pop(context);
        _showRoleEditor(viewModel, user);
      },
      onToggleSuspension: () {
        Navigator.pop(context);
        _toggleSuspension(viewModel, user);
      },
      formatDate: _formatDate,
    );
  }

  void _showRoleEditor(AdminUsersViewModel viewModel, AdminUser user) {
    // Note: Details sheet is already closed by the onEditRoles callback
    // Do NOT call Navigator.pop here - it would pop the admin dashboard!

    final currentRoles = List<String>.from(user.roles);
    final availableRoles = [
      {'key': 'User', 'display': 'User'},
      {'key': 'Expert', 'display': 'Expert'},
      {'key': 'Support', 'display': 'Support'},
      {'key': 'Admin', 'display': 'Admin'},
      {'key': 'SuperAdmin', 'display': 'Super Admin'},
    ];

    final scaffoldContext = context; // Capture parent context

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Edit User Roles',
            style: AppTypography.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableRoles.map((role) {
              final roleKey = role['key']!;
              final roleDisplay = role['display']!;
              final isSelected = currentRoles.contains(roleKey);
              return CheckboxListTile(
                title: Text(
                  roleDisplay,
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                value: isSelected,
                activeColor: AppColors.primary,
                onChanged: (value) {
                  setDialogState(() {
                    if (value == true) {
                      currentRoles.add(roleKey);
                    } else {
                      currentRoles.remove(roleKey);
                    }
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final messenger = ScaffoldMessenger.of(scaffoldContext);
                final success = await viewModel.updateRoles(
                  user.id,
                  currentRoles,
                );
                if (success && mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Roles updated')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  /// Calculate regular users from stats map
  int _calculateRegularUsersFromStats(Map<String, int> stats) {
    final total = stats['totalUsers'] ?? 0;
    final experts = stats['totalExperts'] ?? 0;
    final support = stats['totalSupport'] ?? 0;
    final admins = stats['totalAdmins'] ?? 0;
    final superAdmin = stats['totalSuperAdmin'] ?? 0;
    // Regular users = total - (experts + support + admins + superAdmin)
    return (total - experts - support - admins - superAdmin).clamp(0, total);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats row - only rebuilds when stats change (not on filter changes)
        Selector<AdminUsersViewModel, Map<String, int>>(
          selector: (_, vm) => vm.state.stats,
          shouldRebuild: (previous, next) => previous != next,
          builder: (context, stats, _) {
            // Separate selector just for loading state
            return Selector<AdminUsersViewModel, bool>(
              selector: (_, vm) => vm.state.isLoading,
              shouldRebuild: (previous, next) => previous != next,
              builder: (context, isLoading, _) {
                if (isLoading && stats.isEmpty) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatCard(
                          label: 'Total',
                          value: stats['totalUsers']?.toString() ?? '0',
                          color: AppColors.primary,
                          filterKey: null,
                          isSuspendedFilter: false,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          label: 'Users',
                          value: _calculateRegularUsersFromStats(stats).toString(),
                          color: AppColors.info,
                          filterKey: 'user',
                          isSuspendedFilter: false,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          label: 'Experts',
                          value: stats['totalExperts']?.toString() ?? '0',
                          color: AppColors.primaryLight,
                          filterKey: 'Expert',
                          isSuspendedFilter: false,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          label: 'Support',
                          value: stats['totalSupport']?.toString() ?? '0',
                          color: AppColors.warning,
                          filterKey: 'Support',
                          isSuspendedFilter: false,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          label: 'Admins',
                          value: stats['totalAdmins']?.toString() ?? '0',
                          color: AppColors.primaryLight,
                          filterKey: 'Admin',
                          isSuspendedFilter: false,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          label: 'SuperAdmin',
                          value: stats['totalSuperAdmin']?.toString() ?? '0',
                          color: AppColors.purple,
                          filterKey: 'SuperAdmin',
                          isSuspendedFilter: false,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          label: 'Suspended',
                          value: stats['suspendedUsers']?.toString() ?? '0',
                          color: AppColors.error,
                          filterKey: null,
                          isSuspendedFilter: true,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),

        // Search - only rebuilds when search query changes
        Selector<AdminUsersViewModel, String>(
          selector: (_, viewModel) => viewModel.state.filters.searchQuery,
          shouldRebuild: (previous, next) => previous != next,
          builder: (context, searchQuery, _) {
            final viewModel = context.read<AdminUsersViewModel>();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            viewModel.searchUsers('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (value) {
                  viewModel.setSearchQuery(value);
                },
                onSubmitted: (value) => viewModel.searchUsers(value),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Error and user list - only rebuilds when users, error, or loading state changes
        Expanded(
          child: Selector<AdminUsersViewModel, Map<String, dynamic>>(
            selector: (_, viewModel) => {
              'users': viewModel.state.filteredUsers,
              'error': viewModel.state.error,
              'isLoading': viewModel.state.isLoading,
            },
            shouldRebuild: (previous, next) {
              return previous['isLoading'] != next['isLoading'] ||
                     previous['error'] != next['error'] ||
                     previous['users'] != next['users'];
            },
            builder: (context, data, _) {
              final viewModel = context.read<AdminUsersViewModel>();
              final users = data['users'] as List;
              final error = data['error'] as String?;
              final isLoading = data['isLoading'] as bool;

              return Column(
                children: [
                  // Error message
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => viewModel.initialize(),
                              color: AppColors.error,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Loading/List/Empty
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : users.isEmpty
                            ? const UserEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: users.length,
                                itemBuilder: (context, index) {
                                  final user = users[index] as AdminUser;
                                  return UserListItem(
                                    user: user,
                                    onTap: () => _showUserDetails(viewModel, user),
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Individual stat card that manages its own selection state.
/// Each card only rebuilds when its specific filter condition changes.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? filterKey; // null means "Total" (no filter)
  final bool isSuspendedFilter;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.filterKey,
    required this.isSuspendedFilter,
  });

  @override
  Widget build(BuildContext context) {
    // Each card selects only its own selection state
    return Selector<AdminUsersViewModel, bool>(
      selector: (_, viewModel) {
        final filters = viewModel.state.filters;
        if (isSuspendedFilter) {
          return filters.suspendedFilter == true;
        } else if (filterKey == null) {
          // "Total" is selected when no filters are active
          return filters.roleFilter == null && filters.suspendedFilter == null;
        } else {
          return filters.roleFilter == filterKey && filters.suspendedFilter != true;
        }
      },
      shouldRebuild: (previous, next) => previous != next,
      builder: (context, isSelected, _) {
        final viewModel = context.read<AdminUsersViewModel>();
        
        return OutlinedButton(
          onPressed: () => _handleTap(viewModel),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: isSelected ? color : AppColors.divider,
              width: isSelected ? 2 : 1,
            ),
            backgroundColor: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value,
                  style: AppTypography.captionTiny.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleTap(AdminUsersViewModel viewModel) {
    final filters = viewModel.state.filters;
    
    if (isSuspendedFilter) {
      // Toggle suspended filter
      final isCurrentlySelected = filters.suspendedFilter == true;
      if (isCurrentlySelected) {
        viewModel.clearFilters();
      } else {
        viewModel.updateFilters(
          filters.copyWith(suspendedFilter: true, clearRole: true),
        );
      }
    } else if (filterKey == null) {
      // "Total" - clear all filters
      viewModel.clearFilters();
    } else {
      // Role filter
      final isCurrentlySelected = filters.roleFilter == filterKey && filters.suspendedFilter != true;
      if (isCurrentlySelected) {
        viewModel.clearFilters();
      } else {
        viewModel.updateFilters(
          filters.copyWith(roleFilter: filterKey, clearSuspended: true),
        );
      }
    }
  }
}
