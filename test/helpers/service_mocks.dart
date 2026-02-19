// Centralized mock generation for all application services
//
// This file uses @GenerateMocks to create mock implementations
// of all major services used throughout the application.
//
// Usage:
// 1. Import this file in your test
// 2. Run `flutter pub run build_runner build` to generate mocks
// 3. Use MockXXX classes in your tests
//
// Example:
// ```dart
// import 'package:securityexperts_app/test/helpers/service_mocks.dart';
//
// late MockUserRepository mockUserRepo;
//
// setUp(() {
//   mockUserRepo = MockUserRepository();
// });
// ```

import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Core Services
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/auth/role_service.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';
import 'package:securityexperts_app/core/config/remote_config_service.dart';

// Data Services & Repositories
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/data/repositories/expert/expert_repository.dart';
import 'package:securityexperts_app/data/repositories/product/product_repository.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_room_repository.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_message_repository.dart';

// Shared Services
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/notification_service.dart';
import 'package:securityexperts_app/shared/services/firebase_messaging_service.dart';
import 'package:securityexperts_app/shared/services/media_upload_service.dart';
import 'package:securityexperts_app/shared/services/media_download_service.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/shared/services/ringtone_service.dart';
import 'package:securityexperts_app/shared/services/dialog_service.dart';
import 'package:securityexperts_app/shared/services/event_bus.dart';
import 'package:securityexperts_app/shared/services/upload_manager.dart';
import 'package:securityexperts_app/shared/services/profanity/profanity_filter_service.dart';

// Feature Services - Chat
import 'package:securityexperts_app/features/chat/services/unread_messages_service.dart';
import 'package:securityexperts_app/features/chat/services/audio_recording_manager.dart';
import 'package:securityexperts_app/features/chat/services/reply_management_service.dart';
import 'package:securityexperts_app/features/chat/services/chat_page_service.dart';
import 'package:securityexperts_app/features/chat/services/user_presence_service.dart';

// Feature Services - Profile
import 'package:securityexperts_app/features/profile/services/biometric_auth_service.dart';
import 'package:securityexperts_app/features/profile/services/profile_picture_service.dart';
import 'package:securityexperts_app/features/profile/services/skills_service.dart';

// Feature Services - Support
import 'package:securityexperts_app/features/support/data/repositories/support_repository.dart';
import 'package:securityexperts_app/features/support/data/repositories/support_attachment_repository.dart';
import 'package:securityexperts_app/features/support/services/device_info_service.dart';
import 'package:securityexperts_app/features/support/services/support_service.dart';
import 'package:securityexperts_app/features/support/services/faq_service.dart';

// Feature Services - Ratings
import 'package:securityexperts_app/features/ratings/data/repositories/rating_repository.dart';
import 'package:securityexperts_app/features/ratings/services/rating_service.dart';

// Feature Services - Admin
import 'package:securityexperts_app/features/admin/services/admin_ticket_service.dart';
import 'package:securityexperts_app/features/admin/services/admin_user_service.dart';
import 'package:securityexperts_app/features/admin/services/admin_skills_service.dart';
import 'package:securityexperts_app/features/admin/services/admin_faq_service.dart';

// Validators
import 'package:securityexperts_app/core/validators/phone_validator.dart';

@GenerateMocks([
  // Firebase Services
  FirebaseFirestore,
  FirebaseAuth,
  FirebaseStorage,
  FirebaseFunctions,
  
  // Core Services
  AppLogger,
  RoleService,
  AnalyticsService,
  RemoteConfigService,
  FirestoreInstance,
  
  // Repositories
  UserRepository,
  ExpertRepository,
  ProductRepository,
  ChatRoomRepository,
  ChatMessageRepository,
  SupportRepository,
  SupportAttachmentRepository,
  RatingRepository,
  
  // Shared Services
  UserProfileService,
  UserCacheService,
  ErrorHandler,
  NotificationService,
  FirebaseMessagingService,
  MediaUploadService,
  MediaDownloadService,
  MediaCacheService,
  RingtoneService,
  DialogService,
  EventBus,
  UploadManager,
  ProfanityFilterService,
  
  // Chat Feature Services
  UnreadMessagesService,
  AudioRecordingManager,
  ReplyManagementService,
  ChatPageService,
  UserPresenceService,
  
  // Profile Feature Services
  BiometricAuthService,
  ProfilePictureService,
  SkillsService,
  
  // Support Feature Services
  DeviceInfoService,
  SupportService,
  FaqService,
  
  // Rating Feature Services
  RatingService,
  
  // Admin Feature Services
  AdminTicketService,
  AdminUserService,
  AdminSkillsService,
  AdminFaqService,
  
  // Validators
  PhoneValidator,
])
void main() {}
