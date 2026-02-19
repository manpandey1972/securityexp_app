import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/providers/auth_provider.dart';
import 'package:securityexperts_app/providers/role_provider.dart';
import 'package:securityexperts_app/shared/services/upload_manager.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/auth/role_service.dart';

/// Provider utilities and factory functions

/// Create all app providers as a list for MultiProvider
/// Usage: MultiProvider(providers: createAppProviders(), child: App())
List<ChangeNotifierProvider> createAppProviders() {
  return [
    // Auth provider - must be created first
    // lazy: false ensures AuthState is created immediately, not when first accessed
    // This is critical for FCM/VoIP token initialization on app startup
    ChangeNotifierProvider<AuthState>(
      create: (_) => AuthState(sl<FirebaseAuth>()),
      lazy: false,
    ),
    // Role provider - streams user role from Firestore for admin features
    // lazy: false ensures role is fetched immediately for proper UI rendering
    // Passes FirebaseAuth instance to listen for auth state changes
    // This ensures role stream is re-subscribed when user logs in/out
    ChangeNotifierProvider<RoleProvider>(
      create: (_) => RoleProvider(
        sl<RoleService>(),
        auth: sl<FirebaseAuth>(),
      ),
      lazy: false,
    ),
    // Upload manager - global upload manager for background uploads
    // Uses existing singleton from service locator
    ChangeNotifierProvider<UploadManager>.value(
      value: sl<UploadManager>(),
    ),
  ];
}

/// Consumer builder helper for auth state
typedef AuthConsumerBuilder =
    Widget Function(BuildContext context, AuthState authState, Widget? child);
