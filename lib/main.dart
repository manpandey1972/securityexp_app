import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/core/constants.dart';
import 'package:securityexperts_app/shared/services/pending_notification_handler.dart';
import 'package:securityexperts_app/providers/provider_setup.dart';
import 'firebase_options.dart'; // generated via flutterfire CLI
import 'features/authentication/pages/splash_screen.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/notification_service.dart';
import 'package:securityexperts_app/core/config/remote_config_service.dart';
import 'package:securityexperts_app/shared/themes/app_theme.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_shape_config.dart';
import 'package:securityexperts_app/features/calling/widgets/call_overlay.dart';
import 'package:securityexperts_app/features/calling/services/monitoring/call_listener_service.dart';
import 'package:securityexperts_app/features/chat/pages/chat_conversation_page.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/features/chat/services/user_presence_service.dart';
import 'package:securityexperts_app/features/admin/pages/admin_dashboard_page.dart';
import 'package:securityexperts_app/features/admin/pages/admin_tickets_page.dart';
import 'package:securityexperts_app/features/admin/pages/admin_ticket_detail_page.dart';
import 'package:securityexperts_app/features/admin/pages/admin_faqs_page.dart';
import 'package:securityexperts_app/features/admin/pages/admin_faq_editor_page.dart';
import 'package:securityexperts_app/features/admin/pages/admin_skills_page.dart';
import 'package:securityexperts_app/features/admin/pages/admin_skill_editor_page.dart';
import 'package:securityexperts_app/features/admin/pages/admin_users_page.dart';
import 'package:securityexperts_app/core/analytics/analytics_route_observer.dart';
import 'package:securityexperts_app/core/routing/app_routes.dart';
import 'package:securityexperts_app/core/debug/shake_handler.dart';

// Track main() calls for debugging duplicate log issues
int _mainCallCount = 0;
const _tag = 'Main';

/// Installs a global error filter to suppress known WebRTC errors on web.
/// These errors occur when peer connection closes during track operations
/// (e.g., call rejection while camera is being enabled) and cannot be
/// caught by normal try-catch due to microtask scheduling in dart_webrtc.
void _installWebRtcErrorFilter() {
  // Handle uncaught async errors (errors in Futures that escape zones)
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString();

    // Suppress known WebRTC errors that occur during normal call termination
    if (errorStr.contains('InvalidStateError') &&
        (errorStr.contains('replaceTrack') ||
            errorStr.contains('peer connection is closed') ||
            errorStr.contains('RTCRtpSender'))) {
      // Silently suppress - this is expected when call ends during media setup
      return true; // Error handled, don't propagate
    }

    return false; // Not handled, let default handler process it
  };

  // Also handle Flutter framework errors
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorStr = details.exception.toString();

    // Suppress known WebRTC errors
    if (errorStr.contains('InvalidStateError') &&
        (errorStr.contains('replaceTrack') ||
            errorStr.contains('peer connection is closed'))) {
      return; // Silently suppress
    }

    // Forward all other errors to original handler
    if (originalOnError != null) {
      originalOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
}

void main() async {
  _mainCallCount++;

  WidgetsFlutterBinding.ensureInitialized();

  // Install global error handler to suppress known WebRTC errors on web
  // These errors occur when peer connection closes during track operations
  // and cannot be caught by normal try-catch due to microtask scheduling
  if (kIsWeb) {
    _installWebRtcErrorFilter();
  }

  await ErrorHandler.handle<void>(
    operation: () async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Activate App Check — uses Debug provider in debug builds so that
      // simulators / emulators work; Device Check (iOS) and Play Integrity
      // (Android) are used in release builds. Web uses free reCAPTCHA v3.
      await FirebaseAppCheck.instance.activate(
        providerAndroid:
            kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
        providerApple:
            kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
        providerWeb: ReCaptchaV3Provider('6Ld3UHksAAAAAPAAR4sXYc6Dz7tw-4ZNE4cOQ8EQ'),
      );

      // Ensure Firebase is ready before proceeding
      await Future.delayed(AppConstants.firebaseInitDelay);

      // Setup all application services with dependency injection
      await setupServiceLocator();

      // Initialize shake detector for verbose logging toggle
      ShakeHandler.setup();

      // Initialize logger after service locator is set up
      final logger = sl<AppLogger>();
      logger.debug('[Main] main() called (count: $_mainCallCount)', tag: _tag);
      logger.debug('All services initialized via service locator', tag: _tag);

      // Handle cold start notification tap (app was terminated)
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        sl<AppLogger>().debug(
          '📬 App launched from notification: ${initialMessage.messageId}',
          tag: _tag,
        );
        PendingNotificationHandler.setPendingMessage(initialMessage);
      }

      // Enable Firebase foreground notifications for iOS banners
      // We still handle the notification via our local service, but this ensures iOS shows the banner
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      // Request notification permission on web
      if (kIsWeb) {
        await ErrorHandler.handle<void>(
          operation: () async {
            final settings = await FirebaseMessaging.instance.requestPermission(
              alert: true,
              announcement: false,
              badge: true,
              carPlay: false,
              criticalAlert: false,
              provisional: false,
              sound: true,
            );

            if (settings.authorizationStatus ==
                AuthorizationStatus.authorized) {
              sl<AppLogger>().debug(
                'Web notification permission granted',
                tag: _tag,
              );
              final token = await FirebaseMessaging.instance.getToken();
              sl<AppLogger>().debug(
                'Web FCM Token obtained (${token != null ? '${token.length} chars' : 'null'})',
                tag: _tag,
              );
            } else {
              sl<AppLogger>().warning(
                'Web notification permission denied or provisional',
                tag: _tag,
              );
            }
          },
          onError: (error) => sl<AppLogger>().error(
            'Error requesting web notification permission: $error',
            tag: _tag,
          ),
        );
      }

      // Initialize local notifications
      await sl<NotificationService>().initialize();

      // Initialize Remote Config for dynamic configuration
      await sl<RemoteConfigService>().initialize();

      // Configure UI shape style (rounded vs pill)
      // Change to AppShapeStyle.pill for pill-shaped buttons and text fields
      AppShapeConfig.style = AppShapeStyle.pill;

      // Clear any pending badge on app startup
      await sl<NotificationService>().clearBadge();

      // Initialize Call Listener (checks notification permissions for iOS strategy)
      await CallListenerService().initialize();
    },
    onError: (error) => sl<AppLogger>().error(
      'Firebase initialization error: $error',
      tag: _tag,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// Track MyApp instances for debugging
int _myAppInstanceCounter = 0;

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final int _instanceId = ++_myAppInstanceCounter;

  @override
  void initState() {
    super.initState();
    sl<AppLogger>().debug(
      '[MyApp-$_instanceId] Created (total: $_myAppInstanceCounter)',
      tag: _tag,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    sl<AppLogger>().debug('🗑️ [MyApp-$_instanceId] Disposed', tag: _tag);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final presenceService = sl<UserPresenceService>();

    switch (state) {
      case AppLifecycleState.resumed:
        // Clear badge when user returns to the app
        sl<NotificationService>().clearBadge();
        sl<AppLogger>().debug(
          '[MyApp-$_instanceId] App resumed - badge cleared',
          tag: _tag,
        );
        // Update presence to online
        presenceService.setAppInForeground();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Update presence to offline/background
        presenceService.setAppInBackground();
        sl<AppLogger>().debug(
          '[MyApp-$_instanceId] App paused/inactive - presence set to background',
          tag: _tag,
        );
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is being terminated or hidden
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: createAppProviders(),
      child: MaterialApp(
        navigatorKey: PendingNotificationHandler.navigatorKey,
        navigatorObservers: [AnalyticsRouteObserver()],
        debugShowCheckedModeBanner: false,
        title: 'Security Experts',
        scaffoldMessengerKey: SnackbarService.messengerKey,
        theme: AppTheme.getLightTheme(),
        darkTheme: AppThemeDarkConfig.darkTheme,
        themeMode: ThemeMode.dark, // Always use dark theme
        home: const SplashPage(),
        onGenerateRoute: (settings) {
          // Handle named routes for notification navigation
          if (settings.name == AppRoutes.chat) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ChatConversationPage(
                partnerId: args?['partnerId'] ?? '',
                partnerName: args?['partnerName'] ?? 'User',
              ),
            );
          }
          // Admin dashboard route
          if (settings.name == AppRoutes.admin) {
            return MaterialPageRoute(
              builder: (_) => const AdminDashboardPage(),
            );
          }
          // Admin tickets routes
          if (settings.name == AppRoutes.adminTickets) {
            return MaterialPageRoute(
              builder: (_) => const AdminTicketsPage(),
            );
          }
          if (settings.name?.startsWith('${AppRoutes.adminTickets}/') == true) {
            final ticketId = settings.name!.split('/').last;
            return MaterialPageRoute(
              builder: (_) => AdminTicketDetailPage(ticketId: ticketId),
            );
          }
          // Admin FAQs routes
          if (settings.name == AppRoutes.adminFaqs) {
            return MaterialPageRoute(
              builder: (_) => const AdminFaqsPage(),
            );
          }
          if (settings.name?.startsWith('${AppRoutes.adminFaqs}/') == true) {
            final faqId = settings.name!.split('/').last;
            return MaterialPageRoute(
              builder: (_) => AdminFaqEditorPage(
                faqId: faqId == 'new' ? null : faqId,
              ),
            );
          }
          // Admin skills routes
          if (settings.name == AppRoutes.adminSkills) {
            return MaterialPageRoute(
              builder: (_) => const AdminSkillsPage(),
            );
          }
          if (settings.name?.startsWith('${AppRoutes.adminSkills}/') == true) {
            final skillId = settings.name!.split('/').last;
            return MaterialPageRoute(
              builder: (_) => AdminSkillEditorPage(
                skillId: skillId == 'new' ? null : skillId,
              ),
            );
          }
          // Admin users route
          if (settings.name == AppRoutes.adminUsers) {
            return MaterialPageRoute(
              builder: (_) => const AdminUsersPage(),
            );
          }
          return null;
        },
        builder: (context, child) {
          return CallOverlay(child: child ?? const SizedBox());
        },
      ),
    );
  }
}
