# Codebase Review: SecurityExperts App

**Date:** 2026-02-26  
**Scope:** Architecture, Security, Performance, Code Quality  
**Stack:** Flutter 3.10+ / Firebase (Firestore, Auth, Storage, Functions, RTDB) / LiveKit / E2EE (AES-256-GCM + KMS)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Issues](#1-architecture-issues)
3. [Security Issues](#2-security-issues)
4. [Performance Issues](#3-performance-issues)
5. [Code Quality Issues](#4-code-quality-issues)
6. [Phased Remediation Plan](#phased-remediation-plan)

---

## Executive Summary

The SecurityExperts App is a well-structured Flutter application with feature-module organization, clean repository abstractions, robust E2EE (KMS-backed AES-256-GCM), and comprehensive test coverage (~130+ test files). The codebase demonstrates solid engineering fundamentals.

However, the review identified **28 issues** across four categories:

| Category | Critical | High | Medium | Low |
|---|---|---|---|---|
| Architecture | 0 | 3 | 4 | 2 |
| Security | 2 | 3 | 3 | 1 |
| Performance | 0 | 2 | 4 | 1 |
| Code Quality | 0 | 1 | 1 | 1 |

---

## 1. Architecture Issues

### ARCH-01 — Dual DI / State Management Systems (High)

**Location:** `lib/core/service_locator.dart`, `lib/providers/provider_setup.dart`

The app uses **both** GetIt (service locator) and Provider (ChangeNotifier) for dependency injection and state management. GetIt manages ~60+ registrations while Provider wraps only 3 services (`AuthState`, `RoleProvider`, `UploadManager`). ViewModels directly call `sl<T>()` inside constructors rather than receiving all dependencies via Provider.

**Impact:** Unclear ownership boundaries; harder to test (requires both `sl` reset and Provider overrides); new developers must learn two DI paradigms.

**Recommendation:** Consolidate. Either:
- (a) Move the 3 remaining Providers into GetIt and use `ChangeNotifierProvider.value` only for the Navigator/build-tree-bound state, or
- (b) Adopt a unified solution like `riverpod` that handles both scoped state and DI.

---

### ARCH-02 — Singleton + Factory Anti-Pattern in Services (High)

**Location:** `lib/shared/services/user_profile_service.dart`, `lib/shared/services/media_cache_service.dart`, `lib/core/config/remote_config_service.dart`

Several services implement the classic `_instance` / `factory` singleton pattern **and** are registered in GetIt:

```dart
// UserProfileService — has internal singleton AND is sl.registerSingleton
static final UserProfileService _instance = UserProfileService._internal();
factory UserProfileService() => _instance;

// MediaCacheService — same pattern
static final MediaCacheService _instance = MediaCacheService._internal();
factory MediaCacheService() => _instance;

// RemoteConfigService — same pattern
static final RemoteConfigService _instance = RemoteConfigService._internal();
factory RemoteConfigService() => _instance;
```

**Impact:** GetIt's `registerSingleton` already guarantees a single instance. Having both means `MediaCacheService()` and `sl<MediaCacheService>()` return the same object, but the guarantee comes from _two_ mechanisms, which is confusing and fragile. Tests that call `sl.reset()` won't reset the static singleton.

**Recommendation:** Remove the static singleton pattern; rely solely on GetIt's `registerLazySingleton`. Change private constructors to public.

---

### ARCH-03 — Feature Module Boundary Violations (High)

**Location:** `lib/core/service_locator.dart` imports from all `features/*/`

The service locator directly imports and registers ViewModels/services from all 11 feature modules, creating a tight coupling graph rooted at the core layer. The core layer knows about every feature.

**Impact:** Adding/removing a feature requires touching `service_locator.dart`. Feature independence is violated.

**Recommendation:** Each feature module should expose a `registerDependencies(GetIt sl)` function. The service locator calls each module's registrar:

```dart
// In service_locator.dart
import 'features/chat/chat_feature.dart';
import 'features/calling/calling_feature.dart';
// ...
await chatFeature.register(sl);
await callingFeature.register(sl);
```

---

### ARCH-04 — Routing Defined Inline with String Matching (Medium)

**Location:** `lib/main.dart` lines 160–210 (`onGenerateRoute`)

Routes are defined via cascading `if (settings.name == ...)` / `if (settings.name?.startsWith(...))` checks. Route names are plain strings scattered across the codebase.

**Impact:** No compile-time safety; easy to mistype route names; no type-safe argument passing.

**Recommendation:** Adopt `go_router` or at minimum define a `Routes` constants class with a centralized route table and typed argument records.

---

### ARCH-05 — Missing Repository Interfaces for Several Modules (Medium)

**Location:** `lib/data/repositories/interfaces/` vs actual implementations

Repository interfaces exist for Chat, User, Expert, and Product. However, admin repositories (`AdminFaqRepository`, `AdminSkillsRepository`, `AdminTicketRepository`, `AdminUserRepository`), support repositories (`SupportRepository`, `SupportAttachmentRepository`), rating repository (`RatingRepository`), and calling repositories all lack formal interfaces.

**Impact:** These modules are harder to mock in tests and cannot be swapped for alternate implementations.

**Recommendation:** Add `IAdminRepository`, `ISupportRepository`, `IRatingRepository`, `ICallRepository` interfaces in `data/repositories/interfaces/`.

---

### ARCH-06 — `ChatConversationViewModel` is Overly Large (Medium)

**Location:** `lib/features/chat/presentation/view_models/chat_conversation_view_model.dart` (537 lines)

This ViewModel orchestrates ~10 services, handles text input, file attachment, camera capture, audio recording, message CRUD, presence, analytics, and upload state. It is the highest-coupling class in the application.

**Impact:** Difficult to test comprehensively; hard to navigate; violation of Single Responsibility.

**Recommendation:** Extract sub-ViewModels or use composable mixins: `ChatInputMixin`, `ChatMediaMixin`, `ChatRecordingMixin`, each focused on one concern.

---

### ARCH-07 — `CallCoordinator` Contains Unrelated UI Code (Medium)

**Location:** `lib/features/calling/services/call_coordinator.dart` — `showDeleteMessageDialog()`

A **call** coordination class contains a `showDeleteMessageDialog()` method that has nothing to do with calls.

**Impact:** Confusing for maintainers; violates SRP.

**Recommendation:** Move `showDeleteMessageDialog` to a shared dialog utility or the chat feature module.

---

### ARCH-08 — `run_tests.sh` References Wrong App Name (Low)

**Location:** `run_tests.sh` line 5: `echo "🧪 GreenHive App - Test Runner"`

The script header references "GreenHive App" instead of "SecurityExperts App". The hardcoded summary also claims "Total tests created: 184" regardless of actual results.

**Recommendation:** Fix branding. Replace hardcoded summary with dynamic test count parsing.

---

### ARCH-09 — Dockerfile for Go Backend Has No Matching Source (Low)

**Location:** `Dockerfile.example`, `go.mod.example`

A Go-based Dockerfile and `go.mod.example` exist but there is no Go source code in the repo. These appear to be template artifacts.

**Recommendation:** Remove if unused, or move to a `templates/` directory with a README explaining their purpose.

---

## 2. Security Issues

### SEC-01 — Firebase API Keys Committed to Source Control (Critical)

**Location:** `lib/firebase_options.dart`

All platform-specific Firebase API keys, App IDs, and project configuration are hardcoded and committed:

```dart
apiKey: 'AIzaSyBNcNVnt6Td9FJ_0aOLcLSU-t4DLdYFlHk',  // Web
apiKey: 'AIzaSyBe9D55nX2YJq1aIMf6uPW4gFNokaffbVo',  // Android
apiKey: 'AIzaSyAbp_cYNPSnPOlYMnTtnGKJUCbwOSbtvbM',  // iOS
```

**Impact:** While Firebase API keys are considered semi-public (security is enforced by rules), these keys can still be abused for quota exhaustion, analytics poisoning, and enumeration attacks if App Check is not enabled. The keys also expose the project ID, database URL, and storage bucket.

**Recommendation:**
1. Enable **Firebase App Check** for all services (Firestore, Storage, Functions, RTDB) to reject requests without valid attestation.
2. Add `lib/firebase_options.dart` to `.gitignore` for future repos (it's auto-generated by FlutterFire CLI).
3. Consider rotating the web API key if the repo has ever been public.

---

### SEC-02 — Storage Rules Allow Overly Broad Access (Critical)

**Location:** `storage.rules`

```
// SUPPORT TICKET ATTACHMENTS
match /support/{ticketId}/{allPaths=**} {
  allow read: if request.auth != null;
  allow delete: if request.auth != null;
```

**Any authenticated user** can read and delete **any** support ticket attachment. There is no participant or ownership check.

**Impact:** Users can read other users' sensitive support attachments (screenshots, documents). A malicious user could delete evidence from other users' tickets.

**Recommendation:**
```
allow read: if request.auth != null && (
  // User's ticket OR support staff
  request.auth.uid == resource.metadata['uploadedBy'] ||
  ticketId.split('_')[0] == request.auth.uid
);
allow delete: if false;  // Only Cloud Functions should delete
```

---

### SEC-03 — Chat Room Participant Check Uses roomId Parsing (High)

**Location:** `storage.rules` — chat_attachments, encrypted_media

```
allow read: if request.auth != null && 
  (roomId.split('_')[0] == request.auth.uid || 
   roomId.split('_')[1] == request.auth.uid);
```

This relies on the room ID format being exactly `"uid1_uid2"`. If a room ID ever has a different format (e.g., group chats, future migration), this check breaks silently and either grants or denies access incorrectly.

**Impact:** Brittle access control that is format-dependent rather than data-dependent.

**Recommendation:** For storage rules where Firestore cross-reference is not available, document the room ID format as a hard contract. Alternatively, use Cloud Functions as a proxy for storage uploads/downloads so access can be verified against the Firestore room document.

---

### SEC-04 — `sealRoomKey` Race Condition on Key Creation (High)

**Location:** `functions/src/e2ee/roomKeyManagement.ts` lines 65-80

```typescript
// 2. Idempotency — if key already exists, decrypt and return it
const existingCiphertext = roomDoc.data()?.encrypted_room_key;
if (existingCiphertext) {
  return decryptAndReturn(existingCiphertext);
}

// 3. Generate random 32-byte room key
const roomKey = crypto.randomBytes(32);
// ...
// 5. Store on room document
await roomRef.update({
  encrypted_room_key: ciphertextB64,
  e2ee_enabled: true,
});
```

The check-then-write is **not wrapped in a Firestore transaction**. If two participants call `sealRoomKey` concurrently before either write completes, both generate different keys, and the last write wins — causing one participant to have the wrong key.

**Impact:** Messages encrypted with the overwritten key become unrecoverable.

**Recommendation:** Use a Firestore transaction:

```typescript
await db.runTransaction(async (tx) => {
  const roomDoc = await tx.get(roomRef);
  const existing = roomDoc.data()?.encrypted_room_key;
  if (existing) return decryptAndReturn(existing);
  // ... generate, encrypt, tx.update(...)
});
```

---

### SEC-05 — Room Key Returned in Plaintext Over Cloud Function Response (High)

**Location:** `functions/src/e2ee/roomKeyManagement.ts`

Both `handleSealRoomKey` and `handleGetRoomKey` return `{ roomKey: <base64 plaintext> }` in the Cloud Function response. While Cloud Functions use HTTPS, the response is logged by default in Firebase Functions logs.

**Impact:** Room keys may be persisted in Cloud Logging, which has a different retention policy and access control model than KMS.

**Recommendation:**
1. Explicitly set `logger.info()` calls to **not** include the roomKey value (currently they don't, but future logging changes could expose it).
2. Consider returning the key encrypted to the client's public key (requires client to send a per-session public key).
3. Add a Cloud Logging exclusion filter for the `api` function response body.

---

### SEC-06 — No Rate Limiting on Cloud Functions (Medium)

**Location:** `functions/src/index.ts` — the unified `api` onCall function

The `api` Cloud Function handles all sensitive operations (createCall, key management) with no rate limiting beyond Firebase's global quotas.

**Impact:** A compromised client or leaked credentials can spam key retrieval, call creation, or message sends without server-side throttling.

**Recommendation:** Add per-user rate limiting using Firestore counters or Firebase Extensions (Rate Limiter). For the `api` function:

```typescript
const userCallCount = await getUserCallCountInWindow(uid, 60); // 60-second window
if (userCallCount > 10) {
  throw new HttpsError('resource-exhausted', 'Rate limit exceeded');
}
```

---

### SEC-07 — FCM Token Logged to Console (Medium)

**Location:** `lib/main.dart` lines 97-98

```dart
final token = await FirebaseMessaging.instance.getToken();
sl<AppLogger>().debug('Web FCM Token: $token', tag: _tag);
```

FCM tokens are logged in debug mode. If debug logs are accidentally shipped or captured in crash reports, tokens could be leaked.

**Impact:** Leaked FCM tokens allow sending unsolicited push notifications to the device.

**Recommendation:** Redact FCM tokens in logs: `token?.substring(0, 10) + '...'`.

---

### SEC-08 — `user_documents` Storage Path Has No Content-Type Restriction (Medium)

**Location:** `storage.rules`

```
match /user_documents/{userId}/{document=**} {
  allow read, write, delete: if request.auth != null && 
                                request.auth.uid == userId;
}
```

No file size limit, no content-type restriction. A user can upload arbitrarily large files of any type.

**Impact:** Storage cost abuse; potential for hosting malicious content.

**Recommendation:** Add size and type constraints:
```
allow write: if request.auth != null &&
  request.auth.uid == userId &&
  request.resource.size <= 52428800 &&  // 50MB
  (request.resource.contentType.matches('image/.*') ||
   request.resource.contentType == 'application/pdf' ||
   request.resource.contentType.matches('video/.*'));
```

---

### SEC-09 — No App Check Enforcement Documented (Low)

**Location:** Project-wide

There is no evidence of Firebase App Check integration in the Flutter app or Cloud Functions. Without App Check, any HTTP client with the API key can call Cloud Functions and access Firestore/Storage.

**Recommendation:** Enable App Check with DeviceCheck (iOS), Play Integrity (Android), and reCAPTCHA Enterprise (Web). Enforce in Cloud Functions:

```typescript
export const api = onCall({ enforceAppCheck: true }, async (request) => { ... });
```

---

## 3. Performance Issues

### PERF-01 — Firestore `get()` Calls in Security Rules (High)

**Location:** `firestore.rules` — multiple `get()` calls

The rules use `get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles` in many places (users collection, support tickets, admin operations). Each `get()` in a rule costs a Firestore read and adds latency to every request.

**Impact:** A single write to a support ticket message triggers up to **3 Firestore reads** just for the security rule evaluation. At scale, this multiplies costs and slows writes.

**Recommendation:**
1. Store the user's role as a **custom claim** in Firebase Auth tokens (`request.auth.token.role`). This eliminates the `get()` calls entirely.
2. Set custom claims via a Cloud Function when roles change:
```typescript
await admin.auth().setCustomUserClaims(uid, { roles: ['Expert', 'Admin'] });
```
3. Update rules to: `request.auth.token.roles.hasAny(['Admin', 'SuperAdmin'])`.

---

### PERF-02 — UserCacheService Creates Firestore Listener Per User (High)

**Location:** `lib/shared/services/user_cache_service.dart` — `_startListeningToUser()`

Every user fetched (via `getOrFetch`, `fetchMultiple`, or the chat list prefetch) gets a **dedicated Firestore snapshot listener**. In a chat list with 50 conversations, this creates 50 active Firestore listeners.

**Impact:** Each listener maintains a WebSocket channel to Firestore, consuming mobile bandwidth and battery. Firestore charges per document read on initial snapshot and per change.

**Recommendation:**
- Use a **polling approach** for non-active users (e.g., refresh profile data on chat open, not continuously).
- Only maintain real-time listeners for users currently visible on screen.
- Implement a max listener cap (e.g., 20) and evict LRU listeners.

---

### PERF-03 — Chat Messages Loaded with `limitToLast(50)` Without Pagination (Medium)

**Location:** `lib/features/chat/services/chat_stream_service.dart` line 48

```dart
_messageRepository.getMessagesStream(roomId, limit: 50)
```

While the repository supports pagination via `loadOlderMessages()`, the stream service hardcodes loading the last 50 messages. For rooms with long histories, this is efficient. However, the limit is not configurable via Remote Config and the initial 50 might be too low for power users or too high for slow connections.

**Recommendation:** Make the batch size configurable via `RemoteConfigService` and consider a smaller default (e.g., 30) for mobile connections.

---

### PERF-04 — Media Cache Uses `SharedPreferences` for URL Index (Medium)

**Location:** `lib/shared/services/media_cache_service.dart`

The cache index for each room's media URLs is stored in `SharedPreferences` (key-value XML/plist). Each media file operation reads and writes the index:

```dart
final prefs = await SharedPreferences.getInstance();
final urls = prefs.getStringList(key) ?? [];
urls.add(url);
await prefs.setStringList(key, urls);
```

**Impact:** `SharedPreferences` is backed by file I/O on each write. With many media files across rooms, this becomes a bottleneck during room cleanup and cache clearing operations.

**Recommendation:** Use `sqflite` or `hive` for the cache index, or rely entirely on the file system cache directory (scan directory when needed instead of maintaining a separate index).

---

### PERF-05 — Duplicate Room Sorting in ChatListViewModel (Medium)

**Location:** `lib/features/chat_list/presentation/view_models/chat_list_view_model.dart`

Rooms are sorted by `lastMessageDateTime` in three places:
1. `loadRooms()` — after fetch
2. `_subscribeToRoomUpdates()` — on each stream emission  
3. `ChatRoomRepository.getUserRoomsStream()` — inside the repository's `.map()`

**Impact:** Triple-sorting the same data on every stream emission.

**Recommendation:** Sort only once, preferably in the repository's stream, and have the ViewModel trust the order.

---

### PERF-06 — `MediaCacheService` Static Fields Prevent Memory Release (Medium)

**Location:** `lib/shared/services/media_cache_service.dart`

```dart
static final Map<String, Uint8List> _decryptedBytesCache = {};
static final Map<String, Future<Uint8List?>> _inflightDecrypts = {};
```

These are `static final` maps that grow unbounded across the app's lifetime. Decrypted media bytes are never evicted.

**Impact:** In a long session with many media messages, memory usage grows continuously. A single 10MB video consumes 10MB of Dart heap indefinitely.

**Recommendation:** Implement an LRU eviction policy or size-based cap (e.g., 100MB max in-memory cache). Consider using `flutter_cache_manager`'s disk-based approach consistently rather than augmenting it with in-memory caching.

---

### PERF-07 — `asyncMap` in Message Stream Blocks UI Thread (Low)

**Location:** `lib/data/repositories/chat/chat_message_repository.dart` — `getMessagesStream()`

The `.asyncMap()` call processes every Firestore snapshot by awaiting `_parseDocument()` for each message. If decryption is involved, this can block the stream pipeline.

**Recommendation:** Consider using `compute()` for batch decryption of messages to move crypto work off the main isolate.

---

## 4. Code Quality Issues

### QA-01 — Inconsistent Error Handling Patterns (High)

**Location:** Multiple files

The codebase uses three distinct error handling approaches:
1. `ErrorHandler.handle<T>()` — modern approach with typed fallback
2. `try/catch` with local handling
3. `.catchError()` on Futures

Example of `.catchError()` in `chat_conversation_view_model.dart`:
```dart
await _unreadMessagesService.markRoomAsRead(_state.roomId).catchError((e) {
  _logger.warning('Error marking room as read: $e');
});
```

Meanwhile the same file uses `ErrorHandler.handle<void>()` elsewhere.

**Impact:** Inconsistency makes it hard to reason about error propagation; `.catchError()` swallows typed exception information.

**Recommendation:** Standardize on `ErrorHandler.handle<T>()` for all async operations. Lint rule or custom analyzer plugin to flag `.catchError()` usage.

---

### QA-02 — `ChatListViewModel` Creates New `MediaCacheService()` Instance (Medium)

**Location:** `lib/features/chat_list/presentation/view_models/chat_list_view_model.dart` line 27

```dart
final MediaCacheService _mediaCacheService = MediaCacheService();
```

This bypasses GetIt and creates the service via the factory constructor. While it returns the singleton due to the static instance pattern (ARCH-02), it's inconsistent with how other services are obtained.

**Recommendation:** Use `sl<MediaCacheService>()` consistently.

---

### QA-03 — Debug Logging Uses Emoji Extensively (Low)

**Location:** `lib/main.dart`, various services

```dart
logger.debug('🚀 main() called (count: $_mainCallCount)', tag: _tag);
sl<AppLogger>().debug('🏠 [MyApp-$_instanceId] Created', tag: _tag);
```

**Impact:** Emojis in log messages can cause rendering issues in some log aggregation systems and make grep-based log analysis harder.

**Recommendation:** Reserve emojis for local dev; use structured logging tags instead (`[INIT]`, `[LIFECYCLE]`).

---

## Phased Remediation Plan

### Phase 1: Security Hardening (Week 1–2) — Critical & High Security

| ID | Issue | Effort | Priority |
|---|---|---|---|
| SEC-01 | Enable Firebase App Check; rotate web API key | 2 days | Critical |
| SEC-02 | Fix storage rules for support ticket attachments | 0.5 day | Critical |
| SEC-04 | Wrap `sealRoomKey` in Firestore transaction | 0.5 day | High |
| SEC-05 | Ensure room keys never appear in Cloud Logging | 0.5 day | High |
| SEC-03 | Document roomId format contract; add validation | 1 day | High |
| SEC-08 | Add size/type constraints to `user_documents` storage rule | 0.5 day | Medium |

**Deliverables:**
- Updated `storage.rules` with fixed access controls
- Updated `functions/src/e2ee/roomKeyManagement.ts` with transaction
- App Check enabled across all Firebase services
- Security documentation updated

---

### Phase 2: Performance Optimization (Week 3–4) — High & Medium Performance

| ID | Issue | Effort | Priority |
|---|---|---|---|
| PERF-01 | Migrate roles to Firebase Auth custom claims | 3 days | High |
| PERF-02 | Add listener cap + LRU eviction to UserCacheService | 2 days | High |
| PERF-06 | Add LRU eviction to `_decryptedBytesCache` | 1 day | Medium |
| PERF-05 | Deduplicate room sorting | 0.5 day | Medium |
| PERF-04 | Evaluate SharedPreferences → Hive for cache index | 1 day | Medium |
| PERF-03 | Make message batch size configurable via Remote Config | 0.5 day | Medium |

**Deliverables:**
- Custom claims–based security rules (no more `get()` calls)
- Bounded memory caches with eviction
- Reduced Firestore reads per request
- Measurable latency improvement in rule evaluation

---

### Phase 3: Architecture Cleanup (Week 5–7) — High & Medium Architecture

| ID | Issue | Effort | Priority |
|---|---|---|---|
| ARCH-02 | Remove static singletons; rely on GetIt only | 1 day | High |
| ARCH-03 | Decentralize service registration per feature module | 3 days | High |
| ARCH-01 | Consolidate Provider + GetIt overlap | 2 days | High |
| ARCH-04 | Introduce typed routing (go_router or route constants) | 2 days | Medium |
| ARCH-06 | Decompose ChatConversationViewModel via mixins | 2 days | Medium |
| ARCH-05 | Add missing repository interfaces | 1 day | Medium |
| ARCH-07 | Move misplaced `showDeleteMessageDialog` | 0.5 day | Medium |

**Deliverables:**
- Single DI mechanism with clear patterns
- Feature modules with self-registration
- Typed routing with compile-time safety
- Smaller, focused ViewModels

---

### Phase 4: Code Quality & Polish (Week 8) — Remaining Issues

| ID | Issue | Effort | Priority |
|---|---|---|---|
| QA-01 | Standardize on `ErrorHandler.handle<T>()` everywhere | 1 day | High |
| QA-02 | Fix DI bypass in ChatListViewModel | 0.5 day | Medium |
| SEC-06 | Add Cloud Function rate limiting | 1 day | Medium |
| SEC-07 | Redact FCM tokens in debug logs | 0.5 day | Medium |
| SEC-09 | Add App Check enforcement to Cloud Functions | 0.5 day | Low |
| ARCH-08 | Fix test runner branding and hardcoded counts | 0.5 day | Low |
| ARCH-09 | Remove orphaned Go template files | 0.5 day | Low |
| QA-03 | Standardize log message format | 0.5 day | Low |
| PERF-07 | Move message decryption to isolate | 1 day | Low |

**Deliverables:**
- Consistent error handling codebase-wide
- Rate-limited Cloud Functions
- Clean repository with no dead artifacts
- Structured logging format

---

## Summary

The codebase is in good shape with strong fundamentals: well-organized feature modules, robust E2EE implementation, clean repository pattern, and extensive test coverage. The highest-priority items are the **storage rule access control flaws** (SEC-02) and the **room key race condition** (SEC-04), both of which should be addressed immediately. The performance recommendation with the highest ROI is migrating roles to **custom claims** (PERF-01), which will eliminate ~3 Firestore reads per security rule evaluation.

Total estimated effort: **~4–5 developer-weeks** spread across 8 calendar weeks.
