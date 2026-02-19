# GreenHive App - Architecture Guide

**Version:** 3.0  
**Status:** Production Ready  
**Last Updated:** January 16, 2026  
**Phases Completed:** 1-6 (Code Quality Review Implementation)  

---

## 📑 Table of Contents

1. [Overview](#overview)
2. [Architectural Layers](#architectural-layers)
3. [Project Structure](#project-structure)
4. [Design Patterns](#design-patterns)
5. [Service Locator Pattern](#service-locator-pattern)
6. [Validation Framework](#validation-framework)
7. [Data Flow](#data-flow)
8. [Feature Implementation](#feature-implementation)
9. [Dependency Management](#dependency-management)
10. [Testing Strategy](#testing-strategy)
11. [Deployment Architecture](#deployment-architecture)
12. [Communication Protocols](#communication-protocols)

---

## 🎯 Overview

GreenHive is a **Flutter/Dart mobile application** designed with a **layered, modular architecture** emphasizing:

- **Separation of Concerns** - Clear layer boundaries
- **Dependency Injection** - Centralized service management via GetIt
- **Reusability** - Shared components and patterns
- **Testability** - Mockable dependencies
- **Scalability** - Easy feature additions
- **Maintainability** - Clear code organization

### Core Technologies

| Layer | Technology |
|---|---|
| **UI Framework** | Flutter (Dart) |
| **State Management** | Provider + GetIt |
| **Dependency Injection** | GetIt v7.6.0 |
| **Backend** | Firebase (Firestore, Auth, Storage) |
| **Real-time Communication** | WebSockets + Cloud Functions |
| **Local Storage** | SharedPreferences + SQLite |
| **Input Validation** | Custom Validator Framework |

---

## 🏗️ Architectural Layers

```
┌─────────────────────────────────────────┐
│         UI Layer (Presentation)          │
│  Pages, Widgets, Screens, Theme         │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│    State Management Layer (Logic)        │
│  Providers, Notifiers, State Classes    │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│    Service Layer (Business Logic)       │
│  ChatService, AuthService, Validators   │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│    Repository Layer (Data Access)       │
│  ChatRepository, UserRepository         │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│    Data Source Layer (External APIs)    │
│  Firestore, Firebase Auth, Cloud Func   │
└─────────────────────────────────────────┘
```

### Layer Responsibilities

#### 1. **UI Layer (Presentation)**
- **Responsibility:** Display data, handle user interactions
- **Contains:** Pages, Widgets, Screens, Theme configurations
- **Examples:** `ChatPage`, `ChatConversationPage`, `LoginPage`
- **Communication:** Read from providers, trigger actions through providers
- **Dependencies:** State Management Layer

#### 2. **State Management Layer (Logic)**
- **Responsibility:** Manage application state, business logic
- **Contains:** Providers, StateNotifiers, ChangeNotifiers
- **Examples:** `ChatProvider`, `AuthProvider`, `UserProvider`
- **Communication:** Calls services, updates UI
- **Dependencies:** Service Layer

#### 3. **Service Layer (Business Logic)**
- **Responsibility:** Implement business rules, coordinate operations
- **Contains:** Business logic services, validators, utility classes
- **Examples:** `ChatService`, `AuthService`, `UserProfileService`, `EmailValidator`
- **Communication:** Uses repositories and local logic
- **Dependencies:** Repository Layer, Validators

#### 4. **Repository Layer (Data Access)**
- **Responsibility:** Provide clean data access interface
- **Contains:** Repository implementations
- **Examples:** `ChatRepository`, `UserRepository`, `AuthRepository`
- **Communication:** Abstracts data sources
- **Dependencies:** Data Source Layer

#### 5. **Data Source Layer (External APIs)**
- **Responsibility:** Direct communication with external systems
- **Contains:** Firestore client, Firebase Auth, Cloud Functions
- **Examples:** Firestore queries, Firebase Authentication
- **Communication:** REST/WebSocket/Real-time listeners
- **Dependencies:** None

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── app.dart                           # App configuration
│
├── core/                              # Shared core functionality
│   ├── service_locator.dart          # Dependency injection (Phase 1)
│   ├── validators/                    # Input validation (Phase 2)
│   │   ├── base_validator.dart
│   │   ├── email_validator.dart
│   │   ├── phone_validator.dart
│   │   ├── message_validator.dart
│   │   ├── form_validation_mixin.dart
│   │   └── validators.dart
│   ├── constants/                     # Application constants
│   ├── extensions/                    # Dart extensions
│   ├── utils/                         # Utility functions
│   └── theme/                         # Theme configuration
│
├── features/                          # Feature modules
│   ├── auth/                          # Authentication feature
│   │   ├── data/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── pages/
│   │
│   ├── chat/                          # Chat feature (Primary)
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   └── repositories/
│   │   └── presentation/
│   │       ├── pages/
│   │       ├── providers/
│   │       ├── widgets/
│   │       └── providers.dart
│   │
│   ├── calls/                         # Calling feature
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── user_profile/                  # User profile feature
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── notifications/                 # Notifications feature
│       ├── data/
│       ├── domain/
│       └── presentation/
│
├── models/                            # Shared data models
├── services/                          # Shared services
├── providers/                         # Shared state providers
├── pages/                             # Shared pages
└── widgets/                           # Shared widgets

android/                               # Android native code
ios/                                   # iOS native code
web/                                   # Web deployment
functions/                             # Firebase Cloud Functions
pubspec.yaml                           # Dependencies
```

---

## 🎨 Design Patterns

### 1. **Service Locator Pattern (Phase 1)**

**Problem:** Service instantiation scattered throughout codebase

**Solution:** Centralized dependency injection using GetIt

**Implementation:**
```dart
// In lib/core/service_locator.dart
final getIt = GetIt.instance;

void setupServiceLocator() async {
  // Register services
  getIt.registerSingleton<AuthService>(
    AuthService(firebaseAuth: FirebaseAuth.instance),
  );
  
  getIt.registerLazySingleton<ChatService>(
    () => ChatService(repository: getIt<ChatRepository>()),
  );
}

// In any widget/provider
final authService = getIt<AuthService>();
```

**Benefits:**
- Single point of service registration
- Easy mocking for testing
- Consistent service lifecycle
- No circular dependencies

### 2. **Repository Pattern**

**Problem:** Data access logic mixed with business logic

**Solution:** Abstract data access behind repository interface

**Implementation:**
```dart
// Abstract interface
abstract class ChatRepository {
  Future<List<Chat>> getChats();
  Future<void> sendMessage(String chatId, Message message);
}

// Implementation
class ChatRepositoryImpl extends ChatRepository {
  final FirestoreChatService _firestoreService;
  
  @override
  Future<List<Chat>> getChats() async {
    return _firestoreService.fetchChats();
  }
}

// Usage in service
class ChatService {
  final ChatRepository repository;
  
  Future<void> loadChats() async {
    final chats = await repository.getChats();
    // Process chats
  }
}
```

**Benefits:**
- Data source independence
- Easy to swap implementations
- Testable with mock repositories
- Single responsibility

### 3. **Validator Pattern (Phase 2)**

**Problem:** Validation logic scattered across multiple widgets

**Solution:** Centralized validator framework

**Implementation:**
```dart
// Abstract validator
abstract class BaseValidator {
  ValidationResult validate(String value);
}

// Concrete implementation
class EmailValidator extends BaseValidator {
  @override
  ValidationResult validate(String value) {
    // Email validation logic
    return ValidationResult(
      isValid: isValid,
      message: errorMessage,
    );
  }
}

// Usage
final result = EmailValidator().validate(email);
if (result.isValid) {
  // Proceed
}
```

**Benefits:**
- Reusable validators
- Consistent validation
- Easy to test
- Centralized rules

### 4. **Provider Pattern (State Management)**

**Problem:** Sharing state across widgets

**Solution:** Provider for state management

**Implementation:**
```dart
// Define provider
final chatProvider = ChangeNotifierProvider((ref) {
  return ChatViewModel(
    repository: ref.watch(chatRepositoryProvider),
  );
});

// Use in UI
Consumer(
  builder: (context, ref, child) {
    final viewModel = ref.watch(chatProvider);
    return ListView(
      children: viewModel.chats.map((chat) => ChatTile(chat)).toList(),
    );
  },
)
```

**Benefits:**
- Reactive state management
- Automatic rebuilds
- Clear dependencies
- Testable logic

### 5. **Model-View Pattern**

**Problem:** Fat controllers/pages with business logic

**Solution:** Separate view models for business logic

**Implementation:**
```dart
// View model (business logic)
class ChatViewModel with FormValidationMixin {
  Future<void> sendMessage(String text) async {
    final result = MessageValidator().validate(text);
    if (result.isValid) {
      await _chatService.sendMessage(text);
    }
  }
}

// Page (UI only)
class ChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      onSubmitted: (text) {
        viewModel.sendMessage(text);
      },
    );
  }
}
```

**Benefits:**
- Separation of concerns
- Easier testing
- Reusable logic
- Cleaner UI code

---

## 🔌 Service Locator Pattern

### Registration Strategy

**Singletons** (Single instance throughout app):
- `AuthService` - Authentication management
- `UserProfileService` - User data
- `NotificationService` - Notifications

**Lazy Singletons** (Created on first use):
- `ChatService` - Chat operations
- `CallService` - Call management
- Repositories - Data access

**Factories** (New instance each time):
- View models
- Temporary utilities

### Setup Process

```dart
// 1. Call in main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const GreenHiveApp());
}

// 2. Registration in service_locator.dart
Future<void> setupServiceLocator() async {
  // Core services
  getIt.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  getIt.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
  
  // Repository layer
  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      firestoreService: getIt<FirestoreChatService>(),
    ),
  );
  
  // Service layer
  getIt.registerLazySingleton<ChatService>(
    () => ChatService(repository: getIt<ChatRepository>()),
  );
}

// 3. Usage anywhere
final chatService = getIt<ChatService>();
```

### Benefits

| Benefit | How It Helps |
|---|---|
| **Centralized** | All services registered in one place |
| **Testable** | Easy to inject mocks |
| **Type-safe** | Dart's type system catches errors |
| **Lazy Loading** | Services created only when needed |
| **No Circular Deps** | Clear dependency graph |

---

## ✅ Validation Framework

### Validators

```
BaseValidator (abstract)
├── EmailValidator
├── PhoneValidator
└── MessageValidator
```

### Usage Tiers

**Tier 1: TextFormField** (Most Common)
```dart
TextFormField(
  validator: ValidatorBuilders.emailValidator,
)
```

**Tier 2: Real-time Validation**
```dart
TextField(
  onChanged: (value) {
    final result = EmailValidator().validate(value);
  },
)
```

**Tier 3: Form Validation**
```dart
final errors = ValidationHelper.validateLoginForm(
  email: email,
  password: password,
);
```

**Tier 4: Manual Validation**
```dart
final result = EmailValidator().validate(email);
if (!result.isValid) {
  print(result.message);
}
```

### Input Sanitization

**9 Sanitization Methods:**

```dart
final sanitizer = InputSanitizer();

// 1. Message sanitization
sanitizer.sanitizeMessage(text)        // Remove extra spaces

// 2. Username sanitization
sanitizer.sanitizeUsername(text)       // Trim and normalize

// 3. Email normalization
sanitizer.sanitizeEmail(text)          // Lowercase + trim

// 4. Phone formatting
sanitizer.sanitizePhone(text)          // Remove non-digits

// 5-6. HTML escaping
sanitizer.escapeHtml(text)             // Prevent XSS
sanitizer.unescapeHtml(text)           // Reverse escaping

// 7-9. Profanity handling
sanitizer.containsProfanity(text)      // Detect
sanitizer.maskProfanity(text)          // Mask with ***

// 10. Search query cleaning
sanitizer.sanitizeSearchQuery(text)    // For search input
```

---

## 🔄 Data Flow

### Chat Message Flow

```
User Types Message
        ↓
TextField onChanged triggers
        ↓
MessageValidator validates
        ↓
InputSanitizer sanitizes
        ↓
ChatViewModel.sendMessage() called
        ↓
ChatService processes message
        ↓
ChatRepository stores data
        ↓
Firestore persists message
        ↓
Cloud Function triggers
        ↓
Recipient receives notification
        ↓
Provider updates UI
        ↓
Message appears in chat
```

### Authentication Flow

```
User Enters Credentials
        ↓
Form validates input
        ↓
AuthService.login() called
        ↓
Firebase Auth authenticates
        ↓
User profile loaded
        ↓
Auth token stored
        ↓
Provider updates state
        ↓
Navigate to main app
```

### Call Flow

```
Initiator clicks "Call"
        ↓
CallService initiates connection
        ↓
Cloud Function notifies recipient
        ↓
Recipient receives notification
        ↓
Recipient accepts
        ↓
WebSocket connection established
        ↓
Video/Audio streams transmitted
        ↓
Call active
```

---

## 🏢 Feature Implementation

### Architecture for Each Feature

```
feature/
├── data/
│   ├── datasources/
│   │   ├── local_datasource.dart    # Local storage
│   │   └── remote_datasource.dart   # API calls
│   └── repositories/
│       └── feature_repository_impl.dart
│
├── domain/
│   ├── entities/
│   │   └── feature_entity.dart       # Data models
│   └── repositories/
│       └── feature_repository.dart   # Abstract interface
│
└── presentation/
    ├── pages/
    │   └── feature_page.dart         # UI screens
    ├── providers/
    │   └── feature_provider.dart     # State
    ├── widgets/
    │   └── feature_widget.dart       # Reusable UI
    └── providers.dart                # Provider definitions
```

### Example: Chat Feature

```
features/chat/
├── data/
│   ├── datasources/
│   │   ├── local_chat_datasource.dart
│   │   └── remote_chat_datasource.dart (Firestore)
│   └── repositories/
│       └── chat_repository_impl.dart
│
├── domain/
│   ├── entities/
│   │   ├── chat_entity.dart
│   │   └── message_entity.dart
│   └── repositories/
│       └── chat_repository.dart (abstract)
│
└── presentation/
    ├── pages/
    │   ├── chat_page.dart
    │   └── chat_conversation_page.dart
    ├── providers/
    │   └── chat_view_model.dart
    └── widgets/
        ├── message_bubble.dart
        ├── chat_input.dart
        └── chat_tile.dart
```

---

## 🔗 Dependency Management

### Dependency Graph

```
App (main.dart)
  ↓
Service Locator (setupServiceLocator)
  ↓
  ├── Firebase Services
  │   ├── FirebaseAuth
  │   ├── FirebaseFirestore
  │   └── FirebaseStorage
  │
  ├── Repository Layer
  │   ├── ChatRepository
  │   ├── UserRepository
  │   └── AuthRepository
  │
  ├── Service Layer
  │   ├── ChatService (uses ChatRepository)
  │   ├── AuthService (uses AuthRepository)
  │   └── UserProfileService
  │
  ├── Validator Layer
  │   ├── EmailValidator
  │   ├── PhoneValidator
  │   └── MessageValidator
  │
  └── UI Layer (Providers/Pages)
      ├── ChatProvider (uses ChatService)
      ├── AuthProvider (uses AuthService)
      └── Pages use Providers
```

### No Circular Dependencies

```
✅ GOOD: Page → Provider → Service → Repository
❌ BAD:  Page → Provider → Repository → Provider
```

---

## 🧪 Testing Strategy

### Unit Testing

```dart
// Test a validator
void main() {
  group('EmailValidator', () {
    final validator = EmailValidator();
    
    test('validates correct email', () {
      final result = validator.validate('user@example.com');
      expect(result.isValid, true);
    });
    
    test('rejects invalid email', () {
      final result = validator.validate('invalid@');
      expect(result.isValid, false);
    });
  });
}
```

### Widget Testing

```dart
void main() {
  group('ChatPage', () {
    testWidgets('displays messages', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(MessageBubble), findsWidgets);
    });
  });
}
```

### Integration Testing

```dart
void main() {
  group('Chat Feature', () {
    testWidgets('send and receive message', (tester) async {
      // Setup
      // Send message
      // Verify received
    });
  });
}
```

### Mock Services

```dart
class MockChatService extends Mock implements ChatService {}

void main() {
  group('ChatProvider', () {
    late MockChatService mockChatService;
    
    setUp(() {
      mockChatService = MockChatService();
      getIt.registerSingleton<ChatService>(mockChatService);
    });
    
    test('loads chats', () async {
      when(mockChatService.loadChats()).thenAnswer((_) async => []);
      // Test
    });
  });
}
```

---

## 🚀 Deployment Architecture

### Build Pipeline

```
Source Code (Git)
        ↓
Flutter Build
        ↓
iOS Build (xcodebuild)    |    Android Build (gradle)
        ↓                 |            ↓
iOS App (ipa)     |    Android App (apk/aab)
        ↓                 |            ↓
App Store Connect |    Google Play Console
        ↓                 |            ↓
iOS App Store     |    Google Play Store
```

### Firebase Deployment

```
Cloud Functions
  ├── callInitiated()
  ├── messageReceived()
  ├── userStatusChanged()
  └── notificationSent()

Firestore Rules
  ├── Collection rules
  ├── Document rules
  └── Field-level security

Storage Rules
  ├── Profile pictures
  ├── Video recordings
  └── Other media
```

### Environment Configuration

```
Development (localhost)
  └── Firebase Emulator Suite

Staging
  └── Firebase Project: greenhive-staging

Production
  └── Firebase Project: greenhive-prod
```

---

## 💬 Communication Protocols

### Real-time Chat

**Protocol:** WebSocket → Cloud Function → Firestore

```
Client A ──────────────────────────┐
                                   ├─→ Cloud Function ─→ Firestore
Client B ──────────────────────────┘
                                   └─→ Notify Client B
```

### Calling

**Protocol:** WebSDP → TURN Server → WebRTC

```
Caller ──────┐
             ├─→ Cloud Function (Signaling) ──┐
Callee ──────┘                                 ├─→ Peer Connection
                                              ↓
                           TURN Server (NAT Traversal)
                                              ↑
                            ├─→ Audio Stream (P2P)
                            └─→ Video Stream (P2P)
```

### Notifications

**Protocol:** FCM → Device

```
Cloud Function ─→ FCM ─→ Firebase Services ─→ Device Notification
```

---

## 📊 Database Schema

### Firestore Collections

```
users/
  └── {userId}
      ├── email: string
      ├── displayName: string
      ├── photoURL: string
      ├── status: string (online/offline)
      ├── createdAt: timestamp
      └── updatedAt: timestamp

chats/
  └── {chatId}
      ├── participants: array
      ├── lastMessage: string
      ├── lastMessageTime: timestamp
      ├── createdAt: timestamp
      └── messages/
          └── {messageId}
              ├── senderId: string
              ├── text: string
              ├── createdAt: timestamp
              └── status: string (sent/delivered/read)

calls/
  └── {callId}
      ├── initiatorId: string
      ├── recipientId: string
      ├── status: string (ringing/active/ended)
      ├── startTime: timestamp
      ├── endTime: timestamp
      └── duration: number
```

---

## 🔐 Security Architecture

### Authentication
- Firebase Auth handles credentials
- JWT tokens for session management
- Refresh token rotation

### Authorization
- Firestore Security Rules enforce access
- Role-based access control
- Field-level encryption where needed

### Data Protection
- Input validation and sanitization
- SQL injection prevention (N/A - using Firestore)
- XSS prevention with HTML escaping
- Rate limiting on Cloud Functions

### Network Security
- HTTPS for all API calls
- TLS 1.2+ for connections
- Certificate pinning (optional)

---

## 🎓 Architecture Principles

### SOLID Principles

| Principle | Implementation |
|---|---|
| **S**ingle Responsibility | Each service has one job |
| **O**pen/Closed | Open for extension, closed for modification |
| **L**iskov Substitution | Repositories can be swapped |
| **I**nterface Segregation | Small, focused interfaces |
| **D**ependency Inversion | Depend on abstractions, not concrete |

### Clean Architecture

```
Domain (Entities, Use Cases)
  ↓
Application (Services, Validators)
  ↓
Presentation (UI, Providers)
  ↓
Infrastructure (Repositories, Data Sources)
```

### DRY (Don't Repeat Yourself)
- Validators are centralized
- Services are reused
- Components are modular
- Mixins for shared logic

---

## 📈 Scalability

### Horizontal Scaling
- Stateless services (can run multiple instances)
- Distributed state via Firebase
- Load balancing via Cloud Functions

### Vertical Scaling
- Lazy service registration
- Efficient database queries
- Image optimization
- Code splitting

### Performance Optimization
- Pagination for large lists
- Caching strategies
- Lazy loading
- Asset compression

---

## 🛠️ Development Workflow

### Adding a New Feature

1. **Define Structure**
   ```
   features/new_feature/
   ├── data/
   ├── domain/
   └── presentation/
   ```

2. **Create Entities**
   - Define data models in `domain/entities/`

3. **Create Repository**
   - Abstract in `domain/repositories/`
   - Implementation in `data/repositories/`

4. **Create Service**
   - Business logic in `services/`
   - Register in `service_locator.dart`

5. **Add Validators** (if needed)
   - Create in `lib/core/validators/`
   - Export in `validators.dart`

6. **Create UI**
   - Pages in `presentation/pages/`
   - Widgets in `presentation/widgets/`
   - Providers in `presentation/providers/`

7. **Add Tests**
   - Unit tests
   - Widget tests
   - Integration tests

### Code Review Checklist

- [ ] Follows architecture layers
- [ ] Uses service locator for dependencies
- [ ] Validates input with validators
- [ ] Sanitizes user input
- [ ] Has error handling
- [ ] Tests included
- [ ] Documentation updated

---

## 🔗 Related Documentation

| Document | Purpose |
|---|---|
| [PHASE_1_SUMMARY.md](PHASE_1_SUMMARY.md) | Service Locator Details |
| [SERVICE_LOCATOR_QUICK_REFERENCE.md](../guides/SERVICE_LOCATOR_QUICK_REFERENCE.md) | Dependency Injection Guide |
| [VALIDATORS_QUICK_REFERENCE.md](VALIDATORS_QUICK_REFERENCE.md) | Validation Framework Guide |
| [PHASE_2_IMPLEMENTATION_COMPLETE.md](PHASE_2_IMPLEMENTATION_COMPLETE.md) | Validators Implementation |
| [CONTRIBUTING.md](../../CONTRIBUTING.md) | Contributing Guidelines |

---

## 📞 Architecture Decision Records (ADR)

### ADR-001: Use GetIt for Dependency Injection
- **Decision:** Use GetIt service locator
- **Rationale:** Type-safe, widely used, minimal setup
- **Status:** Implemented (Phase 1)

### ADR-002: Separate Validation Framework
- **Decision:** Create centralized validators
- **Rationale:** Reusable, consistent, testable
- **Status:** Implemented (Phase 2)

### ADR-003: Repository Pattern
- **Decision:** Abstract data access behind repositories
- **Rationale:** Easy to test, swap implementations
- **Status:** In use

---

## ✅ Checklist: Is Your Code Following Architecture?

- [ ] UI code is only in `pages/` and `widgets/`
- [ ] Business logic is in `services/`
- [ ] Data access is in `repositories/`
- [ ] Services are registered in service locator
- [ ] Input is validated before use
- [ ] Input is sanitized before storage
- [ ] No direct Firestore calls outside repositories
- [ ] No circular dependencies
- [ ] Error handling is present
- [ ] Code is tested

---

## 🎯 Next Steps

### Phase 3 Completion
- [x] Create ARCHITECTURE.md
- [ ] Create CONTRIBUTING.md (in progress)
- [ ] Diagram service layer (in progress)

### Phase 4: Unit Tests
- Create test structure
- Add tests for 3 critical services
- Setup CI/CD

---

**Architecture Version:** 2.0  
**Status:** Production Ready  
**Last Updated:** January 9, 2026  
**Maintained by:** GreenHive Development Team
