import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/signaling_service.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/media_manager_factory.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/room_service.dart';
import 'package:securityexperts_app/features/calling/domain/repositories/call_repository.dart';
import 'package:securityexperts_app/features/calling/domain/repositories/call_history_repository.dart';
import 'package:securityexperts_app/features/calling/infrastructure/repositories/firebase_call_repository.dart';
import 'package:securityexperts_app/features/calling/infrastructure/repositories/firebase_call_history_repository.dart';
import 'package:securityexperts_app/features/calling/services/livekit_service.dart';
import 'package:securityexperts_app/features/calling/services/audio_device_service.dart';
import 'package:securityexperts_app/features/calling/services/call_logger.dart';
import 'package:securityexperts_app/features/calling/services/incoming_call_manager.dart';
import '../config/call_config.dart';
import '../errors/call_error_handler.dart';
import 'package:securityexperts_app/features/calling/services/analytics/call_analytics.dart';
import 'package:securityexperts_app/features/calling/services/resilience/retry_manager.dart';
import 'package:securityexperts_app/features/calling/services/resilience/circuit_breaker.dart';
import 'package:securityexperts_app/features/calling/services/monitoring/network_quality_monitor.dart';
import 'package:securityexperts_app/features/calling/services/signaling/unified_signaling_service.dart';
import 'package:securityexperts_app/features/calling/infrastructure/repositories/voip_token_repository.dart';
import 'package:securityexperts_app/core/config/remote_config_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

// Re-export sl for files that import call_dependencies
export 'package:securityexperts_app/core/service_locator.dart' show sl;

/// Parameters for creating a CallController
class CallParams {
  final bool isCaller;
  final bool isVideo;
  final String? calleeId;
  final String? callId;

  CallParams({
    required this.isCaller,
    required this.isVideo,
    this.calleeId,
    this.callId,
  });
}

/// Sets up all call-related dependencies in the DI container
///
/// This should be called once during app initialization,
/// before any call functionality is used.
///
/// Example:
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp();
///   setupCallDependencies(); // Setup DI
///   runApp(MyApp());
/// }
/// ```
void setupCallDependencies() {
  // Logger - different implementation for debug vs release
  sl.registerLazySingleton<CallLogger>(
    () => kDebugMode ? DebugCallLogger() : ProductionCallLogger(),
  );

  // Configuration - load from Remote Config (centralized provider selection)
  sl.registerLazySingleton<CallConfig>(() {
    try {
      return CallConfig(remoteConfig: RemoteConfigService());
    } catch (e) {
      // Fallback to default config if Remote Config fails
      sl<CallLogger>().warning(
        'Failed to load CallConfig from Remote Config, using defaults',
        {'error': e.toString()},
      );
      return CallConfig();
    }
  });

  // Error Handler
  sl.registerLazySingleton<CallErrorHandler>(
    () => CallErrorHandler(sl<CallLogger>()),
  );

  // Analytics - different implementation for debug vs release
  sl.registerLazySingleton<CallAnalytics>(
    () => kDebugMode ? DebugCallAnalytics() : ProductionCallAnalytics(),
  );

  // Retry Manager - for handling retryable operations
  sl.registerLazySingleton<RetryManager>(
    () => RetryManager(
      logger: sl<CallLogger>(),
      config: RetryConfig(
        maxAttempts: sl<CallConfig>().maxRetryAttempts,
        initialDelay: sl<CallConfig>().retryInitialDelay,
        backoffMultiplier: sl<CallConfig>().retryBackoffMultiplier,
      ),
    ),
  );

  // Circuit Breaker Manager - for resilience
  sl.registerLazySingleton<CircuitBreakerManager>(
    () => CircuitBreakerManager(),
  );

  // Network Quality Monitor - factory for per-call monitoring
  sl.registerFactory<NetworkQualityMonitor>(() => NetworkQualityMonitor());

  // Call Repository - data access layer for call operations
  // Abstracts Firebase implementation details
  sl.registerLazySingleton<CallRepository>(
    () => FirebaseCallRepository(
      functions: FirebaseFunctions.instance,
      firestore: FirestoreInstance().db,
      auth: FirebaseAuth.instance,
      userCache: sl<UserCacheService>(),
      callConfig: sl<CallConfig>(),
    ),
  );

  // Incoming Call Manager - manages incoming call state and UI
  sl.registerLazySingleton<IncomingCallManager>(() => IncomingCallManager());

  // Call History Repository - manages call history CRUD operations
  sl.registerLazySingleton<CallHistoryRepository>(
    () => FirebaseCallHistoryRepository(firestore: FirestoreInstance().db),
  );

  // Signaling Service - now delegates to repository
  sl.registerLazySingleton<SignalingService>(
    () => UnifiedSignalingService(repository: sl<CallRepository>()),
  );

  // Room Service - factory for managing LiveKit room connections
  // IMPORTANT: Must be factory (not singleton) because LiveKitService.dispose()
  // closes stream controllers, making them unusable for subsequent calls.
  // Cross-call coordination (waiting for the previous call's cleanup before
  // connecting a new one) is handled via STATIC fields in LiveKitService:
  //   _isCleaningUp, _cleanupCompleter, _lastCallEndTime.
  sl.registerFactory<RoomService>(() => LiveKitService());

  // Audio Device Service - singleton for audio routing
  //
  // NOTE: AudioDeviceService.initialize() is intentionally NOT called here.
  // Initialization should happen when actually entering call flow to:
  // 1. Defer audio session configuration until needed
  // 2. Avoid conflicts with other audio apps on app launch
  // 3. Allow iOS to manage default audio routing
  //
  // The service's initialize() method sets up platform listeners and should be
  // called once when entering the call feature (e.g., CallController setup).
  sl.registerLazySingleton<AudioDeviceService>(() => AudioDeviceService());

  // VoIP Token Repository - manages iOS VoIP push tokens
  // Syncs token to Firestore for backend to send push notifications
  sl.registerLazySingleton<VoIPTokenRepository>(() => VoIPTokenRepository());

  // Media Manager Factory - factory pattern for creating media managers
  sl.registerFactory<MediaManagerFactory>(() => DefaultMediaManagerFactory());
}

/// Initializes call-related services that need async setup
///
/// Call this when entering the call feature for the first time in a session.
/// This sets up:
/// - AudioDeviceService platform listeners
/// - Android VoIP audio configuration
///
/// Example:
/// ```dart
/// // In CallController or when entering call flow
/// await initializeCallServices();
/// ```
Future<void> initializeCallServices() async {
  final audioService = sl<AudioDeviceService>();
  await audioService.initialize();

  // Configure Android for VoIP (sets MODE_IN_COMMUNICATION and requests audio focus)
  await audioService.configureForVoIPCall();
}

/// Releases call-related audio resources
///
/// Call this when completely exiting call flow.
/// This releases:
/// - Android audio focus
/// - Android Bluetooth SCO
/// - Android audio mode reset
///
/// Example:
/// ```dart
/// // When call ends and user exits call UI
/// await releaseCallServices();
/// ```
Future<void> releaseCallServices() async {
  final audioService = sl<AudioDeviceService>();
  await audioService.releaseVoIPCall();
}

/// Resets all call dependencies
///
/// Useful for testing or when needing to reinitialize the system.
/// WARNING: Only use this in tests or during app lifecycle events.
void resetCallDependencies() {
  sl.reset();
}

/// Checks if call dependencies are setup
bool areCallDependenciesSetup() {
  return sl.isRegistered<CallLogger>() &&
      sl.isRegistered<CallConfig>() &&
      sl.isRegistered<CallAnalytics>() &&
      sl.isRegistered<RetryManager>() &&
      sl.isRegistered<SignalingService>() &&
      sl.isRegistered<MediaManagerFactory>();
}
