import 'package:flutter/material.dart';
import 'package:securityexperts_app/features/chat_list/pages/chat_page.dart';

/// Reusable Chats Tab Widget
/// Self-contained chats interface with loading and error states
class ChatsTab extends StatelessWidget {
  final Function()? onLoadRequested;
  final Function(Function())? onRegisterLoadCallback;

  const ChatsTab({
    super.key,
    this.onLoadRequested,
    this.onRegisterLoadCallback,
  });

  @override
  Widget build(BuildContext context) {
    // Register load callback when tab is built
    if (onRegisterLoadCallback != null) {
      onRegisterLoadCallback!(() {
        // Trigger load on chat page
        if (onLoadRequested != null) {
          onLoadRequested!();
        }
      });
    }

    return ChatPage(
      onLoadRequested: onLoadRequested,
      onRegisterLoadCallback: onRegisterLoadCallback,
    );
  }
}
