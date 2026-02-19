import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_users_view_model.dart';
import 'package:securityexperts_app/features/admin/services/admin_user_service.dart';
import 'package:securityexperts_app/features/admin/widgets/user/user_widgets.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_section_wrapper.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';

/// Admin page for managing users.
class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminRouteGuard(
      minimumRole: UserRole.admin,
      child: ChangeNotifierProvider(
        create: (_) => AdminUsersViewModel()..initialize(),
        child: const _AdminUsersView(),
      ),
    );
  }
}

class _AdminUsersView extends StatefulWidget {
  const _AdminUsersView();

  @override
  State<_AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<_AdminUsersView> {
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
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.pop(context, true),
            label: action.substring(0, 1).toUpperCase() + action.substring(1),
            isDestructive: !user.isSuspended,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => UserDetailsSheet(
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
      ),
    );
  }

  void _showRoleEditor(AdminUsersViewModel viewModel, AdminUser user) {
    Navigator.pop(context); // Close details sheet

    final currentRoles = List<String>.from(user.roles);
    final availableRoles = [
      {'key': 'Consumer', 'display': 'User'},
      {'key': 'Expert', 'display': 'Expert'},
      {'key': 'Support', 'display': 'Support'},
      {'key': 'Admin', 'display': 'Admin'},
      {'key': 'SuperAdmin', 'display': 'Super Admin'},
    ];

    final scaffoldContext = context; // Capture parent context

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit User Roles'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableRoles.map((role) {
              final roleKey = role['key']!;
              final roleDisplay = role['display']!;
              final isSelected = currentRoles.contains(roleKey);
              return CheckboxListTile(
                title: Text(roleDisplay),
                value: isSelected,
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminUsersViewModel>();
    final state = viewModel.state;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'User Management',
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
            onPressed: () => viewModel.initialize(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats row - filter chips style
          if (!state.isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _UserTypeFilterChip(
                      label: 'Total',
                      count: int.tryParse(state.stats['totalUsers']?.toString() ?? '0') ?? 0,
                      isSelected: false,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _UserTypeFilterChip(
                      label: 'Experts',
                      count: int.tryParse(state.stats['totalExperts']?.toString() ?? '0') ?? 0,
                      isSelected: false,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 8),
                    _UserTypeFilterChip(
                      label: 'Admins',
                      count: int.tryParse(state.stats['totalAdmins']?.toString() ?? '0') ?? 0,
                      isSelected: false,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 8),
                    _UserTypeFilterChip(
                      label: 'Suspended',
                      count: int.tryParse(state.stats['suspendedUsers']?.toString() ?? '0') ?? 0,
                      isSelected: false,
                      color: AppColors.error,
                    ),
                  ],
                ),
              ),
            ),

          // Search and filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.filters.searchQuery.isNotEmpty
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
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected:
                            state.filters.roleFilter == null &&
                            state.filters.suspendedFilter == null,
                        onSelected: (value) {
                          viewModel.clearFilters();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Users'),
                        selected: state.filters.roleFilter == 'user',
                        onSelected: (value) {
                          viewModel.setRoleFilter(value ? 'user' : null);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Experts'),
                        selected: state.filters.roleFilter == 'Expert',
                        onSelected: (value) {
                          viewModel.setRoleFilter(value ? 'Expert' : null);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Admins'),
                        selected: state.filters.roleFilter == 'Admin',
                        onSelected: (value) {
                          viewModel.setRoleFilter(value ? 'Admin' : null);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Suspended'),
                        selected: state.filters.suspendedFilter == true,
                        onSelected: (value) {
                          viewModel.setSuspendedFilter(value ? true : null);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Error message
          if (state.error != null)
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
                        state.error!,
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

          // User list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Builder(
                    builder: (context) {
                      final filteredUsers = state.filteredUsers;
                      return filteredUsers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No users found',
                                    style: AppTypography.bodyRegular.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                return UserListItem(
                                  user: user,
                                  onTap: () => _showUserDetails(viewModel, user),
                                );
                              },
                            );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserTypeFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;

  const _UserTypeFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? color : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: Colors.transparent,
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
              '$count',
              style: AppTypography.captionTiny.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
