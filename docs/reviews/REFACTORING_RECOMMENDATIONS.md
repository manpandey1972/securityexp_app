# GreenHive App - Refactoring Recommendations

**Review Date:** January 21, 2026  
**Reviewer:** Code Review Agent  
**Codebase Version:** Current Production

---

## 📊 Executive Summary

| Category | Grade | Key Finding |
|----------|-------|-------------|
| **Architecture** | C+ | Inconsistent feature structures, scattered locations |
| **Code Organization** | C | Pages/widgets duplicated across 3+ locations |
| **Design Patterns** | B- | ViewModels correct but legacy patterns remain |
| **Service Layer** | C+ | 31 services in lib/services/ - many belong in features |

---

## 🔴 High Priority Recommendations

### 1. Consolidate Page Locations

**Problem:** Pages are scattered between `lib/pages/` and `lib/features/*/pages/`

| Current Location | Move To |
|-----------------|---------|
| `lib/pages/chat_page.dart` | `features/chat_list/pages/` |
| `lib/pages/chat_conversation_page.dart` | `features/chat/pages/` |
| `lib/pages/home_page.dart` | `features/home/pages/` |
| `lib/pages/phone_auth_screen.dart` | `features/phone_auth/pages/` |
| `lib/pages/user_onboarding_page.dart` | `features/onboarding/pages/` |
| `lib/pages/user_profile_page.dart` | `features/profile/pages/` |
| `lib/pages/splash_screen.dart` | `features/authentication/pages/` |
| `lib/pages/expert_details_page.dart` | `features/home/pages/` |
| `lib/pages/product_details_page.dart` | `features/home/pages/` |
| `lib/pages/media_manager_page.dart` | `features/chat/pages/` |
| `lib/pages/skill_selection_page.dart` | `features/profile/pages/` |

**Impact:** Improves code discoverability and maintains feature encapsulation.

---

### 2. Standardize Feature Module Structure

**Problem:** Each feature has a different folder structure, making navigation difficult.

**Current State:**

| Feature | Structure | Completeness |
|---------|-----------|--------------|
| `calling` | domain/, infrastructure/, managers/, models/, pages/, presentation/, services/, widgets/ | ✅ Complete |
| `chat` | pages/ (empty), presentation/, services/ (empty), widgets/ (empty) | ❌ Incomplete |
| `chat_list` | presentation/ only | ❌ Minimal |
| `home` | presentation/ only | ❌ Minimal |
| `profile` | pages/ (empty), presentation/, services/ (empty), widgets/ (empty) | ❌ Incomplete |
| `phone_auth` | presentation/ only | ❌ Minimal |
| `onboarding` | presentation/ only | ❌ Minimal |
| `authentication` | pages/ (empty) only | ❌ Stub only |

**Recommended Standard Structure:**

```
features/{feature_name}/
├── pages/           # UI pages/screens
├── presentation/
│   ├── state/       # State classes (immutable)
│   └── view_models/ # ViewModels (ChangeNotifier)
├── services/        # Feature-specific services
├── widgets/         # Feature-specific widgets
└── constants/       # Feature-specific constants (optional)
```

---

### 3. Move Chat Services to Feature Module

**Problem:** 31 services in `lib/services/` - many are chat-specific and should move.

**Services to move to `features/chat/services/`:**

- `audio_recording_manager.dart`
- `chat_media_cache_helper.dart`
- `chat_media_handler.dart`
- `chat_page_initializer.dart`
- `chat_page_service.dart`
- `chat_recording_handler.dart`
- `chat_scroll_handler.dart`
- `chat_stream_service.dart`
- `firestore_chat_service.dart`
- `message_send_handler.dart`
- `reply_management_service.dart`
- `unread_messages_service.dart`
- `user_presence_service.dart`

**Services to move to `features/profile/services/`:**

- `profile_picture_service.dart`
- `skills_service.dart`
- `biometric_auth_service.dart`

**Services to move to `features/home/services/`:**

- `home_data_loader.dart`

**Services to keep in `lib/shared/services/` (cross-cutting):**

- `firebase_messaging_service.dart`
- `notification_service.dart`
- `error_handler.dart`
- `event_bus.dart`
- `dialog_service.dart`
- `media_cache_service.dart`
- `media_download_service.dart`
- `media_upload_service.dart`
- `upload_manager.dart`

---

### 4. Consolidate Widget Locations

**Problem:** Widgets are scattered across three locations with overlapping purposes.

| Current Location | Widget Count | Action |
|-----------------|--------------|--------|
| `lib/widgets/chat/` | 17 files | Move to `features/chat/widgets/` |
| `lib/widgets/call/` | 8 files | Merge into `features/calling/widgets/` |
| `lib/widgets/` (root) | 15 files | Move generic to `lib/shared/widgets/` |

**Specific widget movements:**

```
lib/widgets/chat/*                    → features/chat/widgets/
lib/widgets/call/*                    → features/calling/widgets/
lib/widgets/expert_card.dart          → features/home/widgets/
lib/widgets/experts_list_tab.dart     → features/home/widgets/
lib/widgets/products_tab.dart         → features/home/widgets/
lib/widgets/chats_tab.dart            → features/chat_list/widgets/
lib/widgets/calls_tab.dart            → features/calling/widgets/
lib/widgets/profile_picture_widget.dart → lib/shared/widgets/
lib/widgets/avatar_widget.dart        → lib/shared/widgets/
lib/widgets/success_animation.dart    → lib/shared/widgets/
lib/widgets/global_upload_indicator.dart → lib/shared/widgets/
lib/widgets/profile_menu.dart         → features/profile/widgets/
```

---

## 🟡 Medium Priority Recommendations

### 5. Convert Factory Singletons to GetIt DI

**Problem:** Some services use factory constructors for singletons, bypassing DI container.

**Affected files:**

| File | Current Pattern |
|------|-----------------|
| `lib/shared/services/user_profile_service.dart` | Factory singleton |
| `lib/services/profile_picture_service.dart` | Factory singleton |
| `lib/services/media_cache_service.dart` | Factory singleton |
| `lib/services/unread_messages_service.dart` | Factory singleton |
| `lib/services/upload_manager.dart` | Factory singleton |

**Current (problematic):**
```dart
static final UserProfileService _instance = UserProfileService._internal();
factory UserProfileService() => _instance;
```

**Recommended:**
```dart
// In service_locator.dart
sl.registerLazySingleton<UserProfileService>(() => UserProfileService());

// Usage
final service = sl<UserProfileService>();
```

**Impact:** Enables proper mocking in tests, consistent DI pattern.

---

### 6. Deprecate Legacy ChatState Provider

**Problem:** Old `ChatState` class in `lib/providers/` (237 lines) coexists with new ViewModel pattern.

**Current state:**
- Legacy: `lib/providers/chat_state.dart`
- Modern: `lib/features/chat/presentation/view_models/chat_conversation_view_model.dart`
- Modern: `lib/features/chat_list/presentation/view_models/chat_list_view_model.dart`

**Migration steps:**
1. Identify all usages of `ChatState` via `context.watch<ChatState>()`
2. Replace with appropriate ViewModel
3. Remove `ChatState` from `provider_setup.dart`
4. Delete `lib/providers/chat_state.dart`

---

### 7. Remove Business Logic from Pages

**Problem:** Some pages contain direct repository access and business logic.

**Affected files:**

| File | Issue |
|------|-------|
| `lib/pages/user_profile_page.dart` | Direct `UserRepository` access |
| `lib/pages/splash_screen.dart` | Direct `BiometricAuthService` and `UserRepository` access |
| `lib/pages/user_onboarding_page.dart` | Business logic in page methods |

**Recommended pattern:**
```dart
// Page should only do:
final viewModel = context.watch<UserProfileViewModel>();

// All business logic in ViewModel:
class UserProfileViewModel extends ChangeNotifier {
  final UserRepository _userRepository;
  // ... business logic here
}
```

---

### 8. Create Shared Frosted Glass Widget

**Problem:** Frosted glass effect implemented in 3 places with duplicate code.

**Current locations:**
- `lib/pages/home_page.dart` - AppBar and BottomNav
- `lib/widgets/experts_list_tab.dart` - Search bar

**Recommended: Create reusable widget**

```dart
// lib/shared/widgets/frosted_container.dart
class FrostedContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;
  final double blurSigma;
  final double backgroundOpacity;
  
  const FrostedContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.blurSigma = 15,
    this.backgroundOpacity = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surface.withValues(alpha: backgroundOpacity),
                AppColors.surface.withValues(alpha: backgroundOpacity - 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
```

---

## 🟢 Low Priority Recommendations

### 9. Standardize Page Naming Convention

**Problem:** Mix of "Screen" and "Page" suffixes.

| Current | Recommended |
|---------|-------------|
| `PhoneAuthScreen` | `PhoneAuthPage` |
| `SplashScreen` | `SplashPage` |

**Standard:** Use "Page" suffix for all navigation destinations.

---

### 10. Consolidate Constants Locations

**Problem:** Constants exist in multiple locations.

| Current Location | Action |
|-----------------|--------|
| `lib/constants/` | Move to `lib/core/constants/` |
| `lib/pages/constants/` | Move to respective feature constants |
| `lib/features/calling/presentation/constants/` | ✅ Keep (correct location) |

---

### 11. Clean Up Unused Imports

**Files with potential unused `dart:ui` imports:**
- `lib/widgets/experts_list_tab.dart`
- `lib/pages/home_page.dart`
- `lib/widgets/chat/message_bubble.dart`

**Action:** Run `dart analyze` and fix all unused import warnings.

---

## 📁 Recommended Final Structure

```
lib/
├── core/                         # Framework-level code
│   ├── config/                   # App configuration
│   ├── constants/                # Global constants
│   ├── di/                       # Dependency injection setup
│   ├── errors/                   # Error handling
│   ├── logging/                  # Logging utilities
│   ├── utils/                    # Core utilities
│   └── validators/               # Input validators
│
├── data/                         # Shared data layer
│   ├── models/                   # Data models
│   └── repositories/             # Shared repositories
│
├── features/                     # Feature modules
│   ├── authentication/
│   │   ├── pages/
│   │   ├── presentation/
│   │   │   ├── state/
│   │   │   └── view_models/
│   │   └── services/
│   │
│   ├── calling/                  # ✅ Well-structured (use as template)
│   │   ├── domain/
│   │   ├── infrastructure/
│   │   ├── managers/
│   │   ├── models/
│   │   ├── pages/
│   │   ├── presentation/
│   │   ├── services/
│   │   └── widgets/
│   │
│   ├── chat/
│   │   ├── pages/
│   │   ├── presentation/
│   │   ├── services/             # Move from lib/services/
│   │   └── widgets/              # Move from lib/widgets/chat/
│   │
│   ├── chat_list/
│   │   ├── pages/
│   │   ├── presentation/
│   │   └── widgets/
│   │
│   ├── home/
│   │   ├── pages/
│   │   ├── presentation/
│   │   ├── services/
│   │   └── widgets/
│   │
│   ├── onboarding/
│   │   ├── pages/
│   │   ├── presentation/
│   │   └── widgets/
│   │
│   ├── phone_auth/
│   │   ├── pages/
│   │   ├── presentation/
│   │   └── widgets/
│   │
│   └── profile/
│       ├── pages/
│       ├── presentation/
│       ├── services/
│       └── widgets/
│
├── shared/                       # Shared utilities
│   ├── animations/               # Animation utilities
│   ├── services/                 # Cross-cutting services
│   ├── themes/                   # App theming
│   └── widgets/                  # Reusable widgets
│
├── firebase_options.dart
└── main.dart
```

---

## 🗓️ Implementation Roadmap

### Phase 1: Quick Wins (1-2 days)
- [ ] Create `FrostedContainer` shared widget
- [ ] Standardize page naming (Screen → Page)
- [ ] Clean up unused imports

### Phase 2: Widget Consolidation (2-3 days)
- [ ] Move `lib/widgets/chat/*` → `features/chat/widgets/`
- [ ] Merge `lib/widgets/call/*` → `features/calling/widgets/`
- [ ] Move generic widgets to `lib/shared/widgets/`
- [ ] Delete empty `lib/widgets/` folder

### Phase 3: Page Migration (3-4 days)
- [ ] Move all pages from `lib/pages/` to feature folders
- [ ] Update all import statements
- [ ] Delete empty `lib/pages/` folder

### Phase 4: Service Reorganization (4-5 days)
- [ ] Move chat services to `features/chat/services/`
- [ ] Move profile services to `features/profile/services/`
- [ ] Convert factory singletons to GetIt DI
- [ ] Update service_locator.dart registrations

### Phase 5: Legacy Cleanup (2-3 days)
- [ ] Migrate ChatState usages to ViewModels
- [ ] Remove business logic from pages
- [ ] Delete deprecated files

---

## 📝 Migration Script Template

For moving files and updating imports:

```bash
# Find all imports of a file
grep -r "import 'package:greenhive_app/pages/chat_page.dart'" lib/

# After moving, use IDE refactoring or:
find lib -name "*.dart" -exec sed -i '' \
  's|package:greenhive_app/pages/chat_page.dart|package:greenhive_app/features/chat_list/pages/chat_page.dart|g' {} \;
```

---

## ✅ Definition of Done

Each phase is complete when:
1. All files moved to correct locations
2. All imports updated and verified
3. `flutter analyze` passes with no errors
4. App builds and runs successfully
5. All tests pass

---

*This document should be updated as refactoring progresses.*
