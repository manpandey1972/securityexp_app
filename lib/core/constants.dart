/// Central constants file for GreenHive app
/// This file consolidates all app-wide constants in one place
///
/// Organization:
/// 1. App Constants (timing, pagination, cache)
/// 2. Firestore Constants (collections, fields)
/// 3. UI Constants (dimensions, radii, padding)
/// 4. Chat Constants (chat-specific values)
/// 5. File Constants (extensions, sizes)
/// 6. App Strings (UI text, status messages)
/// 7. Regex Patterns (validation)
library;

// ============================================================================
// APP CONSTANTS - Timing, pagination, cache
// ============================================================================

class AppConstants {
  // ========== Timing & Delays ==========
  static const Duration firebaseInitDelay = Duration(milliseconds: 500);
  static const Duration callTimeout = Duration(milliseconds: 200);
  static const Duration recordingCheckInterval = Duration(milliseconds: 100);
  static const Duration messageRefreshInterval = Duration(seconds: 5);

  // ========== Pagination ==========
  static const int messageBatchSize = 50;
  static const int roomBatchSize = 20;
  static const int searchLimit = 10;

  // ========== Media & Cache ==========
  static const int maxCacheSizeBytes = 100 * 1024 * 1024; // 100MB
  static const int imageQuality = 80;
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB
  static const int mediaCacheLimit = 100;

  // ========== Validation ==========
  static const int minMessageLength = 1;
  static const int maxMessageLength = 500;
  static const int maxNameLength = 50;
}

// ============================================================================
// FIRESTORE CONSTANTS - Collections and field names
// ============================================================================

class FirestoreConstants {
  // ========== Collections ==========
  static const String roomsCollection = 'chat_rooms';
  static const String usersCollection = 'users';
  static const String messagesCollection = 'messages';
  static const String skillsCollection = 'skills';
  static const String productsCollection = 'products';

  // ========== Room Fields ==========
  static const String participantsField = 'participants';
  static const String lastMessageField = 'lastMessage';
  static const String lastMessageTimeField = 'lastMessageTime';
  static const String lastMessageDateTimeField = 'lastMessageDateTime';
  static const String roomNameField = 'roomName';
  static const String createdAtField = 'createdAt';

  // ========== Message Fields ==========
  static const String messageIdField = 'id';
  static const String senderIdField = 'sender_id';
  static const String textField = 'text';
  static const String timestampField = 'timestamp';
  static const String messageTypeField = 'type';
  static const String replyToField = 'replyTo';
  static const String mediaUrlField = 'mediaUrl';
  static const String mediaTypeField = 'mediaType';
  static const String editedAtField = 'editedAt';

  // ========== User Fields ==========
  static const String userIdField = 'userId';
  static const String userNameField = 'userName';
  static const String profilePictureField = 'profilePicture';
  static const String statusField = 'status';
  static const String emailField = 'email';
  static const String phoneField = 'phone';

  // ========== Call Fields ==========
  static const String callIdField = 'callId';
  static const String callerIdField = 'callerId';
  static const String calleeIdField = 'calleeId';
  static const String callTypeField = 'callType'; // audio, video
  static const String callStatusField =
      'callStatus'; // ringing, connected, ended
  static const String callDurationField = 'callDuration';
  static const String callStartTimeField = 'startTime';
  static const String callEndTimeField = 'endTime';
}

// ============================================================================
// UI CONSTANTS - Dimensions, paddings, radii
// ============================================================================

class UIConstants {
  // ========== Spacing ==========
  // Prefer AppSpacing for all new code. These are kept for backward
  // compatibility with existing usages.
  @Deprecated('Use AppSpacing.spacing8 instead')
  static const double smallPadding = 8.0;
  @Deprecated('Use AppSpacing.spacing16 instead')
  static const double mediumPadding = 16.0;
  @Deprecated('Use AppSpacing.spacing24 instead')
  static const double largePadding = 24.0;
  @Deprecated('Use AppSpacing.spacing32 instead')
  static const double extraLargePadding = 32.0;

  // ========== Border Radius ==========
  static const double smallRadius = 4.0;
  static const double mediumRadius = 8.0;
  static const double largeRadius = 12.0;
  static const double extraLargeRadius = 16.0;
  static const double circleRadius = 50.0;

  // ========== Chat UI Dimensions ==========
  static const double chatMessagePadding = 12.0;
  static const double chatMediaPadding = 4.0;
  static const double chatBorderRadius = 12.0;
  static const double profileAvatarRadius = 20.0;
  static const double profileAvatarPadding = 12.0;
  static const double messageCornerRadius = 12.0;
  static const double messagePadding = 12.0;
  static const double mediaMessagePadding = 4.0;

  // ========== Icon Sizes ==========
  static const double smallIconSize = 16.0;
  static const double mediumIconSize = 24.0;
  static const double largeIconSize = 32.0;
  static const double avatarIconSize = 48.0;
  static const double largeAvatarSize = 64.0;
  static const double profileAvatarSize = 18.0;

  // ========== Avatar Sizes ==========
  static const double circleAvatarRadius = 24.0;
  static const double smallAvatarRadius = 16.0;
  static const double largeAvatarRadius = 32.0;

  // ========== Input Field Height ==========
  static const double inputFieldHeight = 48.0;
  static const double textFieldHeight = 56.0;

  // ========== Button Dimensions ==========
  static const double buttonHeight = 48.0;
  static const double buttonWidth = 120.0;
  static const double fabSize = 56.0;

  // ========== Input Area ==========
  static const double inputPadding = 8.0;
  static const double iconButtonSize = 48.0;
}

// ============================================================================
// CHAT CONSTANTS - Chat-specific values
// ============================================================================

class ChatConstants {
  // ========== Animation Durations ==========
  static const Duration scrollAnimationDuration = Duration(milliseconds: 300);
  static const Duration scrollDelayBeforeAutoScroll = Duration(
    milliseconds: 200,
  );
  static const Duration scrollToNewMessageDelay = Duration(milliseconds: 800);
  static const Duration attachmentSheetDuration = Duration(milliseconds: 250);
  static const Duration recordingToastDuration = Duration(seconds: 1);
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 800);

  // ========== Scroll Detection ==========
  static const int scrollThresholdDistance = 5;
  static const int scrollDetectionThreshold = 5;

  // ========== Chat Message Styling ==========
  static const double chatMessagePadding = 12.0;
  static const double chatMediaPadding = 4.0;
  static const double chatBorderRadius = 12.0;

  // ========== Chat UI Dimensions ==========
  static const double profileAvatarRadius = 20;
  static const double profileAvatarPadding = 12;
  static const double messageCornerRadius = 12;
  static const double messagePadding = 12;
  static const double mediaMessagePadding = 4;
  static const double avatarIconSize = 48;
  static const double circleAvatarRadius = 24;

  // ========== Chat Header Constants ==========
  static const double chatHeaderAvatarRadius = 18.0;
  static const double chatHeaderAvatarPadding = 8.0;

  // ========== Chat Input Constants ==========
  static const double chatInputPadding = 8.0;
  static const double chatIconButtonSize = 48.0;

  // ========== Recording ==========
  static const int recordingCheckMs = 100;
}

// ============================================================================
// FILE CONSTANTS - File extensions and types
// ============================================================================

class FileConstants {
  // ========== Image Extensions ==========
  static const List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  ];

  // ========== Video Extensions ==========
  static const List<String> videoExtensions = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
  ];

  // ========== Audio Extensions ==========
  static const List<String> audioExtensions = [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'flac',
    'ogg',
  ];

  // ========== Document Extensions ==========
  static const List<String> documentExtensions = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'xlsx',
    'xls',
    'ppt',
    'pptx',
  ];

  // ========== HEIC/HEIF Extensions ==========
  static const List<String> heicExtensions = ['heic', 'heif'];

  // ========== File Size Limits ==========
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSizeBytes = 50 * 1024 * 1024; // 50MB
  static const int maxAudioSizeBytes = 25 * 1024 * 1024; // 25MB
  static const int maxDocumentSizeBytes = 10 * 1024 * 1024; // 10MB
}

// ============================================================================
// APP STRINGS - UI text, messages, status
// ============================================================================

class AppStrings {
  // ========== Status ==========
  static const String online = 'Online';
  static const String offline = 'Offline';
  static const String typing = 'Typing...';
  static const String away = 'Away';

  // ========== Errors ==========
  static const String networkError =
      'Network error. Please check your connection.';
  static const String loadingError = 'Failed to load data. Please try again.';
  static const String sendError = 'Failed to send message. Please try again.';
  static const String permissionError =
      'Permission denied. Please check app settings.';
  static const String validationError =
      'Invalid input. Please check and try again.';
  static const String timeoutError = 'Operation timed out. Please try again.';
  static const String unknownError = 'An unknown error occurred';
  static const String serverError = 'Server error. Please try again later.';

  // ========== Actions ==========
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String send = 'Send';
  static const String save = 'Save';
  static const String close = 'Close';
  static const String ok = 'OK';
  static const String done = 'Done';
  static const String next = 'Next';
  static const String submit = 'Submit';
  static const String select = 'Select';
  static const String clearAll = 'Clear All';

  // ========== Messages ==========
  static const String messageDeleted = 'Message deleted';
  static const String messageEdited = 'Edited';
  static const String noMessages = 'No messages yet. Start a conversation!';
  static const String copiedToClipboard = 'Copied to clipboard';
  static const String uploadingMessage = 'Uploading...';
  static const String deletingMessage = 'Deleting...';
  static const String typeMessage = 'Type a message...';
  static const String noChangesMade = 'No changes made';

  // ========== Chat Actions ==========
  static const String voiceCall = 'Voice Call';
  static const String videoCall = 'Video Call';
  static const String attachFile = 'Attach File';
  static const String viewInfo = 'View Info';
  static const String clearChat = 'Clear Chat';
  static const String blockUser = 'Block User';
  static const String chatCleared = 'Chat cleared';
  static const String chatDeleted = 'Chat deleted';
  static const String failedToClearChat = 'Failed to clear chat';
  static const String failedToDeleteChat = 'Failed to delete chat';

  // ========== Chat Errors ==========
  static const String imageFailedToLoad = 'Image failed to load';
  static const String cannotOpenUrl = 'Cannot open URL';
  static const String audioRecordingNotSupportedOnWeb =
      'Audio recording is not supported on web';
  static const String failedToStartRecording = 'Failed to start recording';

  // ========== Call Status ==========
  static const String incomingCall = 'Incoming call...';
  static const String callEnded = 'Call ended';
  static const String callMissed = 'Missed call';
  static const String callDeclined = 'Call declined';
  static const String callHistory = 'Call History';
  static const String failedToLoadCallHistory =
      'Failed to load call history';

  // ========== Home ==========
  static const String pleaseSignInToChat = 'Please sign in to start a chat';
  static const String expertProfile = 'Expert Profile';
  static const String searchByNameOrSkills = 'Search by name or skills...';
  static const String failedToLoadExperts =
      'Failed to load experts. Please try again.';
  static const String failedToLoadProducts =
      'Failed to load products. Please try again.';

  // ========== Auth ==========
  static const String pleaseLogIn = 'Please log in';
  static const String pleaseLogInToViewCallHistory =
      'Please log in to view call history';

  // ========== Phone Auth ==========
  static const String enterPhoneNumber = 'Enter your phone number';
  static const String enterOtp = 'Enter OTP';
  static const String phoneRequired = 'Phone number is required';
  static const String phoneInvalid = 'Invalid phone number format';
  static const String phoneTooShort = 'Phone number too short';
  static const String otpRequired = 'OTP is required';
  static const String otpInvalid = 'Invalid OTP';
  static const String countryRequired = 'Country selection required';
  static const String sendOtp = 'Send OTP';
  static const String verifyOtp = 'Verify OTP';
  static const String phoneVerification = 'Phone Verification';
  static const String resendOtp = 'Resend OTP';
  static const String resendIn = 'Resend in';
}

// ============================================================================
// REGEX PATTERNS - Input validation
// ============================================================================

class RegexPatterns {
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp phoneRegex = RegExp(
    r'^[+]?[(]?[0-9]{3}[)]?[-\s.]?[0-9]{3}[-\s.]?[0-9]{4,6}$',
  );

  static final RegExp roomIdRegex = RegExp(r'^[a-zA-Z0-9_-]{20,}$');

  static final RegExp messageCleanupRegex = RegExp(r'\s+');

  static final RegExp urlRegex = RegExp(
    r'https?://(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&/=]*)',
  );

  static final RegExp alphanumericRegex = RegExp(r'^[a-zA-Z0-9]+$');

  static final RegExp nameRegex = RegExp(r'^[a-zA-Z\s]+$');
}

// ============================================================================
// DURATION CONSTANTS - Animation and timing
// ============================================================================

class DurationConstants {
  // ========== General Animations ==========
  static const Duration veryShort = Duration(milliseconds: 100);
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration long = Duration(milliseconds: 800);
  static const Duration veryLong = Duration(milliseconds: 1200);

  // ========== Timeouts ==========
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration databaseTimeout = Duration(seconds: 15);
  static const Duration uiTimeout = Duration(seconds: 5);

  // ========== Delays ==========
  static const Duration debugDelay = Duration(milliseconds: 500);
  static const Duration snackBarDuration = Duration(seconds: 2);
  static const Duration dialogAnimationDuration = Duration(milliseconds: 300);
  static const Duration notificationDuration = Duration(seconds: 4);
}

// ============================================================================
// PLATFORM CONSTANTS - Device-specific values
// ============================================================================

class PlatformConstants {
  // ========== Safe Area ==========
  static const double safeAreaPaddingSmall = 8.0;
  static const double safeAreaPaddingMedium = 16.0;
  static const double safeAreaPaddingLarge = 24.0;

  // ========== Status Bar ==========
  static const double statusBarHeight = 24.0;

  // ========== Navigation Bar ==========
  static const double navigationBarHeight = 56.0;
  static const double bottomNavigationHeight = 80.0;
}

// ============================================================================
// API CONSTANTS - API-related values
// ============================================================================

class APIConstants {
  static const String baseUrl = 'https://api.greenhive.local';
  static const int connectTimeout = 30000; // milliseconds
  static const int receiveTimeout = 30000; // milliseconds
}

// ============================================================================
// DATABASE CONSTANTS - Database-specific values
// ============================================================================

class DatabaseConstants {
  static const int queryTimeout = 30000; // milliseconds
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}

// ============================================================================
// CACHE CONSTANTS - Caching strategies
// ============================================================================

class CacheConstants {
  static const Duration imageCacheDuration = Duration(days: 7);
  static const Duration videoCacheDuration = Duration(days: 3);
  static const Duration messageCacheDuration = Duration(hours: 24);
  static const Duration userCacheDuration = Duration(hours: 6);
  static const int maxCachedImages = 100;
  static const int maxCachedVideos = 50;
}
