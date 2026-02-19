import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';

class SnackbarService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void show(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.bodyRegular,
        ),
        duration: duration,
        backgroundColor: AppColors.divider,
      ),
    );
  }
}
