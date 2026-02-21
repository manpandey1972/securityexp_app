import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/core/di/call_dependencies.dart' as call_di;
import 'package:securityexperts_app/core/di/crypto_dependencies.dart' as crypto_di;

// Core Services
import 'package:securityexperts_app/core/config/remote_config_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/auth/role_service.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';

// Data Services
import 'package:securityexperts_app/data/services/firestore_instance.dart';

// Shared Services
import 'package:securityexperts_app/shared/services/account_cleanup_service.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/shared/services/ringtone_service.dart';
import 'package:securityexperts_app/shared/services/profanity/profanity_filter_service.dart';

// Feature Services - Chat
import 'package:securityexperts_app/features/chat/services/unread_messages_service.dart';
import 'package:securityexperts_app/shared/services/media_upload_service.dart';
import 'package:securityexperts_app/shared/services/media_download_service.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/features/chat/services/audio_recording_manager.dart';
import 'package:securityexperts_app/features/chat/services/reply_management_service.dart';
import 'package:securityexperts_app/features/chat/services/chat_page_service.dart';
import 'package:securityexperts_app/shared/services/upload_manager.dart';
import 'package:securityexperts_app/features/chat/services/user_presence_service.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/features/chat/services/encryption_service.dart';

// Feature Services - Authentication & Profile
import 'package:securityexperts_app/features/profile/services/biometric_auth_service.dart';
import 'package:securityexperts_app/features/profile/services/profile_picture_service.dart';
import 'package:securityexperts_app/features/profile/services/skills_service.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/data/repositories/expert/expert_repository.dart';
import 'package:securityexperts_app/data/repositories/product/product_repository.dart';

// Feature Services - Notifications
import 'package:securityexperts_app/shared/services/notification_service.dart';
import 'package:securityexperts_app/shared/services/firebase_messaging_service.dart';

// Utility Services
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/event_bus.dart';
import 'package:securityexperts_app/shared/services/dialog_service.dart';

// Validators
import 'package:securityexperts_app/core/validators/phone_validator.dart';

// Home Feature Services
import 'package:securityexperts_app/features/home/services/home_data_loader.dart';
import 'package:securityexperts_app/features/home/presentation/view_models/home_view_model.dart';

// Chat Feature Services
import 'package:securityexperts_app/features/chat/presentation/view_models/chat_conversation_view_model.dart';
import 'package:securityexperts_app/features/chat_list/presentation/view_models/chat_list_view_model.dart';

// Phone Auth Feature Services
import 'package:securityexperts_app/features/phone_auth/presentation/view_models/phone_auth_view_model.dart';
import 'package:securityexperts_app/features/phone_auth/services/google_auth_service.dart';
import 'package:securityexperts_app/features/phone_auth/services/apple_auth_service.dart';

// Onboarding Feature Services
import 'package:securityexperts_app/features/onboarding/presentation/view_models/onboarding_view_model.dart';

// Profile Feature Services
import 'package:securityexperts_app/features/profile/presentation/view_models/user_profile_view_model.dart';

// Support Feature Services
import 'package:securityexperts_app/features/support/data/repositories/support_repository.dart';
import 'package:securityexperts_app/features/support/data/repositories/support_attachment_repository.dart';
import 'package:securityexperts_app/features/support/services/device_info_service.dart';
import 'package:securityexperts_app/features/support/services/support_service.dart';
import 'package:securityexperts_app/features/support/services/support_analytics.dart';
import 'package:securityexperts_app/features/support/services/faq_service.dart';

// Admin Feature Services
import 'package:securityexperts_app/features/admin/services/admin_ticket_service.dart';
import 'package:securityexperts_app/features/admin/services/admin_faq_service.dart';
import 'package:securityexperts_app/features/admin/services/admin_skills_service.dart';
import 'package:securityexperts_app/features/admin/services/admin_user_service.dart';

// Rating Feature Services
import 'package:securityexperts_app/features/ratings/data/repositories/rating_repository.dart';
import 'package:securityexperts_app/features/ratings/services/rating_service.dart';


/// Global service locator instance
///
/// This is the central dependency injection container for the entire app.
/// Use this to register and retrieve singleton services.
///
/// Example:
/// ```dart
/// // Get a service
/// final chatService = sl<ChatService>();
///
/// // In tests, you can reset and register mocks
/// sl.reset();
/// sl.registerSingleton<ChatService>(MockChatService());
/// ```
final sl = GetIt.instance;

/// Initialize all application services
///
/// This should be called once during app initialization in main.dart.
/// It sets up all dependency injection registrations.
///
/// Call order:
/// 1. Core services (config, error handling)
/// 2. Data layer (Firestore, repositories)
/// 3. Shared services (user profile, cache)
/// 4. Feature services (chat, calling, etc.)
///
/// Example:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp();
///   await setupServiceLocator(); // Initialize all services
///   runApp(MyApp());
/// }
/// ```

// Guard to prevent multiple initializations
bool _serviceLocatorInitialized = false;

Future<void> setupServiceLocator() async {
  // Prevent duplicate initialization
  if (_serviceLocatorInitialized) {
    return;
  }
  _serviceLocatorInitialized = true;

  final logger = kDebugMode ? DebugAppLogger() : ProductionAppLogger();
  logger.debug('🔧 [ServiceLocator] Initializing dependency injection...');

  // ========================================
  // CORE SERVICES - Foundation layer
  // ========================================

  // App Logger - Must be first as all services use it
  sl.registerLazySingleton<AppLogger>(
    () => kDebugMode ? DebugAppLogger() : ProductionAppLogger(),
  );

  // Remote Config - Must be early as other services depend on it
  sl.registerLazySingleton<RemoteConfigService>(() => RemoteConfigService());

  // Error Handler - Used throughout the app
  sl.registerLazySingleton<ErrorHandler>(() => ErrorHandler());

  // Event Bus - For app-wide event communication
  sl.registerLazySingleton<EventBus>(() => EventBus());

  // Phone Validator - For phone number validation
  sl.registerLazySingleton<PhoneValidator>(() => PhoneValidator());

  // Analytics Service - For tracking user behavior and performance
  sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService());

  // Initialize analytics early (non-blocking)
  sl<AnalyticsService>().initialize().catchError((e) {
    sl<AppLogger>().warning('Analytics initialization failed: $e');
  });

  sl<AppLogger>().debug('✅ [ServiceLocator] Core services registered');

  // ========================================
  // DATA LAYER - Database and repositories
  // ========================================

  // Firebase Auth - Authentication service
  // Register instance for dependency injection and easier testing
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);

  // Firebase Firestore - Database service
  // Register instance for dependency injection and easier testing
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);

  // Firestore Instance - Singleton database connection (legacy wrapper)
  sl.registerLazySingleton<FirestoreInstance>(() => FirestoreInstance());

  // Role Service - For admin role and permission management
  // MUST be registered after FirestoreInstance to use correct database
  sl.registerLazySingleton<RoleService>(
    () => RoleService(firestore: sl<FirestoreInstance>().db),
  );

  sl<AppLogger>().debug('✅ [ServiceLocator] Data layer registered');

  // ========================================
  // E2EE CRYPTO SERVICES
  // ========================================

  // Register all E2EE encryption services (Signal Protocol, key storage, etc.)
  crypto_di.registerCryptoServices(sl);

  sl<AppLogger>().debug('✅ [ServiceLocator] Crypto services registered');

  // ========================================
  // SHARED SERVICES - Used across features
  // ========================================

  // User Profile Service - Global user state (singleton instance already exists)
  sl.registerSingleton<UserProfileService>(UserProfileService());

  // User Cache Service
  sl.registerLazySingleton<UserCacheService>(() => UserCacheService());

  // Snackbar Service - For showing app-wide messages
  // Note: This is a static service, no registration needed

  // Ringtone Service - For playing call/message sounds
  sl.registerLazySingleton<RingtoneService>(() => RingtoneService());

  // User Presence Service - Tracks user online/offline status and current chat room
  // Used by Cloud Functions to suppress push notifications when user is active
  sl.registerLazySingleton<UserPresenceService>(() => UserPresenceService());

  // Profanity Filter Service - Filters inappropriate content in user inputs
  sl.registerLazySingleton<ProfanityFilterService>(
    () => ProfanityFilterService(),
  );

  // Account Cleanup Service - Centralized teardown for sign-out / account deletion
  sl.registerLazySingleton<AccountCleanupService>(
    () => AccountCleanupService(sl<AppLogger>()),
  );

  sl<AppLogger>().debug('✅ [ServiceLocator] Shared services registered');

  // ========================================
  // FEATURE SERVICES - CHAT
  // ========================================

  // Media Services for chat (register early since repositories depend on them)
  sl.registerLazySingleton<MediaUploadService>(() => MediaUploadService());
  sl.registerLazySingleton<MediaDownloadService>(() => MediaDownloadService());
  sl.registerLazySingleton<MediaCacheService>(() => MediaCacheService());

  // Upload Manager - Global upload manager for background uploads
  // Registered as singleton (not lazy) so it's always available
  sl.registerLazySingleton<UploadManager>(() => UploadManager());

  // Chat Repositories - Architecture for chat operations
  sl.registerLazySingleton<ChatRoomRepository>(
    () => ChatRoomRepository(mediaCacheService: sl<MediaCacheService>()),
  );
  sl.registerLazySingleton<ChatMessageRepository>(
    () => ChatMessageRepository(
      roomRepository: sl<ChatRoomRepository>(),
      encryptionService: sl<EncryptionService>(),
    ),
  );

  // Chat Stream Service - Factory, requires roomId per instance
  // Note: ChatStreamService requires roomId, so it should be created per chat room
  // Use: ChatStreamService(roomId: 'roomId', messageRepository: sl<ChatMessageRepository>())

  // Unread Messages Service - Tracks unread message counts
  sl.registerLazySingleton<UnreadMessagesService>(
    () => UnreadMessagesService(),
  );

  // Audio Recording Manager - For voice messages
  sl.registerFactory<AudioRecordingManager>(() => AudioRecordingManager());

  // Reply Management Service - For message replies
  sl.registerLazySingleton<ReplyManagementService>(
    () => ReplyManagementService(),
  );

  // Chat Page Service - Handles chat page operations (delete, edit, etc.)
  sl.registerLazySingleton<ChatPageService>(
    () => ChatPageService(
      messageRepository: sl<ChatMessageRepository>(),
      mediaDownloadService: sl<MediaDownloadService>(),
    ),
  );

  // ========================================
  // FEATURE SERVICES - CALLING
  // ========================================

  // Call-related services are registered via call_dependencies.dart
  call_di.setupCallDependencies();

  // ========================================
  // FEATURE SERVICES - AUTHENTICATION & PROFILE
  // ========================================

  // Biometric Authentication Service
  sl.registerLazySingleton<BiometricAuthService>(() => BiometricAuthService());

  // Profile Picture Service
  sl.registerLazySingleton<ProfilePictureService>(
    () => ProfilePictureService(),
  );

  // Skills Service - Manages user skills
  sl.registerLazySingleton<SkillsService>(() => SkillsService());

  // User Repository - Firestore CRUD for user profiles
  sl.registerLazySingleton<UserRepository>(() => UserRepository());

  // Expert Repository - Firestore CRUD for experts
  sl.registerLazySingleton<ExpertRepository>(() => ExpertRepository());

  // Product Repository - Firestore CRUD for products
  sl.registerLazySingleton<ProductRepository>(() => ProductRepository());

  // ========================================
  // FEATURE SERVICES - NOTIFICATIONS
  // ========================================

  // Notification Service - Local notifications
  sl.registerLazySingleton<NotificationService>(() => NotificationService());

  // Firebase Messaging Service - Push notifications
  sl.registerLazySingleton<FirebaseMessagingService>(
    () => FirebaseMessagingService(),
  );

  sl<AppLogger>().debug('✅ [ServiceLocator] Notification services registered');

  // ========================================
  // UTILITY SERVICES
  // ========================================

  // Dialog Service - For showing dialogs consistently
  sl.registerLazySingleton<DialogService>(() => DialogService());

  sl<AppLogger>().debug('✅ [ServiceLocator] Utility services registered');

  // ========================================
  // HOME FEATURE SERVICES
  // ========================================

  // Home Data Loader - Manages data loading for home page
  sl.registerLazySingleton<HomeDataLoader>(() => HomeDataLoader());

  // Home ViewModel - Factory pattern (new instance per use)
  sl.registerFactory<HomeViewModel>(
    () => HomeViewModel(dataLoader: sl<HomeDataLoader>()),
  );

  sl<AppLogger>().debug('✅ [ServiceLocator] Home feature services registered');

  // ========================================
  // CHAT FEATURE SERVICES
  // ========================================

  // Chat Conversation ViewModel - Factory pattern (new instance per chat)
  sl.registerFactory<ChatConversationViewModel>(
    () => ChatConversationViewModel(
      roomRepository: sl<ChatRoomRepository>(),
      messageRepository: sl<ChatMessageRepository>(),
      unreadMessagesService: sl<UnreadMessagesService>(),
      mediaDownloadService: sl<MediaDownloadService>(),
      mediaCacheService: sl<MediaCacheService>(),
      chatPageService: sl<ChatPageService>(),
    ),
  );

  // Chat List ViewModel - Factory pattern (new instance per chat list)
  sl.registerFactory<ChatListViewModel>(
    () => ChatListViewModel(
      roomRepository: sl<ChatRoomRepository>(),
      unreadMessagesService: sl<UnreadMessagesService>(),
    ),
  );

  sl<AppLogger>().debug(
    '✅ [ServiceLocator] Auth & Profile services registered',
  );

  // ========================================
  // PHONE AUTH FEATURE SERVICES
  // ========================================

  // Google Auth Service - Singleton (shared across the app)
  sl.registerLazySingleton<GoogleAuthService>(() => GoogleAuthService());

  // Apple Auth Service - Singleton (shared across the app)
  sl.registerLazySingleton<AppleAuthService>(() => AppleAuthService());

  // Phone Auth ViewModel - Factory pattern (new instance per navigation)
  sl.registerFactory<PhoneAuthViewModel>(
    () => PhoneAuthViewModel(
      auth: FirebaseAuth.instance,
      userRepository: sl<UserRepository>(),
    ),
  );

  sl<AppLogger>().debug(
    '✅ [ServiceLocator] Phone auth feature services registered',
  );

  // ========================================
  // ONBOARDING FEATURE SERVICES
  // ========================================

  // Onboarding ViewModel - Factory pattern (new instance per navigation)
  sl.registerFactory<OnboardingViewModel>(
    () => OnboardingViewModel(skillsService: sl<SkillsService>()),
  );

  // ========================================
  // PROFILE FEATURE SERVICES
  // ========================================

  // User Profile ViewModel - Factory pattern (new instance per navigation)
  sl.registerFactory<UserProfileViewModel>(
    () => UserProfileViewModel(
      userRepository: sl<UserRepository>(),
      skillsService: sl<SkillsService>(),
      biometricService: sl<BiometricAuthService>(),
      profilePictureService: sl<ProfilePictureService>(),
      auth: sl<FirebaseAuth>(),
    ),
  );

  // ========================================
  // SUPPORT FEATURE SERVICES
  // ========================================

  // Support Repository - Firestore CRUD for support tickets
  sl.registerLazySingleton<SupportRepository>(() => SupportRepository());

  // Support Attachment Repository - Firebase Storage for ticket attachments
  sl.registerLazySingleton<SupportAttachmentRepository>(
    () => SupportAttachmentRepository(),
  );

  // Device Info Service - Captures device context for tickets
  sl.registerLazySingleton<DeviceInfoService>(() => DeviceInfoService());

  // Support Service - High-level API for support operations
  sl.registerLazySingleton<SupportService>(
    () => SupportService(
      repository: sl<SupportRepository>(),
      attachmentRepository: sl<SupportAttachmentRepository>(),
      deviceInfoService: sl<DeviceInfoService>(),
      notificationService: sl<NotificationService>(),
      log: sl<AppLogger>(),
    ),
  );

  // Support Analytics - Tracks support feature usage
  sl.registerLazySingleton<SupportAnalytics>(() => SupportAnalytics());

  // FAQ Service - Public FAQ service for users (no permission checks)
  sl.registerLazySingleton<FaqService>(() => FaqService());

  sl<AppLogger>().debug(
    '✅ [ServiceLocator] Support feature services registered',
  );

  // ========================================
  // ADMIN FEATURE SERVICES
  // ========================================

  // Admin Ticket Service - Admin operations for ticket management
  sl.registerLazySingleton<AdminTicketService>(() => AdminTicketService());

  // Admin FAQ Service - Admin operations for FAQ management
  sl.registerLazySingleton<AdminFaqService>(() => AdminFaqService());

  // Admin Skills Service - Admin operations for skills management
  sl.registerLazySingleton<AdminSkillsService>(() => AdminSkillsService());

  // Admin User Service - Admin operations for user management
  sl.registerLazySingleton<AdminUserService>(() => AdminUserService());

  sl<AppLogger>().debug('✅ [ServiceLocator] Admin feature services registered');

  // ========================================
  // RATING FEATURE SERVICES
  // ========================================

  // Rating Repository - Firestore CRUD for expert ratings
  sl.registerLazySingleton<RatingRepository>(() => RatingRepository());

  // Rating Service - High-level API for rating operations
  sl.registerLazySingleton<RatingService>(
    () => RatingService(
      repository: sl<RatingRepository>(),
      log: sl<AppLogger>(),
    ),
  );

  sl<AppLogger>().debug('✅ [ServiceLocator] Rating feature services registered');

}

/// Reset the service locator
///
/// This is useful for testing to clear all registrations
/// and register mock implementations.
///
/// Example:
/// ```dart
/// setUp(() {
///   resetServiceLocator();
///   sl.registerSingleton<ChatService>(MockChatService());
/// });
/// ```
void resetServiceLocator() {
  sl.reset();
  _serviceLocatorInitialized = false; // Reset the guard flag for tests
}

/// Check if a service is registered
///
/// Example:
/// ```dart
/// if (isServiceRegistered<ChatService>()) {
///   final chat = sl<ChatService>();
/// }
/// ```
bool isServiceRegistered<T extends Object>() {
  return sl.isRegistered<T>();
}
