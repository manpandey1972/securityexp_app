import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

import '../data/models/models.dart';

/// Widget for selecting ticket type.
///
/// Displays a grid of ticket type options with icons and descriptions.
class TicketTypeSelector extends StatelessWidget {
  /// Currently selected type.
  final TicketType? selectedType;

  /// Callback when type is selected.
  final ValueChanged<TicketType> onSelected;

  const TicketTypeSelector({
    super.key,
    this.selectedType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final types = TicketType.values
        .where((type) => type != TicketType.payment && type != TicketType.bug && type != TicketType.account)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What can we help you with?',
          style: AppTypography.bodyEmphasis.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: types.map((type) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type != types.last ? 8 : 0,
                ),
                child: _TicketTypeCard(
                  type: type,
                  isSelected: selectedType == type,
                  onTap: () => onSelected(type),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TicketTypeCard extends StatelessWidget {
  final TicketType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _TicketTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: SizedBox(
            height: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getIcon(), color: AppColors.textPrimary, size: 18),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    type.displayName,
                    style: AppTypography.captionSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case TicketType.bug:
        return Icons.bug_report;
      case TicketType.featureRequest:
        return Icons.lightbulb_outline;
      case TicketType.feedback:
        return Icons.feedback_outlined;
      case TicketType.support:
        return Icons.help_outline;
      case TicketType.account:
        return Icons.person_outline;
      case TicketType.payment:
        return Icons.payment;
    }
  }
}
