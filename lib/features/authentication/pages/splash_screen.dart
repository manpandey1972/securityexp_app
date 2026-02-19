import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:greenhive_app/providers/auth_provider.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/features/phone_auth/pages/phone_auth_screen.dart';
import 'package:greenhive_app/features/home/pages/home_page.dart';
import 'package:greenhive_app/features/onboarding/pages/user_onboarding_page.dart';
import 'package:greenhive_app/shared/services/user_profile_service.dart';
import 'package:greenhive_app/features/profile/services/biometric_auth_service.dart';
import 'package:greenhive_app/data/repositories/user/user_repository.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';

/// Result of biometric authentication attempt
enum _BiometricResult {
  success, // User authenticated successfully
  failed, // User failed authentication (wrong biometric or cancelled)
  skipped, // Biometric couldn't be shown (e.g., CallKit UI active)
}

class SplashPage extends StatefulWidget {
  final FirebaseAuth? firebaseAuth;

  const SplashPage({super.key, this.firebaseAuth});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static Completer<void>? _authCheckCompleter;

  late final FirebaseAuth _auth;
  late final BiometricAuthService _biometricService;
  late final UserRepository _userRepository;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AppLogger _log;
  static const _tag = 'SplashPage';

  @override
  void initState() {
    super.initState();
    // Initialize pulsing animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize services from GetIt
    _auth = widget.firebaseAuth ?? FirebaseAuth.instance;
    _biometricService = sl<BiometricAuthService>();
    _userRepository = sl<UserRepository>();
    _log = sl<AppLogger>();

    // Defer auth check to after first frame to avoid "setState during build" errors.
    // This ensures navigation doesn't happen during the initial widget tree build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAuthStatus();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Prevent concurrent execution using Completer (atomic operation)
    if (_authCheckCompleter != null && !_authCheckCompleter!.isCompleted) {
      await _authCheckCompleter!.future;
      return;
    }

    // Create a new completer for this check
    _authCheckCompleter = Completer<void>();

    await ErrorHandler.handle<void>(
      operation: () async {
        await _performAuthCheck();
        _authCheckCompleter!.complete();
      },
      onError: (error) {
        _authCheckCompleter!.completeError(error);
      },
    );
  }

  Future<void> _performAuthCheck() async {
    if (!mounted) return;

    final user = _auth.currentUser;

    if (user == null) {
      // Not logged in → Phone Auth
      _navigateToPhoneAuth();
      return;
    }

    // If Face ID/biometric is enabled, authenticate first.
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    if (biometricEnabled) {
      final biometricAvailable = await _biometricService.isBiometricAvailable();

      if (!biometricAvailable) {
        _log.warning(
          'Biometric enabled but not available; logging out for safety',
          tag: _tag,
        );
        await _logout();
        return;
      }

      final authResult = await _authenticateWithBiometric();

      // If biometric was skipped (e.g., CallKit taking over), proceed without logout
      if (authResult == _BiometricResult.skipped) {
        _log.debug(
          'Biometric skipped (system UI conflict); proceeding without logout',
          tag: _tag,
        );
        // Continue to fetch profile - user is still authenticated via Firebase
      } else if (authResult == _BiometricResult.failed) {
        _log.warning('Biometric authentication failed; logging out', tag: _tag);
        await _logout();
        return;
      }
      // authResult == _BiometricResult.success - continue normally
    }

    // After biometric (or if not enabled), fetch profile from API and route
    await _fetchProfileAndRoute();
  }

  Future<void> _fetchProfileAndRoute() async {
    final user = _auth.currentUser;
    if (user == null) {
      _navigateToPhoneAuth();
      return;
    }

    final idToken = await user.getIdToken();
    if (idToken == null) {
      _log.warning('ID token is null; logging out', tag: _tag);
      await _logout();
      return;
    }

    final profile = await ErrorHandler.handle(
      operation: () => _userRepository.getCurrentUserProfile(),
      fallback: null,
      onError: (error) {
        _log.error('Error fetching profile: $error', tag: _tag);
      },
    );

    if (profile != null) {
      _log.debug('Profile loaded successfully for user: ${user.uid}', tag: _tag);
      UserProfileService().setUserProfile(profile);

      // Update last login timestamp to track app session starts
      await ErrorHandler.handle<void>(
        operation: () => _userRepository.updateLastLogin(),
        fallback: null,
        onError: (error) {
          _log.warning('Failed to update last login: $error', tag: _tag);
        },
      );

      // FCM is now initialized automatically in AuthProvider's auth state listener
      // No need to initialize here anymore

      if (mounted) {
        _navigateToHome();
      }
    } else {
      _log.warning('No user profile found', tag: _tag);
      UserProfileService().clearUserProfile();
      if (mounted) {
        _navigateToOnboarding();
      }
    }
  }

  Future<_BiometricResult> _authenticateWithBiometric() async {
    if (!mounted) return _BiometricResult.failed;

    final biometricName = await _biometricService.getBiometricTypeName();

    _log.debug('Biometric authentication starting', tag: _tag);

    try {
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Unlock Greenhive with $biometricName',
      );

      if (!mounted) return _BiometricResult.failed;

      _log.debug(
        'Biometric authentication result: ${authenticated ? 'SUCCESS' : 'FAILURE'}',
        tag: _tag,
      );

      return authenticated ? _BiometricResult.success : _BiometricResult.failed;
    } on PlatformException catch (e) {
      // Handle specific cases where biometric couldn't be shown
      // (e.g., CallKit UI is active, system dialog already showing)
      if (e.code == 'NotAvailable' ||
          e.message?.contains('User interaction required') == true ||
          e.message?.contains('interrupted') == true) {
        _log.debug(
          'Biometric skipped due to system UI conflict: ${e.message}',
          tag: _tag,
        );
        return _BiometricResult.skipped;
      }
      _log.error(
        'Biometric PlatformException: ${e.code} - ${e.message}',
        tag: _tag,
      );
      return _BiometricResult.failed;
    } catch (e, stackTrace) {
      _log.error('Biometric authentication error: $e', tag: _tag, stackTrace: stackTrace);
      return _BiometricResult.failed;
    }
  }

  Future<void> _logout() async {
    if (mounted) {
      final authState = context.read<AuthState>();
      await authState.signOut();
    }
    if (mounted) {
      _navigateToPhoneAuth();
    }
  }

  void _navigateToPhoneAuth() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PhoneAuthPage()),
    );
  }

  void _navigateToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UserOnboardingPage()),
    );
  }

  void _navigateToHome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) =>
                    Transform.scale(scale: _pulseAnimation.value, child: child),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      cacheWidth: 240,
                      cacheHeight: 240,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to GreenHive',
                style: AppTypography.headingLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
