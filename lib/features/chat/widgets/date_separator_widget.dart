import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/features/chat/utils/chat_utils.dart';

/// Date separator widget shown between messages from different days
class DateSeparatorWidget extends StatelessWidget {
  final DateTime date;

  const DateSeparatorWidget({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              DateTimeFormatter.formatDateSeparator(date),
              style: AppTypography.subtitle.copyWith(
                color: AppColors.textSecondary,
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}
