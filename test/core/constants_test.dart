import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/core/constants.dart';
import 'package:greenhive_app/shared/themes/app_spacing.dart';

void main() {
  group('AppConstants', () {
    group('Timing & Delays', () {
      test('should have correct Firebase init delay', () {
        expect(AppConstants.firebaseInitDelay.inMilliseconds, 500);
      });

      test('should have correct call timeout', () {
        expect(AppConstants.callTimeout.inMilliseconds, 200);
      });

      test('should have correct recording check interval', () {
        expect(AppConstants.recordingCheckInterval.inMilliseconds, 100);
      });

      test('should have correct message refresh interval', () {
        expect(AppConstants.messageRefreshInterval.inSeconds, 5);
      });
    });

    group('Pagination', () {
      test('should have correct message batch size', () {
        expect(AppConstants.messageBatchSize, 50);
      });

      test('should have correct room batch size', () {
        expect(AppConstants.roomBatchSize, 20);
      });

      test('should have correct search limit', () {
        expect(AppConstants.searchLimit, 10);
      });
    });

    group('Media & Cache', () {
      test('should have correct max cache size (100MB)', () {
        expect(AppConstants.maxCacheSizeBytes, 100 * 1024 * 1024);
      });

      test('should have correct image quality', () {
        expect(AppConstants.imageQuality, 80);
      });

      test('should have correct max image size (5MB)', () {
        expect(AppConstants.maxImageSize, 5 * 1024 * 1024);
      });

      test('should have correct max video size (50MB)', () {
        expect(AppConstants.maxVideoSize, 50 * 1024 * 1024);
      });

      test('should have correct media cache limit', () {
        expect(AppConstants.mediaCacheLimit, 100);
      });
    });

    group('Validation', () {
      test('should have correct message length limits', () {
        expect(AppConstants.minMessageLength, 1);
        expect(AppConstants.maxMessageLength, 500);
      });

      test('should have correct name length limit', () {
        expect(AppConstants.maxNameLength, 50);
      });
    });
  });

  group('FirestoreConstants', () {
    group('Collections', () {
      test('should have correct collection names', () {
        expect(FirestoreConstants.roomsCollection, 'chat_rooms');
        expect(FirestoreConstants.usersCollection, 'users');
        expect(FirestoreConstants.messagesCollection, 'messages');
        expect(FirestoreConstants.skillsCollection, 'skills');
        expect(FirestoreConstants.productsCollection, 'products');
      });
    });

    group('Room Fields', () {
      test('should have correct room field names', () {
        expect(FirestoreConstants.participantsField, 'participants');
        expect(FirestoreConstants.lastMessageField, 'lastMessage');
        expect(FirestoreConstants.lastMessageTimeField, 'lastMessageTime');
        expect(FirestoreConstants.createdAtField, 'createdAt');
      });
    });

    group('Message Fields', () {
      test('should have correct message field names', () {
        expect(FirestoreConstants.messageIdField, 'id');
        expect(FirestoreConstants.senderIdField, 'sender_id');
        expect(FirestoreConstants.textField, 'text');
        expect(FirestoreConstants.timestampField, 'timestamp');
        expect(FirestoreConstants.messageTypeField, 'type');
        expect(FirestoreConstants.mediaUrlField, 'mediaUrl');
      });
    });

    group('User Fields', () {
      test('should have correct user field names', () {
        expect(FirestoreConstants.userIdField, 'userId');
        expect(FirestoreConstants.userNameField, 'userName');
        expect(FirestoreConstants.emailField, 'email');
        expect(FirestoreConstants.phoneField, 'phone');
        expect(FirestoreConstants.statusField, 'status');
      });
    });

    group('Call Fields', () {
      test('should have correct call field names', () {
        expect(FirestoreConstants.callIdField, 'callId');
        expect(FirestoreConstants.callerIdField, 'callerId');
        expect(FirestoreConstants.calleeIdField, 'calleeId');
        expect(FirestoreConstants.callTypeField, 'callType');
        expect(FirestoreConstants.callStatusField, 'callStatus');
      });
    });
  });

  group('UIConstants', () {
    group('Spacing', () {
      test('should have correct padding values', () {
        expect(AppSpacing.spacing8, 8.0);
        expect(AppSpacing.spacing16, 16.0);
        expect(AppSpacing.spacing24, 24.0);
        expect(AppSpacing.spacing32, 32.0);
      });
    });

    group('Border Radius', () {
      test('should have correct radius values', () {
        expect(UIConstants.smallRadius, 4.0);
        expect(UIConstants.mediumRadius, 8.0);
        expect(UIConstants.largeRadius, 12.0);
        expect(UIConstants.extraLargeRadius, 16.0);
        expect(UIConstants.circleRadius, 50.0);
      });
    });

    group('Chat UI Dimensions', () {
      test('should have correct chat dimensions', () {
        expect(UIConstants.chatMessagePadding, 12.0);
        expect(UIConstants.chatBorderRadius, 12.0);
        expect(UIConstants.profileAvatarRadius, 20.0);
        expect(UIConstants.messageCornerRadius, 12.0);
      });
    });

    group('Icon Sizes', () {
      test('should have correct icon size values', () {
        expect(UIConstants.smallIconSize, 16.0);
        expect(UIConstants.mediumIconSize, 24.0);
        expect(UIConstants.largeIconSize, 32.0);
        expect(UIConstants.avatarIconSize, 48.0);
      });
    });

    group('Button Dimensions', () {
      test('should have correct button dimensions', () {
        expect(UIConstants.buttonHeight, 48.0);
        expect(UIConstants.buttonWidth, 120.0);
        expect(UIConstants.fabSize, 56.0);
      });
    });
  });

  group('FileConstants', () {
    group('Image Extensions', () {
      test('should contain common image formats', () {
        expect(FileConstants.imageExtensions, containsAll(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']));
      });
    });

    group('Video Extensions', () {
      test('should contain common video formats', () {
        expect(FileConstants.videoExtensions, containsAll(['mp4', 'mov', 'avi', 'mkv', 'webm']));
      });
    });

    group('Audio Extensions', () {
      test('should contain common audio formats', () {
        expect(FileConstants.audioExtensions, containsAll(['mp3', 'wav', 'm4a', 'aac', 'flac']));
      });
    });

    group('Document Extensions', () {
      test('should contain common document formats', () {
        expect(FileConstants.documentExtensions, containsAll(['pdf', 'doc', 'docx', 'txt', 'xlsx']));
      });
    });

    group('HEIC Extensions', () {
      test('should contain HEIC/HEIF formats', () {
        expect(FileConstants.heicExtensions, containsAll(['heic', 'heif']));
      });
    });

    group('File Size Limits', () {
      test('should have correct size limits', () {
        expect(FileConstants.maxImageSizeBytes, 5 * 1024 * 1024); // 5MB
        expect(FileConstants.maxVideoSizeBytes, 50 * 1024 * 1024); // 50MB
        expect(FileConstants.maxAudioSizeBytes, 25 * 1024 * 1024); // 25MB
        expect(FileConstants.maxDocumentSizeBytes, 10 * 1024 * 1024); // 10MB
      });
    });
  });

  group('AppStrings', () {
    group('Status Strings', () {
      test('should have correct status strings', () {
        expect(AppStrings.online, 'Online');
        expect(AppStrings.offline, 'Offline');
        expect(AppStrings.typing, 'Typing...');
        expect(AppStrings.away, 'Away');
      });
    });

    group('Error Strings', () {
      test('should have correct error strings', () {
        expect(AppStrings.networkError, contains('Network'));
        expect(AppStrings.loadingError, contains('load'));
        expect(AppStrings.sendError, contains('send'));
        expect(AppStrings.permissionError, contains('Permission'));
        expect(AppStrings.validationError, contains('Invalid'));
      });
    });

    group('Action Strings', () {
      test('should have correct action strings', () {
        expect(AppStrings.retry, 'Retry');
        expect(AppStrings.cancel, 'Cancel');
        expect(AppStrings.delete, 'Delete');
        expect(AppStrings.edit, 'Edit');
        expect(AppStrings.send, 'Send');
        expect(AppStrings.save, 'Save');
        expect(AppStrings.ok, 'OK');
      });
    });

    group('Message Strings', () {
      test('should have correct message strings', () {
        expect(AppStrings.messageDeleted, 'Message deleted');
        expect(AppStrings.messageEdited, 'Edited');
        expect(AppStrings.copiedToClipboard, 'Copied to clipboard');
        expect(AppStrings.uploadingMessage, 'Uploading...');
      });
    });

    group('Call Status Strings', () {
      test('should have correct call status strings', () {
        expect(AppStrings.incomingCall, contains('Incoming'));
        expect(AppStrings.callEnded, contains('ended'));
        expect(AppStrings.callMissed, contains('Missed'));
        expect(AppStrings.callDeclined, contains('declined'));
      });
    });
  });

  group('RegexPatterns', () {
    group('Email Regex', () {
      test('should match valid emails', () {
        expect(RegexPatterns.emailRegex.hasMatch('test@example.com'), isTrue);
        expect(RegexPatterns.emailRegex.hasMatch('user.name@domain.org'), isTrue);
        expect(RegexPatterns.emailRegex.hasMatch('user+tag@example.co.uk'), isTrue);
      });

      test('should not match invalid emails', () {
        expect(RegexPatterns.emailRegex.hasMatch('invalid'), isFalse);
        expect(RegexPatterns.emailRegex.hasMatch('no@domain'), isFalse);
        expect(RegexPatterns.emailRegex.hasMatch('@example.com'), isFalse);
        expect(RegexPatterns.emailRegex.hasMatch('user@.com'), isFalse);
      });
    });

    group('Phone Regex', () {
      test('should match valid phone numbers', () {
        expect(RegexPatterns.phoneRegex.hasMatch('123-456-7890'), isTrue);
        expect(RegexPatterns.phoneRegex.hasMatch('(123) 456-7890'), isTrue);
        expect(RegexPatterns.phoneRegex.hasMatch('+1234567890'), isTrue);
      });

      test('should not match invalid phone numbers', () {
        expect(RegexPatterns.phoneRegex.hasMatch('12345'), isFalse);
        expect(RegexPatterns.phoneRegex.hasMatch('abc-def-ghij'), isFalse);
      });
    });

    group('Room ID Regex', () {
      test('should match valid room IDs (20+ alphanumeric with _-)', () {
        expect(RegexPatterns.roomIdRegex.hasMatch('a' * 20), isTrue);
        expect(RegexPatterns.roomIdRegex.hasMatch('room_12345678901234567890'), isTrue);
        expect(RegexPatterns.roomIdRegex.hasMatch('room-abc-123-xyz-67890123'), isTrue);
      });

      test('should not match invalid room IDs', () {
        expect(RegexPatterns.roomIdRegex.hasMatch('short'), isFalse);
        expect(RegexPatterns.roomIdRegex.hasMatch('a' * 19), isFalse);
      });
    });

    group('URL Regex', () {
      test('should match valid URLs', () {
        expect(RegexPatterns.urlRegex.hasMatch('https://example.com'), isTrue);
        expect(RegexPatterns.urlRegex.hasMatch('http://www.example.com/path'), isTrue);
        expect(RegexPatterns.urlRegex.hasMatch('https://example.com/path?query=value'), isTrue);
      });

      test('should not match invalid URLs', () {
        expect(RegexPatterns.urlRegex.hasMatch('not-a-url'), isFalse);
        expect(RegexPatterns.urlRegex.hasMatch('ftp://example.com'), isFalse);
      });
    });

    group('Alphanumeric Regex', () {
      test('should match alphanumeric strings', () {
        expect(RegexPatterns.alphanumericRegex.hasMatch('abc123'), isTrue);
        expect(RegexPatterns.alphanumericRegex.hasMatch('ABC'), isTrue);
        expect(RegexPatterns.alphanumericRegex.hasMatch('123'), isTrue);
      });

      test('should not match non-alphanumeric strings', () {
        expect(RegexPatterns.alphanumericRegex.hasMatch('abc 123'), isFalse);
        expect(RegexPatterns.alphanumericRegex.hasMatch('abc-123'), isFalse);
        expect(RegexPatterns.alphanumericRegex.hasMatch('abc_123'), isFalse);
      });
    });

    group('Name Regex', () {
      test('should match valid names', () {
        expect(RegexPatterns.nameRegex.hasMatch('John Doe'), isTrue);
        expect(RegexPatterns.nameRegex.hasMatch('Jane'), isTrue);
        expect(RegexPatterns.nameRegex.hasMatch('Mary Ann Smith'), isTrue);
      });

      test('should not match invalid names', () {
        expect(RegexPatterns.nameRegex.hasMatch('John123'), isFalse);
        expect(RegexPatterns.nameRegex.hasMatch('John-Doe'), isFalse);
        expect(RegexPatterns.nameRegex.hasMatch('John_Doe'), isFalse);
      });
    });
  });

  group('DurationConstants', () {
    group('Animation Durations', () {
      test('should have correct animation durations', () {
        expect(DurationConstants.veryShort.inMilliseconds, 100);
        expect(DurationConstants.short.inMilliseconds, 200);
        expect(DurationConstants.medium.inMilliseconds, 400);
        expect(DurationConstants.long.inMilliseconds, 800);
        expect(DurationConstants.veryLong.inMilliseconds, 1200);
      });
    });

    group('Timeouts', () {
      test('should have correct timeout durations', () {
        expect(DurationConstants.networkTimeout.inSeconds, 30);
        expect(DurationConstants.databaseTimeout.inSeconds, 15);
        expect(DurationConstants.uiTimeout.inSeconds, 5);
      });
    });

    group('Delays', () {
      test('should have correct delay durations', () {
        expect(DurationConstants.debugDelay.inMilliseconds, 500);
        expect(DurationConstants.snackBarDuration.inSeconds, 2);
        expect(DurationConstants.dialogAnimationDuration.inMilliseconds, 300);
        expect(DurationConstants.notificationDuration.inSeconds, 4);
      });
    });
  });

  group('CacheConstants', () {
    test('should have correct cache durations', () {
      expect(CacheConstants.imageCacheDuration.inDays, 7);
      expect(CacheConstants.videoCacheDuration.inDays, 3);
      expect(CacheConstants.messageCacheDuration.inHours, 24);
      expect(CacheConstants.userCacheDuration.inHours, 6);
    });

    test('should have correct cache limits', () {
      expect(CacheConstants.maxCachedImages, 100);
      expect(CacheConstants.maxCachedVideos, 50);
    });
  });

  group('DatabaseConstants', () {
    test('should have correct database values', () {
      expect(DatabaseConstants.queryTimeout, 30000);
      expect(DatabaseConstants.maxRetries, 3);
      expect(DatabaseConstants.retryDelay.inSeconds, 2);
    });
  });

  group('PlatformConstants', () {
    test('should have correct safe area padding values', () {
      expect(PlatformConstants.safeAreaPaddingSmall, 8.0);
      expect(PlatformConstants.safeAreaPaddingMedium, 16.0);
      expect(PlatformConstants.safeAreaPaddingLarge, 24.0);
    });

    test('should have correct bar heights', () {
      expect(PlatformConstants.statusBarHeight, 24.0);
      expect(PlatformConstants.navigationBarHeight, 56.0);
      expect(PlatformConstants.bottomNavigationHeight, 80.0);
    });
  });
}
