# GreenHive App — Codebase Review Findings & Execution Plan

**Date:** February 15, 2026
**Scope:** Architecture, Performance, Security, Quality, Maintainability, Standardization
**Codebase:** 378 source files, 94 test files, 47 dependencies

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Findings](#1-architecture)
3. [Security Findings](#2-security)
4. [Performance Findings](#3-performance)
5. [Quality Findings](#4-quality)
6. [Maintainability Findings](#5-maintainability)
7. [Standardization Findings](#6-standardization)
8. [Phased Execution Plan](#phased-execution-plan)

---

## Executive Summary

The codebase is in **good working condition** — 1844 tests pass, iOS builds succeed, CI/CD is operational, and the app ships. The architecture follows MVVM with Provider across most features and uses GetIt for dependency injection. Firestore security rules have a solid foundation with role-based access control.

However, the review identified **42 findings** across 6 categories, with **6 high-severity security items**, **8 architecture inconsistencies**, and significant test coverage gaps (25% test-to-source ratio). The findings are organized by severity and grouped into a 4-phase execution plan.

| Category | Critical | High | Medium | Low |
|---|---|---|---|---|
| Security | 0 | 6 | 4 | 2 |
| Architecture | 0 | 3 | 5 | 0 |
| Quality | 0 | 3 | 4 | 1 |
| Performance | 0 | 0 | 2 | 1 |
| Maintainability | 0 | 1 | 4 | 2 |
| Standardization | 0 | 0 | 3 | 1 |

---

## 1. Architecture

### A-1. Inconsistent feature architecture (HIGH)

Features use 4 different patterns. No single standard architecture is enforced.

| Pattern | Features |
|---|---|
| MVVM (ChangeNotifier + immutable State) | home, chat, chat_list, onboarding, phone_auth, profile, support, admin, ratings |
| DDD (domain/infrastructure + MVVM) | calling (history only) |
| StatefulWidget + Controller | calling (call page) |
| No architecture (bare page) | authentication |

**Impact:** Onboarding new developers is harder. Code reviews lack a reference pattern.
**Recommendation:** Standardize on MVVM for all features. Document the canonical feature structure in CONTRIBUTING.md.

### A-2. No use-case / interactor layer (HIGH)

Business logic lives in providers and services with no separation between orchestration and data access:
- `AuthState` (provider) orchestrates 4 service initializations, FCM/VoIP token lifecycle, and cleanup
- `UserRepository.deleteAccount()` contains 40+ lines of multi-step cleanup logic (FCM, VoIP, presence, cache, Firestore, sign out) that belongs in a use-case
- `ChatPageService` takes `BuildContext` and shows dialogs/snackbars from the service layer

**Impact:** Business logic is untestable without widget/provider context. Cleanup sequences are duplicated (AuthState.signOut and UserRepository.deleteAccount).

### A-3. Parallel error handling strategies (HIGH)

Three coexisting error handling approaches with no guidance on which to use:
1. `ErrorHandler.handle()` / `.executeAsync()` / `.executeVoid()` / `.handleSync()` — 4 methods for similar operations
2. `Result<T>` sealed type in `lib/utils/result.dart` — clean functional approach but rarely used
3. `CallError` hierarchy in `lib/core/errors/call_errors.dart` — domain-specific, well-designed

**Impact:** Mixed usage within the same class (e.g., `UserRepository` uses both `handle` and `executeVoid`). Developers choose arbitrarily.

### A-4. Misplaced code across module boundaries (MEDIUM)

| File | Current Location | Should Be |
|---|---|---|
| `chat_dialog_helper.dart`, `chat_message_helper.dart`, `chat_navigation_helper.dart`, `chat_permission_helper.dart`, `chat_utils.dart` | `lib/utils/` | `lib/features/chat/utils/` |
| `admin_section_wrapper.dart` | `lib/shared/widgets/` | `lib/features/admin/widgets/` |
| `livekit_token_service.dart` | `lib/shared/services/` | `lib/features/calling/services/` |

### A-5. God file — models.dart (MEDIUM)

`lib/data/models/models.dart` is 475 lines containing 6 model classes (`User`, `Message`, `Room`, `Product`, `Call`, `IceCandidate`) + 1 enum. `User` alone is ~180 lines.

**Recommendation:** Split into individual files per model under `lib/data/models/`.

### A-6. Repository interface leaks Firestore types (MEDIUM)

`IChatMessageRepository` pagination methods return `(List<Message>, DocumentSnapshot<Map<String, dynamic>>?)` — the Firestore `DocumentSnapshot` cursor leaks implementation into the interface, making non-Firestore backends impossible.

### A-7. Direct Firebase access from UI layer (MEDIUM)

`FirebaseAuth.instance` / `sl<FirebaseAuth>()` accessed directly in 6+ page/widget files:
- `home_page.dart`, `chat_page.dart`, `call_history_page.dart`, `user_onboarding_page.dart`, `splash_screen.dart`, `chat_message_list_item.dart`

### A-8. Empty/dead structures (MEDIUM)

- `lib/features/calling/managers/` — empty directory
- `lib/features/authentication/` — single splash_screen.dart, no services or architecture
- `CallProvider` enum has only one value (`livekit`), `_parseProvider()` always returns it
- `FirestoreChatService` — deprecated but still present

---

## 2. Security

### S-1. Firestore: active_calls readable by ANY authenticated user (HIGH)

```
// firestore.rules L181
match /active_calls/{callId} {
  allow read: if isAuthenticated();
```

Any logged-in user can read **all** active call documents (caller_id, callee_id, metadata). Should restrict reads to call participants: `resource.data.caller_id == getUserId() || resource.data.callee_id == getUserId()`.

### S-2. Firestore: ICE candidates writable by ANY authenticated user (HIGH)

```
// firestore.rules L193, L261
match /ice_candidates/{candidateId} {
  allow create: if isAuthenticated();
```

In both `active_calls` and `livekit_rooms`, any authenticated user can inject ICE candidates into **any** call. This enables potential call interception.

**Fix:** `allow create: if isAuthenticated() && isCallParticipant(callId);`

### S-3. LiveKit URL uses unencrypted WebSocket (HIGH)

`lib/core/config/remote_config_service.dart` L96 defaults to `ws://136.119.245.234:7880` — plain WebSocket to a bare IP with no TLS. All call signaling data is transmitted unencrypted if Remote Config fails to load.

**Fix:** Use `wss://` with a domain name and valid TLS certificate.

### S-4. CI/CD Node version mismatch (HIGH)

CI deploy step uses Node 18 but `functions/package.json` specifies `"engines": {"node": "22"}`. Functions may be deployed with wrong runtime, leading to unexpected behavior.

### S-5. Blanket `use_build_context_synchronously: ignore` (HIGH)

`analysis_options.yaml` suppresses this rule globally. This hides real bugs where `BuildContext` is used after async gaps when the widget is already unmounted, causing crashes.

**Fix:** Remove the global suppression. Add `// ignore_for_file:` only in files that genuinely need it.

### S-6. Storage: group_media has no membership check (HIGH)

```
// storage.rules L56-63
match /group_media/{groupId}/{allPaths=**} {
  allow read, write: if request.auth != null;
```

Any authenticated user can read/write/delete any group's media files.

### S-7. Firestore rules: expensive reads per request (MEDIUM)

`isAdmin()`, `isSupport()`, `isExpert()` each call `get()` which is a billed Firestore read. Rules with multiple role checks (e.g., `isAdmin() || isSupport() || isSuperAdmin()`) can incur 3+ reads per request, adding latency and cost.

### S-8. TURN credential exposure (MEDIUM)

`RemoteConfigService` getters for `turnUsername` and `turnCredential` expose raw strings. While defaults are empty (good), the values from Remote Config are not redacted in any log path that might reference them.

### S-9. Storage: support attachments readable by any user (MEDIUM)

Any authenticated user can read and delete support ticket attachments at the storage path level. Should restrict to ticket owner + support staff.

### S-10. User.getProfilePictureUrl hardcoded bucket (MEDIUM)

`lib/data/models/models.dart` L394 has hardcoded `greenhive-service.firebasestorage.app` as default Firebase Storage bucket. Should come from config.

### S-11. No auth emulator in firebase.json (LOW)

Emulators configured for functions, firestore, database, storage — but **no auth emulator**. Local testing hits production Firebase Auth.

### S-12. FAQs allow unauthenticated reads (LOW)

`allow read: if true` on FAQs collection — intentional for public help content but worth noting for data classification.

---

## 3. Performance

### P-1. RoleService.hasPermission() hits Firestore on every call (MEDIUM)

`lib/core/auth/role_service.dart` L163 fetches the user document on **every** permission check with no caching. Multiple rapid permission checks in a single screen render will each hit Firestore independently.

**Fix:** Cache the role/permission data with a TTL or use the existing stream subscription.

### P-2. RemoteConfigService creates new default map on every fallback (MEDIUM)

`_getDefaultValues()` creates a new `Map<String, dynamic>` on each call. Should be cached as a static const or lazy field.

### P-3. AnalyticsRouteObserver re-executes route builder (LOW)

`analytics_route_observer.dart` L106 calls `route.builder(route.navigator!.context)` to infer screen name from widget type. This re-executes the builder potentially causing side effects.

---

## 4. Quality

### Q-1. Test coverage: 25% test-to-source ratio (HIGH)

94 test files covering 378 source files. Key features with **zero** tests:
- `authentication` — auth flow completely untested
- `phone_auth` — phone verification untested

`lib/shared/` (19 services, 23 widgets, 18 theme files) has **no dedicated test directory**.

### Q-2. CI pipeline narrowly scoped (HIGH)

- `service-tests` job hardcodes 3 specific test file paths — won't pick up new service tests
- Cloud Functions tests not included in CI pipeline
- No Firestore/Storage rules testing
- No integration or E2E tests

### Q-3. flutter_webrtc dependency possibly unused (HIGH)

`flutter_webrtc: ^1.2.1` remains in pubspec.yaml after the WebRTC provider removal. If only LiveKit handles WebRTC now, this is dead weight adding to binary size and build times.

**Action:** Verify no remaining imports, remove if unused.

### Q-4. Syncfusion licensing (MEDIUM)

`syncfusion_flutter_pdfviewer: ^32.1.25` requires a commercial license for revenue-generating apps. Verify licensing compliance.

### Q-5. Deprecated analysis rule suppressions (MEDIUM)

`deprecated_member_use: ignore` blanket suppression hides all deprecation warnings across the codebase. As Flutter evolves, deprecated APIs won't surface during development.

### Q-6. ErrorHandler.executeMultiple runs sequentially (MEDIUM)

Named "parallel" in docs but uses a sequential `for` loop. Misleading API.

### Q-7. CallErrorHandler double snackbar (MEDIUM)

`handleError` shows a snackbar at L41, then `_handleRecoverableError` shows another at L60 for `CallNetworkError`. User sees duplicate error messages.

### Q-8. ErrorHandler._parseError uses string matching (LOW)

Firebase error classification relies on `contains('Permission denied')`, `contains('network')` — brittle and locale-dependent. Should use Firebase error codes.

---

## 5. Maintainability

### M-1. Duplicate cleanup sequences (HIGH)

Near-identical cleanup logic exists in two places:
- `AuthState.signOut()` (lib/providers/auth_provider.dart L229): cleans up UserCacheService, UserPresenceService, FCM, VoIP, photo backup, then signs out
- `UserRepository.deleteAccount()` (lib/data/repositories/user/user_repository.dart L33): cleans up FCM, VoIP, presence, cache, deletes account

Adding a new cleanup step requires updating both locations. This is a bug waiting to happen.

**Fix:** Extract into a single `AccountCleanupService`.

### M-2. Theme file proliferation (MEDIUM)

5 theme-related files with unclear canonical source:
- `app_theme.dart` (748 lines)
- `app_theme_dark.dart`
- `app_theme_refactored.dart` ← incomplete migration?
- `dark_theme.dart`
- `light_theme.dart`

Plus duplicate definitions: `app_shadows.dart` AND `theme_shadows.dart`.

### M-3. EventBus supports only one event (MEDIUM)

`lib/shared/services/event_bus.dart` — 20 lines, only `onProfileUpdated`. No generic event dispatching. Will need refactoring for any future cross-feature communication.

### M-4. Three serialization naming patterns (MEDIUM)

| Pattern | Models using it |
|---|---|
| `fromJson()` / `toJson()` | Message, User, Product, Call |
| `fromFirestore()` / `toMap()` | Skill |
| `fromMap()` / `toMap()` | CallLog, CallSession |

### M-5. No `==`/`hashCode` on data models (MEDIUM)

No model in `models.dart` overrides `==` or `hashCode`. Equality checks use reference equality. List operations like `contains()`, `Set` deduplication, and widget rebuilds (`didUpdateWidget`) won't behave correctly.

**Fix:** Add `Equatable` mixin or manual overrides to key models.

### M-6. Admin duplicate page file (LOW)

`admin_ticket_detail_page.dart` AND `admin_ticket_detail_page_refactored.dart` exist side-by-side — dead/duplicate code.

### M-7. success_animation_example.dart in production (LOW)

Example file in `lib/shared/widgets/` — should be in `example/` or removed.

---

## 6. Standardization

### ST-1. AppStrings used by only 2 files (MEDIUM)

`lib/constants/app_strings.dart` has 146 lines of organized string constants, but only `features/phone_auth/` uses them. All other features use hardcoded inline strings for SnackBars, dialog titles, and error messages. No i18n foundation.

### ST-2. Three sources of spacing/padding constants (MEDIUM)

The same spacing values are defined in three places:
- `AppTheme.spacing16` in `lib/shared/themes/app_theme.dart`
- `AppSpacing.spacing16` in `lib/shared/themes/app_spacing.dart`
- `UIConstants.mediumPadding = 16.0` in `lib/core/constants.dart`

Widget code uses a mix of all three.

### ST-3. Inconsistent validator API patterns (MEDIUM)

Two validator APIs coexist:
- **OOP pattern**: `BaseValidator` subclasses with `ValidationResult` (email, phone, message validators)
- **Static pattern**: `DisplayNameValidator.validate()` and `PIIValidator.detectPII()` returning `String?`

Both are in `lib/core/validators/`. The barrel export `validators.dart` doesn't export the static validators.

### ST-4. Navigation is fully imperative (LOW)

All features use `Navigator.of(context).push(MaterialPageRoute(...))`. No named routes, no router package (go_router, auto_route). Route handling in `main.dart onGenerateRoute` is a large if/else chain.

---

## Phased Execution Plan

### Phase 1: Security Hardening (1-2 weeks)

**Goal:** Fix all HIGH severity security issues. Zero code architecture changes — rules and config only.

| # | Task | Finding | Effort | Risk if Skipped |
|---|---|---|---|---|
| 1.1 | Tighten `active_calls` read rule to call participants only | S-1 | 1h | Any user can see all active calls |
| 1.2 | Tighten ICE candidates create rule to call participants | S-2 | 1h | Potential call injection |
| 1.3 | Tighten `group_media` storage to group members | S-6 | 2h | Any user can read/delete group files |
| 1.4 | Scope support attachment storage to ticket owner + staff | S-9 | 1h | Any user can read attachments |
| 1.5 | Switch LiveKit default URL to `wss://` with domain | S-3 | 2h | Unencrypted call signaling |
| 1.6 | Fix CI Node version to match functions engine (22) | S-4 | 30m | Functions deployed on wrong runtime |
| 1.7 | Remove blanket `use_build_context_synchronously: ignore` | S-5 | 4h | Hidden widget lifecycle bugs |
| 1.8 | Remove blanket `deprecated_member_use: ignore` | Q-5 | 2h | Missed deprecation warnings |
| 1.9 | Add auth emulator to firebase.json | S-11 | 30m | Local dev hits prod auth |

**Deliverables:** Updated `firestore.rules`, `storage.rules`, `analysis_options.yaml`, `firebase.json`, CI config.

---

### Phase 2: Quality & Dead Code Cleanup (2-3 weeks)

**Goal:** Remove dead code, fix duplicate logic, increase test coverage on critical paths.

| # | Task | Finding | Effort |
|---|---|---|---|
| 2.1 | Verify and remove `flutter_webrtc` from pubspec if unused | Q-3 | 2h |
| 2.2 | Verify Syncfusion license compliance | Q-4 | 1h | **NOTE**: `syncfusion_flutter_pdfviewer ^32.1.25` used only in `pdf_viewer_page.dart`. Community license is free for companies with <$1M revenue. Otherwise requires commercial license. Phase 4 task 4.9 evaluates open-source alternatives (e.g., `pdfx`, `flutter_pdfview`). |
| 2.3 | Delete `admin_ticket_detail_page_refactored.dart` duplicate | M-6 | 15m |
| 2.4 | Delete `success_animation_example.dart` from shared widgets | M-7 | 15m |
| 2.5 | Delete `FirestoreChatService` deprecated facade | A-8 | 1h |
| 2.6 | Delete empty `calling/managers/` directory | A-8 | 5m |
| 2.7 | Remove single-value `CallProvider` enum and `_parseProvider()` | A-8 | 30m |
| 2.8 | Consolidate theme files: remove `_refactored`, merge shadow files | M-2 | 4h |
| 2.9 | Extract `AccountCleanupService` from duplicate cleanup in AuthState + UserRepo | M-1 | 4h |
| 2.10 | Fix `CallErrorHandler` double snackbar issue | Q-7 | 1h |
| 2.11 | Fix `ErrorHandler.executeMultiple` to run in parallel or rename | Q-6 | 1h |
| 2.12 | Fix `ErrorHandler._parseError` to use Firebase error codes | Q-8 | 2h |
| 2.13 | Add tests for `authentication` feature (splash flow) | Q-1 | 4h |
| 2.14 | Add tests for `phone_auth` feature | Q-1 | 4h |
| 2.15 | Add tests for shared services (error_handler, event_bus, snackbar) | Q-1 | 4h |
| 2.16 | Expand CI service-tests to auto-discover test files | Q-2 | 2h |
| 2.17 | Add Cloud Functions tests to CI pipeline | Q-2 | 2h |

**Deliverables:** Cleaner dependency tree, ~10+ new test files, reduced dead code, CI improvements.

---

### Phase 3: Architecture Standardization (3-4 weeks)

**Goal:** Establish consistent patterns across all features. No feature rewrites — incremental alignment.

| # | Task | Finding | Effort |
|---|---|---|---|
| 3.1 | Document canonical feature structure in CONTRIBUTING.md | A-1 | 2h |
| 3.2 | Split `models.dart` (475L) into individual model files | A-5 | 3h |
| 3.3 | Add `==`/`hashCode` (Equatable) to User, Message, Room, Product | M-5 | 3h |
| 3.4 | Standardize serialization: adopt `fromJson`/`toJson` for all models | M-4 | 4h |
| 3.5 | Move misplaced files (chat utils, admin wrapper, token service) | A-4 | 2h |
| 3.6 | Remove Firestore `DocumentSnapshot` from `IChatMessageRepository` interface | A-6 | 3h |
| 3.7 | Consolidate spacing constants to single source (`AppSpacing`) | ST-2 | 4h |
| 3.8 | Align validator API — make all validators extend `BaseValidator` | ST-3 | 3h |
| 3.9 | Consolidate `ErrorHandler` to single API (deprecate old methods) | A-3 | 4h |
| 3.10 | Decide `Result<T>` vs `ErrorHandler` — document guidance, deprecate one | A-3 | 2h |
| 3.11 | Extract `ChatPageService` UI operations into VM/page layer | A-2 | 4h |
| 3.12 | Remove direct `FirebaseAuth` access from page/widget files | A-7 | 3h |
| 3.13 | Cache `RoleService.hasPermission()` with role stream data | P-1 | 3h |
| 3.14 | Move hardcoded Storage bucket from User model to config | S-10 | 1h |
| 3.15 | Adopt `AppStrings` in 3 most-used features (chat, calling, home) | ST-1 | 6h |

**Deliverables:** Consistent feature structure, single error handling API, clean model layer, design system consolidation.

---

### Phase 4: Strategic Improvements (Ongoing)

**Goal:** Longer-term investments that improve developer experience and app quality.

| # | Task | Finding | Effort |
|---|---|---|---|
| 4.1 | Introduce use-case/interactor layer for complex business logic | A-2 | 2-3 weeks |
| 4.2 | Add structured logging (JSON) for production observability | notes | 1 week |
| 4.3 | Evaluate declarative routing (go_router) for deep linking | ST-4 | 1-2 weeks |
| 4.4 | Add integration/E2E tests for critical flows (auth, calling, chat) | Q-2 | 2 weeks |
| 4.5 | Upgrade EventBus to generic typed events or replace with streams | M-3 | 3 days |
| 4.6 | Add Firestore rules unit tests to CI | Q-2 | 3 days |
| 4.7 | Create abstract interfaces for `AnalyticsService`, `RemoteConfigService` | notes | 3 days |
| 4.8 | Align calling feature call page to MVVM (replace StatefulWidget+Controller) | A-1 | 1 week |
| 4.9 | Evaluate replacing Syncfusion PDF viewer with open-source alternative | Q-4 | 3 days |
| 4.10 | Add SAST scanning to CI pipeline | notes | 2 days |

**Deliverables:** Clean architecture layer, E2E test suite, declarative routing, improved observability.

---

## Appendix: Files Referenced

| Finding | Key Files |
|---|---|
| A-1 | `lib/features/*/` (all feature directories) |
| A-2 | `lib/providers/auth_provider.dart`, `lib/data/repositories/user/user_repository.dart` |
| A-3 | `lib/shared/services/error_handler.dart`, `lib/utils/result.dart`, `lib/core/errors/call_errors.dart` |
| A-5 | `lib/data/models/models.dart` |
| S-1, S-2 | `firestore.rules` |
| S-3 | `lib/core/config/remote_config_service.dart` |
| S-5 | `analysis_options.yaml` |
| S-6 | `storage.rules` |
| M-1 | `lib/providers/auth_provider.dart`, `lib/data/repositories/user/user_repository.dart` |
| M-2 | `lib/shared/themes/app_theme.dart`, `app_theme_refactored.dart`, `app_shadows.dart`, `theme_shadows.dart` |
| Q-1 | `test/` (94 files vs 378 source files) |
| Q-3 | `pubspec.yaml` — `flutter_webrtc: ^1.2.1` |
| ST-1 | `lib/constants/app_strings.dart` |
| ST-2 | `lib/shared/themes/app_spacing.dart`, `lib/shared/themes/app_theme.dart`, `lib/core/constants.dart` |
