import 'package:firebase_auth/firebase_auth.dart';
import 'package:greenhive_app/providers/auth_provider.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// App-level Provider setup and initialization

/// Create auth state provider
AuthState createAuthProvider() {
  return AuthState(sl<FirebaseAuth>());
}

/// Helper extension to get current user ID from auth
extension AuthStateExtension on AuthState {
  String? getCurrentUserId() => userId;
}
