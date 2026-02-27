import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/providers/auth_provider.dart';
import 'package:securityexperts_app/providers/role_provider.dart';
import 'package:securityexperts_app/shared/services/upload_manager.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Provider utilities and factory functions

/// Create all app providers as a list for MultiProvider.
///
/// All three ChangeNotifiers are owned by GetIt (service locator).
/// We use [ChangeNotifierProvider.value] so that the widget tree can
/// access them via `context.read<T>()` / `context.watch<T>()`
/// while the actual lifecycle is managed centrally.
List<ChangeNotifierProvider> createAppProviders() {
  return [
    // Auth provider — eager singleton registered in setupServiceLocator().
    ChangeNotifierProvider<AuthState>.value(
      value: sl<AuthState>(),
    ),
    // Role provider — eager singleton registered in setupServiceLocator().
    ChangeNotifierProvider<RoleProvider>.value(
      value: sl<RoleProvider>(),
    ),
    // Upload manager — lazy singleton registered in setupServiceLocator().
    ChangeNotifierProvider<UploadManager>.value(
      value: sl<UploadManager>(),
    ),
  ];
}

/// Consumer builder helper for auth state
typedef AuthConsumerBuilder =
    Widget Function(BuildContext context, AuthState authState, Widget? child);
