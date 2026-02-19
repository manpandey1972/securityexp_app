import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/themes/app_shape_config.dart';
import 'package:greenhive_app/shared/themes/app_shape_extensions.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';
import 'package:greenhive_app/features/admin/presentation/view_models/admin_ticket_detail_view_model.dart';
import 'ticket_badges.dart';

/// Shows status picker bottom sheet
void showStatusPicker(
  BuildContext context,
  AdminTicketDetailViewModel viewModel,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Status',
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...TicketStatus.values.map(
              (status) => ListTile(
                leading: Icon(
                  TicketUIHelpers.getStatusIcon(status),
                  color: TicketUIHelpers.getStatusColor(status),
                ),
                title: Text(
                  TicketUIHelpers.getStatusLabel(status),
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                selected: viewModel.state.ticket?.status == status,
                onTap: () async {
                  Navigator.pop(context);
                  final success = await viewModel.updateStatus(status);
                  if (success) {
                    SnackbarService.show(
                      'Status updated to ${TicketUIHelpers.getStatusLabel(status)}',
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows priority picker bottom sheet
void showPriorityPicker(
  BuildContext context,
  AdminTicketDetailViewModel viewModel,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Priority',
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...TicketPriority.values.map(
              (priority) => ListTile(
                leading: Icon(
                  Icons.flag,
                  color: TicketUIHelpers.getPriorityColor(priority),
                ),
                title: Text(
                  TicketUIHelpers.getPriorityLabel(priority),
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                selected: viewModel.state.ticket?.priority == priority,
                onTap: () async {
                  Navigator.pop(context);
                  final success = await viewModel.updatePriority(priority);
                  if (success) {
                    SnackbarService.show(
                      'Priority updated to ${TicketUIHelpers.getPriorityLabel(priority)}',
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows resolve ticket dialog
void showResolveDialog(
  BuildContext context,
  AdminTicketDetailViewModel viewModel,
) {
  final resolutionController = TextEditingController();
  ResolutionType? selectedType = ResolutionType.fixed;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Resolve Ticket',
          style: AppTypography.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resolution Type',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ResolutionType>(
              initialValue: selectedType,
              dropdownColor: AppColors.surface,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: ResolutionType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedType = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Resolution Summary',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: resolutionController,
              maxLines: 3,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Describe how the issue was resolved...',
                hintStyle: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ).withRoundedShape(radius: AppShapeConfig.roundedRadius),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              if (resolutionController.text.trim().isEmpty) {
                SnackbarService.show('Please enter a resolution summary');
                return;
              }
              Navigator.pop(context);
              final success = await viewModel.resolveTicket(
                resolution: resolutionController.text.trim(),
                resolutionType: selectedType!,
              );
              if (success) {
                SnackbarService.show('Ticket resolved');
              }
            },
            child: const Text('Resolve'),
          ),
        ],
      ),
    ),
  );
}
