# Service Locator Quick Reference

**Last Updated:** January 9, 2026  
**Audience:** All Developers  

---

## TL;DR - Just Show Me How to Use It

### Get a Service
```dart
import 'package:greenhive_app/core/service_locator.dart';

final chatService = sl<ChatService>();
final notifications = sl<NotificationService>();
```

### In a StatefulWidget
```dart
import 'package:greenhive_app/core/service_locator.dart';

class _MyPageState extends State<MyPage> {
  late final ChatService _chat;
  
  @override
  void initState() {
    super.initState();
    _chat = sl<ChatService>();
  }
  
  @override
  void build(BuildContext context) {
    // Use _chat here
  }
}
```

### In Tests
```dart
import 'package:greenhive_app/core/service_locator.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    resetServiceLocator();
    sl.registerSingleton<ChatService>(MockChatService());
  });
  
  test('example', () {
    final service = sl<ChatService>();
    // Use mock service
  });
}
```

---

## All Available Services

### Core Services
```dart
sl<RemoteConfigService>()       // Dynamic config
sl<ErrorHandler>()              // Error handling
sl<EventBus>()                  // App-wide events
```

### Database
```dart
sl<FirestoreInstance>()         // Firestore DB
```

### User & Cache
```dart
sl<UserProfileService>()        // Current user
sl<UserCacheService>()          // User cache
sl<RingtoneService>()           // Sounds
```

### Chat Services
```dart
sl<ChatService>()               // REST API
sl<FirestoreChatService>()      // Real-time
sl<UnreadMessagesService>()     // Message counts
sl<MediaUploadService>()        // Upload
sl<MediaDownloadService>()      // Download
sl<MediaCacheService>()         // Cache
sl<AudioRecordingManager>()     // Voice messages
sl<ReplyManagementService>()    // Replies
```

### Auth & Profile
```dart
sl<BiometricAuthService>()      // Biometric
sl<ProfilePictureService>()     // Profiles
sl<SkillsService>()             // Skills
```

### Notifications & API
```dart
sl<NotificationService>()       // Local notifs
sl<FirebaseMessagingService>()  // Push notifs
sl<ApiService>()                // REST API
sl<DialogService>()             // Dialogs
```

### Call Services
Call services are registered via `call_dependencies.dart`

---

## Common Patterns

### Pattern 1: Simple Service Usage

**Before:**
```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirestoreChatService().getRoomMessages(roomId, token),
      builder: (context, snapshot) {
        // ...
      },
    );
  }
}
```

**After:**
```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: sl<FirestoreChatService>().getRoomMessages(roomId, token),
      builder: (context, snapshot) {
        // ...
      },
    );
  }
}
```

### Pattern 2: Multiple Services

```dart
class _MyPageState extends State<MyPage> {
  late final FirestoreChatService _chat;
  late final UnreadMessagesService _unread;
  
  @override
  void initState() {
    super.initState();
    _chat = sl<FirestoreChatService>();
    _unread = sl<UnreadMessagesService>();
  }
}
```

### Pattern 3: With Provider

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => sl<ChatService>()),
        Provider(create: (_) => sl<UserProfileService>()),
      ],
      child: MaterialApp(
        home: HomePage(),
      ),
    );
  }
}
```

### Pattern 4: Dependency Injection in Services

```dart
class MyCustomService {
  final ChatService _chat;
  final UserProfileService _user;
  
  MyCustomService({
    ChatService? chat,
    UserProfileService? user,
  }) : 
    _chat = chat ?? sl<ChatService>(),
    _user = user ?? sl<UserProfileService>();
}
```

---

## Testing Patterns

### Unit Test Example

```dart
import 'package:greenhive_app/core/service_locator.dart';
import 'package:test/test.dart';

class MockChatService extends Mock implements ChatService {
  @override
  Future<List<Room>> getUserRooms(String token) async => [
    Room(id: '1', name: 'Room 1'),
  ];
}

void main() {
  group('My Feature', () {
    setUp(() {
      resetServiceLocator();
      sl.registerSingleton<ChatService>(MockChatService());
    });

    test('loads rooms', () async {
      final service = sl<ChatService>();
      final rooms = await service.getUserRooms('token');
      expect(rooms, hasLength(1));
    });
  });
}
```

### Widget Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/core/service_locator.dart';

void main() {
  group('Chat Page', () {
    setUp(() {
      resetServiceLocator();
      sl.registerSingleton<FirestoreChatService>(MockFirestoreChatService());
      sl.registerSingleton<UnreadMessagesService>(MockUnreadMessagesService());
    });

    testWidgets('displays rooms', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp());
      
      expect(find.byType(ChatPage), findsOneWidget);
      expect(find.text('Room 1'), findsOneWidget);
    });
  });
}
```

---

## Do's and Don'ts

### ✅ DO

- Use `sl<ServiceType>()` to get services
- Call `resetServiceLocator()` in test setUp()
- Register mock services in tests
- Get services in `initState()` for StatefulWidgets
- Use lazy singletons for most services
- Document service dependencies

### ❌ DON'T

- Create services directly with `ServiceName()`
- Forget to import `service_locator.dart`
- Register services outside `setupServiceLocator()`
- Reset service locator in production code
- Use `sl<>` before `setupServiceLocator()` is called
- Keep references across app lifecycle (use getters instead)

---

## Migration Checklist

### For Existing Code

- [ ] Add import: `import 'package:greenhive_app/core/service_locator.dart';`
- [ ] Find: `final service = ServiceName();`
- [ ] Replace with: `final service = sl<ServiceName>();`
- [ ] In StatefulWidget? Move to initState
- [ ] Test the change
- [ ] Commit and push

### For New Code

- [ ] Use `sl<ServiceType>()` from the start
- [ ] Add import for service_locator
- [ ] No direct service instantiation
- [ ] Test with mocks
- [ ] Document any new service in `service_locator.dart`

---

## Troubleshooting

### Error: "Unregistered service: ChatService"

**Cause:** Service not registered or `setupServiceLocator()` not called

**Fix:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupServiceLocator();  // ← Add this
  runApp(MyApp());
}
```

### Error: "Unimplemented exception: ProviderNotFound"

**Cause:** Using service before initialization

**Fix:** Ensure `setupServiceLocator()` is called before building widgets

### Mock Not Being Used

**Cause:** Service already registered before test

**Fix:**
```dart
setUp(() {
  resetServiceLocator();  // ← Clear first
  sl.registerSingleton<ChatService>(MockChatService());
});
```

### Service Null Reference

**Cause:** Getting service in initState but using before initialized

**Fix:**
```dart
@override
void initState() {
  super.initState();
  _service = sl<MyService>();  // Initialize early
}
```

---

## Advanced Usage

### Lazy vs Eager Registration

```dart
// Lazy - created when first accessed
sl.registerLazySingleton<MyService>(() => MyService());

// Eager - created immediately
sl.registerSingleton<MyService>(MyService());

// Factory - new instance each time
sl.registerFactory<MyService>(() => MyService());
```

### Environment-Specific Services

```dart
void setupServiceLocator() {
  if (kDebugMode) {
    sl.registerLazySingleton<Logger>(() => DebugLogger());
  } else {
    sl.registerLazySingleton<Logger>(() => ProductionLogger());
  }
}
```

### Checking Service Registration

```dart
if (sl.isRegistered<ChatService>()) {
  final service = sl<ChatService>();
  // Use service
}
```

### Service with Parameters

```dart
// For ChatStreamService which needs roomId
final streamService = ChatStreamService(roomId: 'room123');

// Use it (not from service locator, created locally)
streamService.startListening();
```

---

## Quick Command Reference

```bash
# Check if everything compiles
flutter analyze

# Run tests
flutter test

# Add new dependency
flutter pub add package_name

# Get all dependencies
flutter pub get
```

---

## Links & Resources

- **Implementation Details:** [PHASE_1_FOUNDATION_COMPLETE.md](PHASE_1_FOUNDATION_COMPLETE.md)
- **Phase Summary:** [PHASE_1_SUMMARY.md](PHASE_1_SUMMARY.md)
- **Code:** [lib/core/service_locator.dart](lib/core/service_locator.dart)
- **GetIt Package:** https://pub.dev/packages/get_it

---

## Common Use Cases

### Use Case 1: Fetching Chat Messages

```dart
import 'package:greenhive_app/core/service_locator.dart';

class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final FirestoreChatService _chat;

  @override
  void initState() {
    super.initState();
    _chat = sl<FirestoreChatService>();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final messages = await _chat.getRoomMessages('room123', 'token');
    setState(() {
      // Update UI
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: _buildMessageList(),
    );
  }
}
```

### Use Case 2: Showing a Notification

```dart
import 'package:greenhive_app/core/service_locator.dart';

void showNotification() {
  sl<NotificationService>().show(
    title: 'New Message',
    body: 'You have a new message',
  );
}
```

### Use Case 3: Caching User Data

```dart
import 'package:greenhive_app/core/service_locator.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final UserProfileService _profile;

  @override
  void initState() {
    super.initState();
    _profile = sl<UserProfileService>();
  }

  @override
  Widget build(BuildContext context) {
    final user = _profile.userProfile;
    return Scaffold(
      appBar: AppBar(title: Text(user?.name ?? 'User')),
    );
  }
}
```

---

## Getting Help

- Read full docs: [PHASE_1_FOUNDATION_COMPLETE.md](PHASE_1_FOUNDATION_COMPLETE.md)
- Check implementation: [lib/core/service_locator.dart](lib/core/service_locator.dart)
- Ask team lead
- Check similar code in `lib/pages/`
- Review test files

---

**Remember:** The service locator is your friend! It makes code cleaner, more testable, and easier to maintain. Use it everywhere.
