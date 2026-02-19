import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';
import 'package:greenhive_app/firebase_options.dart';

/// Helper class to setup test environment
class TestSetup {
  static void setupTestEnvironment() {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Firebase might already be initialized
      if (!e.toString().contains('already exists')) {
        rethrow;
      }
    }
  }

  static void resetServiceLocator() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    if (sl.isRegistered<SnackbarService>()) {
      sl.unregister<SnackbarService>();
    }
  }

  static void registerMockLogger(Mock mockLogger) {
    if (!sl.isRegistered<AppLogger>()) {
      sl.registerSingleton<AppLogger>(mockLogger as AppLogger);
    }
  }

  static void registerMockSnackbar(Mock mockSnackbar) {
    if (!sl.isRegistered<SnackbarService>()) {
      sl.registerSingleton<SnackbarService>(mockSnackbar as SnackbarService);
    }
  }
}

/// Helper function to create test user data
Map<String, dynamic> createTestUserData({
  String id = 'test_user_123',
  String name = 'Test User',
  String? email = 'test@example.com',
  List<String>? roles,
  List<String>? languages,
  List<String>? expertises,
}) {
  return {
    'id': id,
    'name': name,
    'email': email,
    'roles': roles ?? ['Consumer'],
    'langs': languages ?? ['English'],
    'exps': expertises ?? [],
    'fcms': [],
    'created_at': DateTime.now().millisecondsSinceEpoch,
    'notifications_enabled': true,
  };
}

/// Helper function to create test message data
Map<String, dynamic> createTestMessageData({
  String id = 'msg_123',
  String senderId = 'user_123',
  String text = 'Test message',
  String type = 'text',
}) {
  return {
    'id': id,
    'sender_id': senderId,
    'text': text,
    'type': type,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
}

/// Helper function to create test chat room data
Map<String, dynamic> createTestChatRoomData({
  String id = 'room_123',
  List<String>? participants,
  String? lastMessage,
}) {
  return {
    'id': id,
    'participants': participants ?? ['user_1', 'user_2'],
    'last_message': lastMessage ?? 'Hello',
    'last_message_time': DateTime.now().millisecondsSinceEpoch,
    'unread_count': 0,
  };
}

/// Wait for async operations to complete
Future<void> pumpAndSettle(WidgetTester tester, {Duration? duration}) async {
  await tester.pumpAndSettle(duration ?? const Duration(seconds: 1));
}
