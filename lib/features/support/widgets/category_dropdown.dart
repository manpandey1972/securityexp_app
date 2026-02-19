import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

import '../data/models/models.dart';

/// Dropdown widget for selecting ticket category.
class CategoryDropdown extends StatelessWidget {
  /// Currently selected category.
  final TicketCategory? selectedCategory;

  /// Callback when category is selected.
  final ValueChanged<TicketCategory?> onChanged;

  /// Hint text when nothing is selected.
  final String hint;

  /// Whether field is in error state.
  final bool hasError;

  const CategoryDropdown({
    super.key,
    this.selectedCategory,
    required this.onChanged,
    this.hint = 'Select a category',
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: AppTypography.bodyRegular.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? AppColors.error : AppColors.divider,
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TicketCategory>(
              value: selectedCategory,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  hint,
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              isExpanded: true,
              icon: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
              ),
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              items: TicketCategory.values.map((category) {
                return DropdownMenuItem<TicketCategory>(
                  value: category,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category.displayName,
                          style: AppTypography.bodyRegular,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              selectedItemBuilder: (context) {
                return TicketCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category.displayName,
                          style: AppTypography.bodyRegular.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(TicketCategory category) {
    // The enum has an icon property already
    return category.icon;
  }
}
