import 'package:flutter/material.dart';
import 'package:securityexperts_app/features/calling/pages/call_history_page.dart';

/// Reusable Calls Tab Widget
/// Self-contained calls interface with call history
class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CallHistoryPage();
  }
}
