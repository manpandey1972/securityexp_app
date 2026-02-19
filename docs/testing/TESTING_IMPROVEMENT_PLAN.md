# Testing Improvement Plan: Path to 60% Coverage

## Current State Analysis

### Test Metrics
| Metric | Current | Target |
|--------|---------|--------|
| **Code Coverage** | 13.4% | 60% |
| **Test Cases** | 880 passing | 80%+ pass rate |
| **Skipped Tests** | 55 | < 20 |
| **Failed Tests** | 4 | 0 |
| **Test Files** | 50 | ~120 |
| **Source Files** | 375 | - |
| **Lines of Code** | 20,701 | - |

### Coverage by Feature Area (Estimated)
| Area | Current Coverage | Priority |
|------|-----------------|----------|
| `core/` | ~50% | High |
| `providers/` | ~60% | Medium |
| `features/support/` | ~45% | Medium |
| `features/admin/` | ~40% | Medium |
| `features/ratings/` | ~35% | Medium |
| `features/calling/` | ~25% | High |
| `features/chat/` | ~15% | **Critical** |
| `features/home/` | ~20% | Medium |
| `features/profile/` | ~10% | Medium |
| `shared/` | ~20% | High |
| `data/` | ~25% | High |
| `utils/` | ~5% | Low |

### Well-Tested Files (>50% coverage)
- ✅ `app_state.dart` - 100%
- ✅ `ticket_status_chip.dart` - 100%
- ✅ `home_state.dart` - 100%
- ✅ `event_bus.dart` - 100%
- ✅ `rating_view_model.dart` - 98%
- ✅ `text_normalizer.dart` - 97%
- ✅ `admin_faq_service.dart` - 96%
- ✅ `call_error_handler.dart` - 95%
- ✅ `admin_skills_service.dart` - 86%
- ✅ `admin_user_service.dart` - 82%

### Critical Gaps (Large files with 0% coverage)
1. `call_history_view_model.dart` - 99 lines
2. `message_bubble.dart` (chat) - 89 lines
3. `app_button_variants.dart` - 88 lines
4. `attachment_picker.dart` - 87 lines
5. `media_upload_service.dart` - 86 lines
6. `shimmer_loading.dart` - 85 lines
7. `skills_service.dart` (profile) - 81 lines
8. `document_message_bubble.dart` - 81 lines
9. `admin_faq_repository.dart` - 81 lines
10. `onboarding_view_model.dart` - 80 lines

---

## Phased Implementation Plan

### Phase 1: Foundation & Quick Wins (Week 1-2)
**Goal: Reach 25% coverage, fix failing tests**

#### 1.1 Fix Failing Tests (Day 1)
- [ ] Fix 4 failing tests (ProfilePictureService singleton issues)
- [ ] Reduce skipped tests by improving mock setup

#### 1.2 Test Infrastructure Improvements (Day 2-3)
```dart
// Create comprehensive mock setup
test/helpers/
├── firebase_mocks.dart      // Firebase Auth, Firestore, Storage mocks
├── service_mocks.dart       // All service mocks with Mockito
├── widget_test_helpers.dart // Common widget test setup
├── test_data_factory.dart   // Factory for test models
└── golden_test_helpers.dart // Golden test utilities
```

#### 1.3 Model & Data Layer Tests (Day 4-7)
Priority files to test:
- [ ] `lib/data/models/models.dart` - Improve from 66% to 90%
- [ ] `lib/data/models/skill.dart` - 0% → 80%
- [ ] `lib/data/models/upload_state.dart` - 0% → 80%
- [ ] `lib/data/models/chat_message_actions.dart` - 0% → 80%

#### 1.4 Core Utilities (Day 8-10)
- [ ] `lib/core/validators/` - Most at 85%+, complete remaining
- [ ] `lib/core/logging/app_logger.dart` - 63% → 80%
- [ ] `lib/core/constants.dart` - 0% → 80%
- [ ] `lib/utils/chat_utils.dart` - 0% → 70%
- [ ] `lib/utils/chat_message_helper.dart` - 0% → 70%

**Expected Coverage After Phase 1: ~25%**

---

### Phase 2: Service Layer Testing (Week 3-4)
**Goal: Reach 40% coverage**

#### 2.1 Shared Services (High Impact)
```
test/services/
├── media_upload_service_test.dart      NEW - 86 lines
├── dialog_service_test.dart            EXISTS - expand
├── media_type_helper_test.dart         NEW - 32 lines
├── pending_notification_handler_test.dart NEW - 68 lines
├── ringtone_service_test.dart          EXISTS - improve
└── media_audio_session_helper_test.dart NEW - 7 lines
```

#### 2.2 Chat Services (Critical Path)
```
test/features/chat/services/
├── chat_media_handler_test.dart        EXISTS - expand
├── chat_media_cache_helper_test.dart   NEW - 74 lines
├── chat_recording_handler_test.dart    NEW - 37 lines
├── user_presence_service_test.dart     NEW - 67 lines
└── chat_page_initializer_test.dart     NEW - 65 lines
```

#### 2.3 Support Services
```
test/features/support/services/
├── faq_service_test.dart               NEW - 69 lines
├── issue_reporter_test.dart            NEW - 34 lines
├── support_validator_test.dart         NEW - 25 lines
└── support_analytics_test.dart         NEW - 37 lines
```

**Expected Coverage After Phase 2: ~40%**

---

### Phase 3: ViewModel & State Management (Week 5-6)
**Goal: Reach 50% coverage**

#### 3.1 ViewModels (Business Logic Testing)
```
test/features/
├── calling/presentation/
│   └── call_history_view_model_test.dart  NEW - 99 lines
├── chat_list/
│   └── chat_list_view_model_test.dart     EXISTS - expand
├── home/presentation/
│   └── home_view_model_test.dart          EXISTS - 68% → 85%
├── onboarding/presentation/
│   └── onboarding_view_model_test.dart    NEW - 80 lines
├── profile/presentation/
│   └── user_profile_view_model_test.dart  NEW
├── support/presentation/
│   ├── ticket_list_view_model_test.dart   NEW - 73 lines
│   └── new_ticket_view_model_test.dart    EXISTS - expand
└── admin/presentation/
    ├── admin_dashboard_view_model_test.dart NEW
    └── admin_users_view_model_test.dart     NEW
```

#### 3.2 State Classes
- [ ] All `*_state.dart` files should have 100% coverage
- [ ] Test all state transitions and edge cases

**Expected Coverage After Phase 3: ~50%**

---

### Phase 4: Repository Layer (Week 7-8)
**Goal: Reach 55% coverage**

#### 4.1 Data Repositories
```
test/data/repositories/
├── user_repository_test.dart           EXISTS - expand
├── chat_message_repository_test.dart   EXISTS - expand
├── expert_repository_test.dart         NEW - 78 lines
└── product_repository_test.dart        NEW - 63 lines
```

#### 4.2 Admin Repositories
```
test/features/admin/data/repositories/
├── admin_faq_repository_test.dart      NEW - 81 lines
├── admin_skill_repository_test.dart    NEW
├── admin_user_repository_test.dart     NEW - 41 lines
└── admin_ticket_repository_test.dart   NEW
```

#### 4.3 Feature Repositories
```
test/features/
├── ratings/data/repositories/
│   └── rating_repository_test.dart     EXISTS - expand
├── support/data/repositories/
│   └── support_repository_test.dart    EXISTS - expand
└── calling/infrastructure/repositories/
    ├── firebase_call_repository_test.dart NEW
    └── voip_token_repository_test.dart    NEW - 42 lines
```

**Expected Coverage After Phase 4: ~55%**

---

### Phase 5: Widget Testing (Week 9-10)
**Goal: Reach 60% coverage**

#### 5.1 High-Impact Shared Widgets
```
test/widgets/
├── app_button_variants_test.dart       NEW - 88 lines
├── shimmer_loading_test.dart           NEW - 85 lines
├── empty_state_widget_test.dart        NEW - 35 lines
├── profanity_filtered_text_field_test.dart NEW - 63 lines
└── avatar_widget_test.dart             EXISTS - complete
```

#### 5.2 Chat Widgets (Critical)
```
test/features/chat/widgets/
├── message_bubble_test.dart            NEW - 89 lines
├── document_message_bubble_test.dart   NEW - 81 lines
├── attachment_menu_sheet_test.dart     NEW - 35 lines
├── uploading_message_test.dart         NEW - 35 lines
├── linkified_text_test.dart            NEW - 33 lines
└── swipeable_message_test.dart         NEW - 64 lines
```

#### 5.3 Support Widgets
```
test/features/support/widgets/
├── attachment_picker_test.dart         NEW - 87 lines
├── message_bubble_test.dart            EXISTS - 58% → 80%
├── ticket_card_test.dart               EXISTS - 89% → 95%
└── satisfaction_rating_dialog_test.dart NEW - 64 lines
```

#### 5.4 Rating Widgets
```
test/features/ratings/widgets/
├── star_rating_input_test.dart         NEW - 36 lines
├── expert_rating_summary_test.dart     NEW - 80 lines
└── rating_card_test.dart               NEW - 72 lines
```

**Expected Coverage After Phase 5: ~60%**

---

## Test File Templates

### Service Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([DependencyClass])
import 'service_name_test.mocks.dart';

void main() {
  late ServiceName service;
  late MockDependencyClass mockDependency;

  setUp(() {
    mockDependency = MockDependencyClass();
    service = ServiceName(dependency: mockDependency);
  });

  group('ServiceName', () {
    group('methodName', () {
      test('should return expected result when condition', () async {
        // Arrange
        when(mockDependency.method()).thenReturn(expectedValue);
        
        // Act
        final result = await service.methodName();
        
        // Assert
        expect(result, expectedValue);
        verify(mockDependency.method()).called(1);
      });

      test('should handle error gracefully', () async {
        // Arrange
        when(mockDependency.method()).thenThrow(Exception('error'));
        
        // Act & Assert
        expect(() => service.methodName(), throwsException);
      });
    });
  });
}
```

### ViewModel Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([ServiceClass])
import 'view_model_test.mocks.dart';

void main() {
  late ViewModelName viewModel;
  late MockServiceClass mockService;

  setUp(() {
    mockService = MockServiceClass();
    viewModel = ViewModelName(service: mockService);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('ViewModelName', () {
    test('initial state should be correct', () {
      expect(viewModel.state.isLoading, false);
      expect(viewModel.state.error, isNull);
    });

    group('loadData', () {
      test('should update state when successful', () async {
        when(mockService.getData()).thenAnswer((_) async => testData);
        
        await viewModel.loadData();
        
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.data, testData);
      });

      test('should handle errors', () async {
        when(mockService.getData()).thenThrow(Exception('error'));
        
        await viewModel.loadData();
        
        expect(viewModel.state.error, isNotNull);
      });
    });
  });
}
```

### Widget Test Template
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createWidgetUnderTest({String? param}) {
    return MaterialApp(
      home: Scaffold(
        body: WidgetName(param: param),
      ),
    );
  }

  group('WidgetName', () {
    testWidgets('should render correctly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      expect(find.byType(WidgetName), findsOneWidget);
    });

    testWidgets('should display text when provided', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(param: 'test'));
      
      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('should handle tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: WidgetName(onTap: () => tapped = true),
        ),
      );
      
      await tester.tap(find.byType(WidgetName));
      await tester.pump();
      
      expect(tapped, true);
    });
  });
}
```

---

## Mock Infrastructure To Create

### 1. Firebase Mocks (`test/helpers/firebase_mocks.dart`)
```dart
// Mock classes for Firebase services
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockFirebaseStorage extends Mock implements FirebaseStorage {}
class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}
class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

// Setup helpers
void setupFirebaseMocks() {
  // Register all Firebase mocks with service locator
}
```

### 2. Service Mocks (`test/helpers/service_mocks.dart`)
```dart
@GenerateMocks([
  RoleService,
  UserRepository,
  ExpertRepository,
  ChatService,
  CallService,
  NotificationService,
  UploadManager,
  MediaCacheService,
  ProfanityFilterService,
  SkillsService,
  // ... all services
])
library service_mocks;
```

### 3. Test Data Factory (`test/helpers/test_data_factory.dart`)
```dart
class TestDataFactory {
  static User createUser({...}) => User(...);
  static ChatMessage createMessage({...}) => ChatMessage(...);
  static SupportTicket createTicket({...}) => SupportTicket(...);
  static Expert createExpert({...}) => Expert(...);
  // ... factory methods for all models
}
```

---

## CI/CD Integration

### GitHub Actions Workflow
```yaml
name: Test & Coverage

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - name: Check coverage threshold
        run: |
          COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | cut -d':' -f2 | cut -d'%' -f1 | tr -d ' ')
          if (( $(echo "$COVERAGE < 60" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 60% threshold"
            exit 1
          fi
      - uses: codecov/codecov-action@v3
```

---

## Success Metrics

### Weekly Checkpoints
| Week | Target Coverage | Tests Added | Milestone |
|------|-----------------|-------------|-----------|
| 1 | 18% | ~50 | Fix failing tests, model tests |
| 2 | 25% | ~100 | Core utilities complete |
| 3 | 32% | ~150 | Shared services tested |
| 4 | 40% | ~200 | Chat/Support services done |
| 5 | 45% | ~250 | ViewModels 80% covered |
| 6 | 50% | ~300 | State management complete |
| 7 | 53% | ~350 | Data repositories done |
| 8 | 55% | ~400 | Admin repositories done |
| 9 | 58% | ~450 | Shared widgets tested |
| 10 | 60% | ~500 | Chat widgets complete |

### Quality Gates
- **Pass Rate**: > 95% (zero failing tests)
- **Skipped Tests**: < 20
- **Coverage per PR**: Must not decrease
- **New Code Coverage**: > 80% for new features

---

## Priority Matrix

### Highest Priority (Critical Business Logic)
1. **Chat messaging flow** - Core feature
2. **Calling services** - Real-time critical
3. **Payment/Rating flows** - Revenue impact
4. **Authentication** - Security critical

### High Priority (User-Facing Features)
1. **Support ticket system**
2. **Admin dashboard**
3. **User profile management**
4. **Expert search/discovery**

### Medium Priority (Supporting Features)
1. **Onboarding flow**
2. **Notification handling**
3. **Media upload/caching**
4. **Analytics tracking**

### Lower Priority (UI/Polish)
1. **Animations/transitions**
2. **Theme variations**
3. **Loading states**
4. **Empty states**

---

## Estimated Effort

| Phase | Duration | New Tests | Lines Covered |
|-------|----------|-----------|---------------|
| Phase 1 | 2 weeks | ~200 | +2,500 |
| Phase 2 | 2 weeks | ~250 | +3,000 |
| Phase 3 | 2 weeks | ~200 | +2,000 |
| Phase 4 | 2 weeks | ~150 | +1,500 |
| Phase 5 | 2 weeks | ~200 | +2,500 |
| **Total** | **10 weeks** | **~1,000** | **+11,500** |

This would bring coverage from **2,777 lines (13.4%)** to approximately **14,277 lines (69%)**
