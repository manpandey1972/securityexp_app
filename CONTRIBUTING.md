# Contributing to GreenHive

**Welcome!** We're excited to have you contribute to GreenHive. This guide will help you get started.

---

## 📑 Table of Contents

1. [Getting Started](#getting-started)
2. [Code Organization](#code-organization)
3. [Architecture Guidelines](#architecture-guidelines)
4. [Coding Standards](#coding-standards)
5. [Naming Conventions](#naming-conventions)
6. [Writing Comments](#writing-comments)
7. [Git Workflow](#git-workflow)
8. [Code Review Process](#code-review-process)
9. [Testing Requirements](#testing-requirements)
10. [Debugging Tips](#debugging-tips)
11. [Common Tasks](#common-tasks)
12. [Troubleshooting](#troubleshooting)

---

## 🚀 Getting Started

### Prerequisites

```bash
# Check your environment
flutter doctor

# Required:
- Flutter 3.13+
- Dart 3.0+
- Xcode 14+ (macOS/iOS)
- Android Studio (Android)
```

### Setup Development Environment

```bash
# 1. Clone repository
git clone <repository-url>
cd greenhive_app

# 2. Install dependencies
flutter pub get

# 3. Generate code (if needed)
flutter pub run build_runner build

# 4. Run app
flutter run

# 5. Run tests
flutter test
```

### IDE Setup

**VS Code:**
```bash
# Install extensions
- Dart
- Flutter
- Firebase Explorer (optional)
```

**Android Studio:**
```bash
# Install plugins
- Dart
- Flutter
- Firebase (optional)
```

---

## 📁 Code Organization

### Understanding the Structure

```
lib/
├── core/                    # Shared functionality
│   ├── service_locator.dart     # Dependency injection
│   ├── validators/              # Input validation
│   ├── constants/               # App constants
│   └── extensions/              # Dart extensions
│
├── features/                # Feature modules
│   └── chat/                    # Chat feature
│       ├── data/                # Data layer
│       ├── domain/              # Domain layer
│       └── presentation/        # UI layer
│
├── models/                  # Shared data models
├── services/                # Shared business services
├── pages/                   # Shared pages
└── widgets/                 # Reusable widgets
```

### Canonical Feature Structure (MVVM)

All features **must** follow this MVVM structure. This is the single standard pattern for the project:

```
lib/features/<feature_name>/
├── pages/                         # Full-screen pages (routes)
│   └── <feature>_page.dart
├── widgets/                       # Feature-specific widgets
│   └── <feature>_widget.dart
├── presentation/
│   ├── view_models/               # ChangeNotifier ViewModels
│   │   └── <feature>_view_model.dart
│   └── state/                     # Immutable state classes
│       └── <feature>_state.dart
├── services/                      # Feature-specific business logic
│   └── <feature>_service.dart
├── data/                          # Feature-specific models & repos (if needed)
│   ├── models/
│   └── repositories/
└── utils/                         # Feature-specific helpers
```

**Key rules:**

1. **ViewModels** extend `ChangeNotifier` and hold an immutable state object
2. **Pages** use `Consumer<ViewModel>` or `context.watch<ViewModel>()` — no business logic in pages
3. **Services** never take `BuildContext` — UI feedback (dialogs, snackbars) is handled in the page/VM layer
4. **No direct Firebase access** in pages/widgets — inject via constructor or service locator
5. **Feature-specific code stays inside the feature** — don't put chat helpers in `lib/utils/`

**Minimal ViewModel example:**

```dart
class MyFeatureState {
  final bool isLoading;
  final String? error;
  final List<Item> items;

  const MyFeatureState({
    this.isLoading = false,
    this.error,
    this.items = const [],
  });

  MyFeatureState copyWith({bool? isLoading, String? error, List<Item>? items}) {
    return MyFeatureState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      items: items ?? this.items,
    );
  }
}

class MyFeatureViewModel extends ChangeNotifier {
  final MyFeatureService _service;
  MyFeatureState _state = const MyFeatureState();

  MyFeatureViewModel({required MyFeatureService service}) : _service = service;

  MyFeatureState get state => _state;

  Future<void> loadItems() async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    final result = await ErrorHandler.handle<List<Item>>(
      operation: () => _service.fetchItems(),
      fallback: [],
      onError: (error) {
        _state = _state.copyWith(isLoading: false, error: error);
        notifyListeners();
      },
    );

    _state = _state.copyWith(isLoading: false, items: result);
    notifyListeners();
  }
}
```

### Adding a New Feature

```bash
# 1. Create feature directory with canonical structure
mkdir -p lib/features/new_feature/{pages,widgets,services,utils}
mkdir -p lib/features/new_feature/presentation/{view_models,state}

# 2. Create matching test directory
mkdir -p test/features/new_feature

# 3. Start implementing (see ViewModel example above)
```

---

## 🏗️ Architecture Guidelines

### Layer Responsibilities

#### 1. **Presentation Layer** (`presentation/`)
- **Contains:** Pages, Widgets, Providers
- **Responsibility:** Display UI, collect input, trigger actions
- **Rules:**
  - No business logic
  - No direct Firestore access
  - Use providers for state
  - Validate user input

```dart
// ✅ GOOD: Use provider for business logic
Consumer(
  builder: (context, ref, child) {
    final viewModel = ref.watch(chatProvider);
    return ListView(
      children: viewModel.chats.map((chat) => ChatTile(chat)).toList(),
    );
  },
)

// ❌ BAD: Business logic in UI
Consumer(
  builder: (context, ref, child) {
    final chats = FirebaseFirestore.instance.collection('chats');
    // Don't fetch directly!
    return Text('Chats');
  },
)
```

#### 2. **Domain Layer** (`domain/`)
- **Contains:** Entities, Abstract Repositories
- **Responsibility:** Define interfaces and data models
- **Rules:**
  - No concrete implementations
  - No Firebase imports
  - Pure Dart code

```dart
// ✅ GOOD: Abstract repository
abstract class ChatRepository {
  Future<List<Chat>> getChats();
  Future<void> sendMessage(String chatId, Message message);
}

// Entity
class Chat {
  final String id;
  final String title;
  final DateTime createdAt;
}

// ❌ BAD: No concrete implementation here
class ChatRepositoryImpl implements ChatRepository { }
```

#### 3. **Data Layer** (`data/`)
- **Contains:** Repositories, Data Sources
- **Responsibility:** Implement abstract interfaces
- **Rules:**
  - Connect to external APIs (Firestore)
  - Implement repository interfaces
  - Handle data transformation

```dart
// ✅ GOOD: Implement abstract repository
class ChatRepositoryImpl implements ChatRepository {
  final FirestoreChatService _firestoreService;
  
  ChatRepositoryImpl({required FirestoreChatService firestoreService})
    : _firestoreService = firestoreService;
  
  @override
  Future<List<Chat>> getChats() async {
    return _firestoreService.fetchChats();
  }
}
```

#### 4. **Service Layer** (`services/`)
- **Contains:** Business logic services
- **Responsibility:** Orchestrate operations
- **Rules:**
  - Use repositories for data
  - Implement business rules
  - Register in service locator

```dart
// ✅ GOOD: Business logic in service
class ChatService {
  final ChatRepository _repository;
  
  ChatService({required ChatRepository repository})
    : _repository = repository;
  
  Future<void> sendMessage(String chatId, String text) async {
    final validated = MessageValidator().validate(text);
    if (!validated.isValid) throw Exception(validated.message);
    
    final sanitized = InputSanitizer().sanitizeMessage(text);
    
    final message = Message(
      text: sanitized,
      senderId: getCurrentUserId(),
      timestamp: DateTime.now(),
    );
    
    await _repository.sendMessage(chatId, message);
  }
}
```

### Dependency Flow

```
✅ CORRECT: UI → Service → Repository → DataSource
            (Provider)  (Logic)     (Data)    (API)

❌ INCORRECT: UI → Repository (bypasses business logic)
              UI → DataSource (breaks abstraction)
              Repository → Service (wrong direction)
```

---

## 📝 Coding Standards

### Null Safety

**Always use null safety:**
```dart
// ✅ GOOD: Explicit types
String name = 'John';
String? nickname;
List<String> items = [];
List<String>? optionalList;

// ❌ BAD: Avoid dynamic
dynamic data = 'test';
var user = getUser(); // When type unclear
```

### Error Handling

We have two complementary error handling mechanisms. Use each for its intended layer:

| Mechanism | Where | When to use |
|-----------|-------|-------------|
| `Result<T>` | Repositories & services | Return typed success/failure from data operations |
| `ErrorHandler.handle()` | ViewModels & orchestration | Wrap calls that may fail, log, and provide fallback |

**`Result<T>` — Repositories & Service returns:**
```dart
// ✅ Repository returns Result<T> so callers decide how to react
Future<Result<List<Chat>>> getChats() async {
  try {
    final chats = await _firestore.collection('chats').get();
    return Result.success(chats.docs.map(Chat.fromFirestore).toList());
  } catch (e) {
    return Result.error('Failed to load chats: $e');
  }
}

// Caller uses .when() for branching
final result = await chatRepo.getChats();
result.when(
  success: (chats) => _state = _state.copyWith(chats: chats),
  failure: (error) => _state = _state.copyWith(errorMessage: error.toString()),
);
```

**`ErrorHandler.handle()` — ViewModel / orchestration layer:**
```dart
// ✅ ViewModel uses ErrorHandler for fire-and-forget or fallback operations
Future<void> loadItems() async {
  _state = _state.copyWith(isLoading: true);
  final items = await ErrorHandler.handle<List<Item>>(
    operation: () => _repository.fetchItems(),
    fallback: [],
    onError: (msg) => _state = _state.copyWith(errorMessage: msg),
  );
  _state = _state.copyWith(isLoading: false, items: items);
  notifyListeners();
}
```

**Deprecated methods** — do **not** use these in new code:
- `ErrorHandler.executeAsync()` → use `ErrorHandler.handle()`
- `ErrorHandler.executeVoid()` → use `ErrorHandler.handle<void>()`
- `ErrorHandler.executeSync()` → use `ErrorHandler.handleSync()`
- `ErrorHandler.executeMultiple()` → use `Future.wait` with `ErrorHandler.handle()`

```dart
// ❌ BAD: Ignoring errors
await sendMessage(text);

// ❌ BAD: Using deprecated executeAsync
await ErrorHandler.executeAsync(operation: 'send', fn: () => send(text));

// ✅ GOOD: Using handle
await ErrorHandler.handle<void>(operation: () => send(text));
```

### Async/Await

**Use async/await for futures:**
```dart
// ✅ GOOD
Future<List<Chat>> loadChats() async {
  try {
    return await repository.getChats();
  } catch (e) {
    return [];
  }
}

// ❌ BAD: Using .then()
loadChats() {
  return repository.getChats().then((chats) {
    return chats;
  });
}
```

### Constants

**Define constants properly:**
```dart
// ✅ GOOD: Const for compile-time constants
const String appName = 'GreenHive';
const int maxMessageLength = 5000;

// ✅ GOOD: Final for runtime constants
final now = DateTime.now();
final regex = RegExp(r'^\d{10}$');

// ❌ BAD: Using magic numbers
if (text.length > 5000) { }
```

### Collections

**Use typed collections:**
```dart
// ✅ GOOD: Explicit types
List<Chat> chats = [];
Map<String, User> users = {};
Set<String> ids = {};

// ❌ BAD: Untyped
List chats = [];
var chats = [];
```

---

## 🏷️ Naming Conventions

### Files and Directories

```dart
// ✅ GOOD: Snake case
chat_service.dart
user_repository.dart
message_validator.dart
chat_page.dart
message_bubble.dart

// ❌ BAD: Camel case or mixed
chatService.dart
UserRepository.dart
MessageValidator.dart
```

### Classes

```dart
// ✅ GOOD: Pascal case
class ChatService { }
class MessageValidator { }
class UserProfile { }

// ❌ BAD: Lower case
class chatService { }
class message_validator { }
```

### Variables and Functions

```dart
// ✅ GOOD: Camel case
String displayName;
String? photoUrl;
void sendMessage() { }
Future<List<Chat>> getChats() { }

// ❌ BAD: Other cases
String display_name;
String PhotoURL;
void SendMessage() { }
```

### Constants

```dart
// ✅ GOOD: Upper snake case
const String APP_NAME = 'GreenHive';
const int MAX_MESSAGE_LENGTH = 5000;
const double DEFAULT_PADDING = 16.0;

// ❌ BAD: Camel case
const String appName = 'GreenHive'; // Use const for simple constants
const int maxMessageLength = 5000;
```

### Private Members

```dart
// ✅ GOOD: Leading underscore
class _ChatViewState { }
void _handleSubmit() { }
final _controller = TextEditingController();

// ❌ BAD: No underscore
class ChatViewState { }
void handleSubmit() { }
```

### Booleans

```dart
// ✅ GOOD: is/has prefix
bool isLoading = false;
bool hasError = false;
bool isVisible = true;
bool isEmpty = true;

// ❌ BAD: Unclear
bool loading = false;
bool error = false;
```

---

## 💬 Writing Comments

### Doc Comments

```dart
// ✅ GOOD: Document public API
/// Sends a chat message to the specified conversation.
/// 
/// This method validates and sanitizes the message before sending.
/// It throws an exception if the message is invalid.
/// 
/// Parameters:
///   - chatId: The ID of the chat conversation
///   - text: The message text to send
/// 
/// Returns: A Future that completes when the message is sent
/// 
/// Throws: [ValidationException] if message validation fails
Future<void> sendMessage(String chatId, String text) async { }

// ✅ GOOD: Class documentation
/// Manages all chat-related operations.
/// 
/// This service handles sending messages, loading conversations,
/// and managing chat state. It uses [ChatRepository] for data access
/// and [MessageValidator] for input validation.
/// 
/// Example:
/// ```dart
/// final service = ChatService(repository: repository);
/// await service.sendMessage('chat1', 'Hello');
/// ```
class ChatService { }
```

### Inline Comments

```dart
// ✅ GOOD: Explain why, not what
// Validate before sanitizing to provide better error messages
final validation = MessageValidator().validate(text);
if (!validation.isValid) {
  throw ValidationException(validation.message);
}

// ❌ BAD: Obvious comments
// Set the title
title = 'Chat';

// ❌ BAD: Out of date
// TODO: Fix this later (if nobody knows what "this" is)
```

### TODO Comments

```dart
// ✅ GOOD: Clear TODOs
// TODO: Add rate limiting when messages exceed 100/min (FEATURE-123)
// TODO(john@example.com): Refactor this method (DUE: 2026-02-01)

// ❌ BAD: Vague TODOs
// TODO: Fix this
// TODO: Improve performance
```

---

## 🔗 Git Workflow

### Branch Naming

```bash
# Feature branches
git checkout -b feature/user-profiles
git checkout -b feature/video-calling

# Bug fix branches
git checkout -b fix/crash-on-logout
git checkout -b fix/message-validation-bug

# Refactoring branches
git checkout -b refactor/chat-service
git checkout -b refactor/validator-cleanup

# Documentation branches
git checkout -b docs/api-reference
git checkout -b docs/setup-guide
```

### Commit Messages

```bash
# ✅ GOOD: Clear, descriptive
git commit -m "feat: Add email validation to signup form"
git commit -m "fix: Handle null messages in chat list"
git commit -m "docs: Add contributing guidelines"
git commit -m "refactor: Extract common validation logic"
git commit -m "test: Add unit tests for EmailValidator"

# ❌ BAD: Vague, unclear
git commit -m "update"
git commit -m "fix bugs"
git commit -m "WIP"
git commit -m "asdf"

# Commit format: <type>: <description>
# Types: feat, fix, docs, refactor, test, chore, perf
```

### Pull Request Workflow

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes, commit regularly
git add .
git commit -m "feat: Implement feature"

# 3. Push to remote
git push origin feature/my-feature

# 4. Create pull request on GitHub/GitLab
# - Link to issue
# - Describe changes
# - Request reviewers

# 5. Address review comments
git add .
git commit -m "review: Address feedback"
git push origin feature/my-feature

# 6. Merge after approval
```

---

## 👀 Code Review Process

### Before Submitting for Review

- [ ] Code follows architecture guidelines
- [ ] All naming conventions followed
- [ ] Error handling implemented
- [ ] Input validation added
- [ ] Input sanitization applied
- [ ] Tests written
- [ ] No compilation errors (`flutter analyze`)
- [ ] Code formatted (`dart format`)
- [ ] Comments are clear and helpful

### What Reviewers Look For

| Aspect | Checklist |
|---|---|
| **Architecture** | Follows layers? Correct dependencies? Service locator used? |
| **Standards** | Null safety? Error handling? Naming conventions? |
| **Testing** | Tests included? Edge cases covered? |
| **Security** | Input validated? Sanitized? No hardcoded secrets? |
| **Performance** | Efficient queries? No memory leaks? Optimized? |
| **Documentation** | Comments clear? Updated docs? Examples? |

### Review Comments

```dart
// ✅ GOOD: Helpful, constructive
// Consider using ValidatorBuilders.emailValidator instead of
// creating a new EmailValidator instance. This is more consistent
// with the app's patterns.

// ✅ GOOD: Asks questions
// What happens if getChats() throws an exception here?
// Should we add error handling?

// ✅ GOOD: Explains why
// I'd suggest moving this logic to ChatService instead of the
// provider. This keeps business logic separated from state
// management and makes it easier to test.

// ❌ BAD: Dismissive
// This is wrong.

// ❌ BAD: Unclear
// Doesn't work.

// ❌ BAD: Nitpicky without explanation
// Change this variable name.
```

---

## 🧪 Testing Requirements

### When to Write Tests

| Scenario | Required? |
|---|---|
| New validator class | ✅ YES |
| New service | ✅ YES |
| New repository | ✅ YES |
| New widget (complex logic) | ✅ YES |
| Bug fix | ✅ YES |
| UI page | Optional (widget tests) |
| Trivial helper | Optional |

### Test Structure

```dart
void main() {
  // Group related tests
  group('EmailValidator', () {
    late EmailValidator validator;
    
    // Setup before each test
    setUp(() {
      validator = EmailValidator();
    });
    
    // Test valid input
    test('accepts valid email', () {
      final result = validator.validate('user@example.com');
      expect(result.isValid, true);
    });
    
    // Test invalid input
    test('rejects invalid email', () {
      final result = validator.validate('invalid@');
      expect(result.isValid, false);
    });
    
    // Test edge cases
    test('handles empty string', () {
      final result = validator.validate('');
      expect(result.isValid, false);
    });
  });
}
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/validators/email_validator_test.dart

# Run with coverage
flutter test --coverage

# Run tests matching pattern
flutter test --name "EmailValidator"
```

---

## 🐛 Debugging Tips

### Enable Debug Logging

```dart
// In main.dart
import 'dart:developer' as developer;

developer.log(
  'Message loaded',
  name: 'chat_service',
  level: 500,
);
```

### Use Debugger

```dart
// Set breakpoint and inspect variables
void sendMessage(String text) {
  developer.Timeline.instantSync('sendMessage');
  debugger(); // Stops here in debug mode
  print('Sending: $text');
}
```

### Print Debugging

```dart
// ✅ GOOD: Named print statements
print('[CHAT SERVICE] Loading chats...');
print('[ERROR] Failed to send message: $error');

// ❌ BAD: Unclear output
print(text);
print(value);
```

### Flutter DevTools

```bash
# Open DevTools
flutter pub global activate devtools
devtools

# Or from IDE: Run > Open DevTools
```

### Firebase Emulator

```bash
# Start emulator
firebase emulators:start

# Connect app to emulator (in main.dart)
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

---

## 🔧 Common Tasks

### Adding a New Validator

```dart
// 1. Create file: lib/core/validators/username_validator.dart
class UsernameValidator extends BaseValidator {
  @override
  ValidationResult validate(String value) {
    // Validation logic
    if (value.isEmpty) {
      return ValidationResult(
        isValid: false,
        message: 'Username is required',
      );
    }
    // ... more validation
    return ValidationResult(isValid: true);
  }
}

// 2. Export in lib/core/validators/validators.dart
export 'username_validator.dart';

// 3. Use in forms
TextFormField(
  validator: (value) => UsernameValidator().validate(value).message,
)
```

### Adding a New Service

```dart
// 1. Create file: lib/services/notification_service.dart
class NotificationService {
  Future<void> sendNotification(String title, String body) async {
    // Implementation
  }
}

// 2. Register in service_locator.dart
getIt.registerSingleton<NotificationService>(
  NotificationService(),
);

// 3. Use anywhere
final notificationService = getIt<NotificationService>();
await notificationService.sendNotification('Title', 'Body');
```

### Adding a New Feature

```bash
# 1. Create structure
mkdir -p lib/features/notifications/{data,domain,presentation}

# 2. Create entities (domain/entities/)
# 3. Create abstract repository (domain/repositories/)
# 4. Create repository implementation (data/repositories/)
# 5. Create service (services/)
# 6. Register in service_locator.dart
# 7. Create providers (presentation/providers/)
# 8. Create pages (presentation/pages/)
# 9. Create widgets (presentation/widgets/)
# 10. Add tests
```

### Migrating Page to Service Locator

```dart
// BEFORE: Direct instantiation
class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatService _chatService = ChatService();
  
  @override
  void initState() {
    super.initState();
    _loadChats();
  }
}

// AFTER: Using service locator
class _ChatPageState extends State<ChatPage> {
  late final ChatService _chatService = getIt<ChatService>();
  
  @override
  void initState() {
    super.initState();
    _loadChats();
  }
}
```

---

## ⚠️ Troubleshooting

### Problem: Compilation Errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build

# Check for issues
flutter analyze
```

### Problem: Service Not Found

```dart
// Error: Service not registered in service locator

// Solution 1: Check service_locator.dart
// Make sure service is registered in setupServiceLocator()

// Solution 2: Ensure setupServiceLocator() is called
// In main.dart:
await setupServiceLocator();

// Solution 3: Use correct type
final service = getIt<ChatService>(); // Not getIt.get<ChatService>()
```

### Problem: Validator Not Working

```dart
// Issue: Validator returns valid for invalid input

// Solution: Check validation logic
// Use test to verify behavior
flutter test test/core/validators/email_validator_test.dart

// Solution: Check if validator is being used
TextFormField(
  validator: (value) => ValidatorBuilders.emailValidator(value),
)
```

### Problem: Hot Reload Issues

```bash
# Full restart instead
flutter run --hot

# Or restart from IDE
```

### Problem: Firebase Connection

```dart
// Check Firebase setup
firebase login
firebase projects:list

// Check Firestore connection
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
);

// Test connection
await FirebaseFirestore.instance.collection('test').doc('doc').get();
```

---

## 📚 Resources

### Documentation
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [GetIt Package](https://pub.dev/packages/get_it)
- [Firebase Documentation](https://firebase.google.com/docs)

### Related Guides
- [ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) - System architecture overview
- [SERVICE_LOCATOR_QUICK_REFERENCE.md](docs/guides/SERVICE_LOCATOR_QUICK_REFERENCE.md) - Dependency injection
- [VALIDATORS_QUICK_REFERENCE.md](VALIDATORS_QUICK_REFERENCE.md) - Input validation

### Development Tools
- [DevTools](https://flutter.dev/docs/development/tools/devtools)
- [Android Studio](https://developer.android.com/studio)
- [Xcode](https://developer.apple.com/xcode/)
- [VS Code](https://code.visualstudio.com/)

---

## 🎓 Quick Reference

### Most Common Commands

```bash
# Development
flutter run                           # Run app
flutter test                          # Run tests
flutter analyze                       # Check for issues
dart format lib/                      # Format code

# Git
git checkout -b feature/my-feature    # Create branch
git commit -m "feat: Description"     # Commit
git push origin feature/my-feature    # Push
git pull origin main                  # Update

# Firebase
firebase login                        # Login to Firebase
firebase emulators:start              # Start emulators
firebase deploy                       # Deploy
```

### Most Common Patterns

```dart
// Validate input
final result = EmailValidator().validate(email);

// Sanitize input
final clean = InputSanitizer().sanitizeMessage(text);

// Use service
final service = getIt<ChatService>();

// Handle error
try {
  await operation();
} catch (e) {
  print('Error: $e');
}

// Use provider
Consumer(
  builder: (context, ref, child) {
    final data = ref.watch(myProvider);
    return Text(data);
  },
)
```

---

## ✅ Pre-Commit Checklist

Before pushing code, verify:

- [ ] Code compiles: `flutter analyze` ✅
- [ ] Tests pass: `flutter test` ✅
- [ ] Code formatted: `dart format` ✅
- [ ] Architecture followed: Correct layers, patterns ✅
- [ ] Input validated: All user input checked ✅
- [ ] Input sanitized: Dangerous input cleaned ✅
- [ ] Error handling: Exceptions caught ✅
- [ ] Comments added: Code is understandable ✅
- [ ] Tests included: New code is tested ✅
- [ ] Naming conventions: Consistent naming ✅

---

## 🤝 Getting Help

### Where to Ask Questions

1. **Team Chat:** Ask in #development channel
2. **Code Review:** Ask during review process
3. **Issues:** Check existing issues first
4. **Discussions:** Start discussion for design questions

### How to Report Bugs

```markdown
## Description
Brief description of the bug

## Steps to Reproduce
1. Step one
2. Step two

## Expected Behavior
What should happen

## Actual Behavior
What actually happened

## Environment
- Flutter version
- Device/OS
- Error log
```

---

## 🎉 Thank You!

We appreciate your contributions to GreenHive! By following these guidelines, you help us maintain code quality and make the project better for everyone.

**Questions?** Open an issue or ask in team chat!

---

**Last Updated:** January 9, 2026  
**Maintainer:** GreenHive Development Team  
**Version:** 2.0
