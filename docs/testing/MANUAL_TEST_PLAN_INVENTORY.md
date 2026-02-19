# GreenHive App — Comprehensive Feature Inventory for Manual Test Plan

**Generated**: February 10, 2026  
**App Version**: 1.1.1+1  
**Platforms**: iOS, Android, Web, macOS, Windows  
**Theme Mode**: Always Dark (GreenHive design)

---

## Table of Contents

1. [App Initialization & Infrastructure](#1-app-initialization--infrastructure)
2. [Authentication — Splash Screen](#2-authentication--splash-screen)
3. [Phone Authentication](#3-phone-authentication)
4. [Onboarding](#4-onboarding)
5. [Home Page — Expert Discovery](#5-home-page--expert-discovery)
6. [Expert Details Page](#6-expert-details-page)
7. [Product Details Page](#7-product-details-page)
8. [Chat List (Conversations)](#8-chat-list-conversations)
9. [Chat Conversation](#9-chat-conversation)
10. [Media Manager](#10-media-manager)
11. [PDF Viewer](#11-pdf-viewer)
12. [Text/Code Viewer](#12-textcode-viewer)
13. [Calling — Audio/Video Calls](#13-calling--audiovideo-calls)
14. [Call History](#14-call-history)
15. [Incoming Call Handling](#15-incoming-call-handling)
16. [User Profile Management](#16-user-profile-management)
17. [Admin Dashboard](#17-admin-dashboard)
18. [Admin — Ticket Management](#18-admin--ticket-management)
19. [Admin — User Management](#19-admin--user-management)
20. [Admin — Skills Management](#20-admin--skills-management)
21. [Admin — FAQ Management](#21-admin--faq-management)
22. [Support / Help Center](#22-support--help-center)
23. [Ratings & Reviews](#23-ratings--reviews)
24. [Push Notifications](#24-push-notifications)
25. [User Presence System](#25-user-presence-system)
26. [Firebase Services Used](#26-firebase-services-used)
27. [Device Capabilities Used](#27-device-capabilities-used)
28. [Cross-Cutting Concerns](#28-cross-cutting-concerns)
29. [Platform-Specific Behavior](#29-platform-specific-behavior)

---

## 1. App Initialization & Infrastructure

**File**: `lib/main.dart`

### Startup Sequence
1. `WidgetsFlutterBinding.ensureInitialized()`
2. Web: Install WebRTC error filter (suppresses `InvalidStateError` during call termination)
3. `Firebase.initializeApp()` with platform-specific options
4. `setupServiceLocator()` — registers ~80+ services via GetIt DI
5. `ShakeHandler.setup()` — shake-to-toggle verbose logging (device shake detection)
6. Check for cold-start notification tap (`getInitialMessage()`)
7. Set iOS foreground notification presentation options (alert, badge, sound)
8. Web: Request notification permission and get FCM token
9. Initialize `NotificationService` (local notifications)
10. Initialize `RemoteConfigService` (Firebase Remote Config)
11. Set UI shape style (`AppShapeStyle.pill`)
12. Clear notification badge
13. Initialize `CallListenerService` (checks notification permission for call strategy)
14. `runApp(MyApp())`

### App Lifecycle Handling (`WidgetsBindingObserver`)
- **Resumed**: Clear badge, set presence to foreground (online)
- **Paused/Inactive**: Set presence to background (offline)
- **Detached/Hidden**: No special handling

### Named Routes (via `onGenerateRoute`)
| Route | Page | Purpose |
|-------|------|---------|
| `/chat` | `ChatConversationPage` | Notification deep link to chat |
| `/admin` | `AdminDashboardPage` | Admin panel entry |
| `/admin/tickets` | `AdminTicketsPage` | Admin tickets list |
| `/admin/tickets/:id` | `AdminTicketDetailPage` | Individual ticket |
| `/admin/faqs` | `AdminFaqsPage` | FAQ management |
| `/admin/faqs/:id` | `AdminFaqEditorPage` | FAQ editor |
| `/admin/skills` | `AdminSkillsPage` | Skills management |
| `/admin/skills/:id` | `AdminSkillEditorPage` | Skill editor |
| `/admin/users` | `AdminUsersPage` | User management |

### Global UI Wrappers
- `CallOverlay` wraps entire app — handles incoming call banners and minimized call PiP
- `AnalyticsRouteObserver` — tracks screen views and durations to Firebase Analytics
- `SnackbarService.messengerKey` — global snackbar scaffold key
- `PendingNotificationHandler.navigatorKey` — global navigator key for notification deep links

### Service Locator (Key Services)
- **Core**: AppLogger, RemoteConfigService, ErrorHandler, EventBus, PhoneValidator, AnalyticsService
- **Data**: FirebaseAuth, FirebaseFirestore, FirestoreInstance, RoleService
- **Shared**: UserProfileService, UserCacheService, RingtoneService, ProfanityFilterService
- **Chat**: UnreadMessagesService, MediaUploadService, MediaDownloadService, MediaCacheService, AudioRecordingManager, ReplyManagementService, ChatPageService, UploadManager, UserPresenceService
- **Profile**: BiometricAuthService, ProfilePictureService, SkillsService
- **Notifications**: NotificationService, FirebaseMessagingService
- **Calling**: Full calling DI (signaling, media manager, LiveKit, CallKit, call analytics, network quality)
- **Support**: SupportService, SupportRepository, SupportAttachmentRepository, FaqService, SupportAnalytics
- **Admin**: AdminTicketService, AdminFaqService, AdminSkillsService, AdminUserService
- **Ratings**: RatingRepository, RatingService

### State Providers (via `MultiProvider`)
| Provider | Purpose | Lazy |
|----------|---------|------|
| `AuthState` | Firebase Auth state, FCM/VoIP token management | No (immediate) |
| `RoleProvider` | Streams user role from Firestore for admin features | No (immediate) |
| `UploadManager` | Global background upload state, progress tracking | Value (singleton) |

---

## 2. Authentication — Splash Screen

**File**: `lib/features/authentication/pages/splash_screen.dart`

### Screen Description
Initial app entry point. Shows pulsing GreenHive logo with "Welcome to GreenHive" text on dark background.

### Logic Flow
1. Check `FirebaseAuth.currentUser`
2. If **no user** → Navigate to `PhoneAuthPage`
3. If **user exists** AND **biometric enabled**:
   - Check if biometric available → If not available, log out
   - Authenticate with biometric
   - Success → Continue to profile check
   - Failed → Log out → `PhoneAuthPage`
   - Skipped (system UI conflict, e.g., CallKit active) → Continue without logout
4. Fetch profile from Firestore via `UserRepository.getCurrentUserProfile()`
5. If **profile exists** → Set `UserProfileService`, update last login, navigate to `HomePage`
6. If **no profile** → Navigate to `UserOnboardingPage`

### State Transitions
- Loading state (pulsing animation)
- Biometric authentication prompt (system dialog)
- Error state (profile fetch fails → logout)

### User Interactions
- None (automatic flow)
- Biometric prompt (Face ID / Touch ID / Fingerprint)

### Edge Cases
- Biometric enabled but not available → auto logout
- CallKit active during biometric → skip biometric, continue
- Network error on profile fetch → error handling
- Concurrent execution guard (Completer pattern)
- Firebase Auth token null → logout

---

## 3. Phone Authentication

**Files**: `lib/features/phone_auth/pages/phone_auth_screen.dart`, `lib/features/phone_auth/presentation/view_models/phone_auth_view_model.dart`, `lib/features/phone_auth/presentation/state/`

### Screen Description
Two-step phone authentication: phone number entry → OTP verification.

### Step 1 — Phone Number Entry
**User Interactions**:
- Country code dropdown (multiple countries: US, CA, GB, IN, etc.)
- Phone number text input with formatting (PhoneNumberFormatter: spaces at positions 3, 6)
- "Send OTP" button (disabled when phone invalid or loading)

**State Transitions**:
- Idle → Loading (sending OTP) → OTP Step or Error
- Phone number validation (real-time via ViewModel)
- Error display below phone input field

### Step 2 — OTP Verification
**User Interactions**:
- OTP code text input (numeric, center-aligned)
- "Verify OTP" button (disabled while loading)
- Shows "We sent a code to [dial code] [phone]"

**State Transitions**:
- Idle → Loading (verifying) → Success or Error
- On success: Check if profile exists
  - Profile exists → `HomePage`
  - No profile → `UserOnboardingPage`

### Firebase Integration
- `FirebaseAuth.verifyPhoneNumber()` — sends SMS
- `PhoneAuthProvider.credential()` — verifies OTP
- `signInWithCredential()` — signs in

### Edge Cases
- Invalid phone number format
- Wrong OTP code
- OTP timeout/expiration
- Network errors during send/verify
- Auto-verification (Android)
- Country code switching resets phone input hints

---

## 4. Onboarding

**Files**: `lib/features/onboarding/pages/user_onboarding_page.dart`, `lib/features/onboarding/presentation/view_models/onboarding_view_model.dart`

### Screen Description
New user profile setup. Title: "Welcome to GreenHive" / "Let's set up your profile"

### User Interactions
1. **Display Name** — Text field with profanity filter, max 32 chars, substring matching, validation via `DisplayNameValidator`
2. **Role Selection** — Radio group: Expert / Merchant / Other (horizontal)
3. **Expert-only sections** (shown when Expert selected):
   - **Bio** — Multi-line text field with profanity filter
   - **Skills** — Tap card to open modal bottom sheet
     - Search bar for skills
     - Skills grouped by category (expandable tiles)
     - Checkbox per skill
     - Selected skills shown as Chips (deletable)
   - **Languages** — FilterChip grid (11 languages: English, Spanish, French, German, Portuguese, Hindi, Punjabi, Chinese, Arabic, Japanese, Korean)
4. **"Continue" button** — disabled when display name empty or saving

### State Transitions
- Initial loading (checking if profile already exists → auto-redirect to Home)
- Skills loading → loaded (with loading indicator in modal)
- Saving profile → Success (navigate to Home) or Error
- Error banner display (profile check error, save error, skill load error)

### Profile Creation Flow
1. Validate form
2. Build `User` model with name, roles, languages, expertises, bio
3. Call `UserRepository.createUser()`
4. Set `UserProfileService.setUserProfile()`
5. Emit `EventBus.profileUpdated`
6. Initialize token services (FCM, VoIP, presence)
7. Navigate to `HomePage`

### Edge Cases
- Existing profile found → redirect to Home immediately
- Profanity in display name or bio → filtered/rejected
- No skills selected for Expert role
- Network error on profile creation
- Skill search with no results

---

## 5. Home Page — Expert Discovery

**Files**: `lib/features/home/pages/home_page.dart`, `lib/features/home/widgets/experts_list_tab.dart`, `lib/features/home/widgets/products_tab.dart`, `lib/features/home/presentation/view_models/home_view_model.dart`

### Screen Description
Main app screen with 4 tabs: Experts, Chats, Calls, Products. Frosted glass app bar with logo + profile menu. Floating pill-shaped bottom navigation bar.

### App Bar
**User Interactions**:
- Profile picture (from `UserProfileService`) → `PopupMenuButton` (profile menu)
- Menu items: see [Profile Menu](#profile-menu) section

### Bottom Navigation (4 tabs)
| Tab | Icon | Content |
|-----|------|---------|
| 0. Experts | `person_search` | Expert discovery list |
| 1. Chats | `forum` | Chat conversations list (with unread badge) |
| 2. Calls | `call` | Call history |
| 3. Products | `storefront` | Product catalog |

### Tab 0: Experts List
**User Interactions**:
- Search bar (with focus state — hides bottom nav when focused)
- Expert cards with: name, profile picture, skills, rating
- Per expert: Chat button, Audio Call button, Video Call button
- Tap card → `ExpertDetailsPage`
- Pull-to-refresh

**State Transitions**:
- Loading (shimmer skeleton) → Loaded / Error / Empty
- Search query filtering (via `ExpertSearchUtils`)

### Tab 1: Chats
- Delegates to `ChatsTab` → `ChatPage` (see [Chat List](#8-chat-list-conversations))

### Tab 2: Calls
- Delegates to `CallsTab` → `CallHistoryPage` (see [Call History](#14-call-history))

### Tab 3: Products
**User Interactions**:
- Product cards with title, price
- Tap → `ProductDetailsPage`
- Pull-to-refresh

**State Transitions**:
- Loading → Loaded / Error / Empty

### Global Overlay
- `GlobalUploadIndicator` — shows upload progress when background uploads are active

---

## 6. Expert Details Page

**File**: `lib/features/home/pages/expert_details_page.dart`

### Screen Description
Full expert profile view with bio, skills, and ratings.

### Content Sections
1. **Profile header**: Profile picture (72px), name, rating summary (tappable → all reviews)
2. **About section**: Bio text in card container, or "No bio available"
3. **Skills section**: Skill name chips (loaded by resolving skill IDs to names)
4. **Recent Ratings**: Up to 3 rating cards with star display
5. **"See All Reviews" link** → `ExpertReviewsPage`

### State Transitions
- Loading skills → Loaded
- Loading ratings → Loaded (parallel fetch: stats + recent ratings)
- Error states for skills/ratings loading

---

## 7. Product Details Page

**File**: `lib/features/home/pages/product_details_page.dart`

### Screen Description
Simple product detail view.

### Content
- Title, price, description
- "Buy Now" button → placeholder purchase dialog (AlertDialog with "OK")

### User Interactions
- Buy Now button → shows purchase placeholder dialog
- Back navigation

---

## 8. Chat List (Conversations)

**Files**: `lib/features/chat_list/pages/chat_page.dart`, `lib/features/chat_list/presentation/view_models/chat_list_view_model.dart`

### Screen Description
List of all active chat conversations for the current user.

### User Interactions
- Tap conversation → `ChatConversationPage`
- Pull-to-refresh
- Each item shows: partner profile picture, name, last message preview, timestamp

### State Transitions
- Loading (shimmer skeleton - 8 items) → Loaded / Error / Empty
- Error state with retry button
- Empty state with icon and message

### Data
- Streams from Firestore `chat_rooms` where user is participant
- Shows unread counts per room (from `users/{userId}/rooms/{roomId}`)

---

## 9. Chat Conversation

**Files**: `lib/features/chat/pages/chat_conversation_page.dart`, `lib/features/chat/presentation/view_models/chat_conversation_view_model.dart`, `lib/features/chat/widgets/` (25 widget files)

### Screen Description
Full messaging interface with rich media support.

### App Bar (`ChatAppBar`)
**User Interactions**:
- Back button
- Partner profile picture + name
- Audio call button → initiates audio call
- Video call button → initiates video call
- Overflow menu:
  - **Media Manager** → `CachedMediaPage` (all shared media)
  - **Clear Chat** → confirmation dialog → delete all messages
  - **Delete Chat** → confirmation dialog → delete room + messages → pop back

### Message List
- Uses `ScrollablePositionedList` (reverse: true for chat UX)
- Date separator widgets between days
- Scroll-to-bottom floating button (appears when scrolled up)
- GestureDetector on tap to unfocus keyboard

### Message Types (per `ChatMessageListItem`)
- **Text messages**: With link preview (via `any_link_preview`), linkified text
- **Image messages**: Cached network images with thumbnail/full-size, tap to view full-screen
- **Video messages**: Inline preview with play button overlay, tap to play
- **Audio messages**: Playback controls (play/pause, duration, progress indicator)
- **Document messages**: File card with icon, name, size, tap to open
- **Call log messages**: "Audio/Video call - [duration]" display
- **Uploading messages**: Progress bar with filename and type

### Message Bubble Features
- **Swipe-to-reply** gesture (left for own, right for peer)
- **Reply preview bar** — shows quoted message above input
- **Long-press context menu** (`_MessageBubbleMenu`):
  - Reply
  - Copy text
  - Forward (future)
  - Delete (own messages)
- **Read status**: Sent/delivered/read indicators
- **Timestamp**: Per message

### Chat Input Widget
**User Interactions**:
1. **Text input** — Multi-line, profanity-filtered
2. **Attachment button** (+) → opens `AttachmentMenuSheet` (modal bottom sheet):
   - **Photos** — picks from gallery (image_picker)
   - **Document** — picks file (file_picker)
3. **Camera button** — inline camera preview (captures photo to send)
4. **Send button** — visible when text is entered
5. **Microphone button** — visible when no text; starts audio recording

### Audio Recording
**User Interactions**:
- Tap mic → starts recording (via `record` package)
- Recording overlay shows: duration timer, stop button
- After stopping: preview mode with play/discard/send buttons
- Discard → dismiss recording
- Send → uploads audio to Firebase Storage, sends message

### State Transitions
- Services initializing → Loading → Messages loaded
- Error loading messages → error text display
- Empty conversation → shows input only
- Recording state: idle → recording → stopped/preview → sent/discarded
- Upload progress state per file (0-100%)
- Uploading messages shown at bottom of list

### Pagination
- Loads more messages when scrolling to top (via `ChatScrollHandler.isLoadingMore`)
- `NeverScrollableScrollPhysics` while loading more

### Integrations
- **Firestore**: `chat_rooms/{roomId}/messages` collection
- **Firebase Storage**: Media file upload/download
- **Firebase Realtime Database**: User presence (online/offline, current chat room)
- **Camera**: `camera` package for inline photo capture
- **Microphone**: `record` package for audio recording
- **File Picker**: `file_picker` package for document selection
- **Image Picker**: `image_picker` for gallery photos
- **Image Compression**: `flutter_image_compress` for HEIC→JPEG conversion
- **URL Launcher**: For opening links
- **Video Player**: `video_player` for inline video
- **Audio Player**: `audioplayers` for audio messages
- **Cache Manager**: `flutter_cache_manager` + custom `MediaCacheService`

---

## 10. Media Manager

**File**: `lib/features/chat/pages/media_manager_page.dart`

### Screen Description
Full-screen cached media browser for a chat room. Title: "Media & Files"

### Tabs
1. **Media** — Images and videos
2. **Audio** — Audio recordings
3. **Docs** — Documents (PDFs, text files, etc.)

### User Interactions
- Toggle grid/list view
- Tap image → full-screen view
- Tap video → play video
- Tap document → open in PDF viewer or text viewer
- Download button → saves to device
  - iOS: Documents directory (Files app)
  - Android: `/storage/emulated/0/Download`
- Pull-to-refresh

### State Transitions
- Loading (prefetch all media) → Loaded / Empty per category

---

## 11. PDF Viewer

**Files**: `lib/features/chat/pages/pdf_viewer_page.dart`, `lib/features/chat/pages/pdf_viewer_page_web.dart`

### Screen Description
Full-screen PDF viewer with navigation and search.

### User Interactions
- Page navigation (prev/next buttons, page counter)
- Zoom controls
- Search toggle → search bar with text input, next/prev match navigation
- Open externally via URL launcher

### Platform Behavior
- **Mobile/Desktop**: Uses `SfPdfViewer` from Syncfusion with file caching via `MediaCacheService`
- **Web**: Separate `PDFViewerPageWeb` with URL-based loading / url_launcher fallback

### State Transitions
- Loading → Loaded / Error
- Caching from URL → cached file

---

## 12. Text/Code Viewer

**File**: `lib/features/chat/pages/text_viewer_page.dart`

### Screen Description
Full-screen text/code file viewer with search and formatting controls.

### User Interactions
- Font size adjustment (increase/decrease)
- Toggle line numbers
- Toggle word wrap
- Search bar with next/prev match
- Copy text to clipboard

### Platform Behavior
- **Mobile/Desktop**: Load from local file or cached URL
- **Web**: Direct HTTP fetch of URL content

### State Transitions
- Loading → Content loaded / Error

---

## 13. Calling — Audio/Video Calls

**Files**: `lib/features/calling/pages/call_page_v2.dart`, `lib/features/calling/pages/call_controller.dart`, `lib/features/calling/services/` (20+ files)

### Screen Description
Full-screen call interface. Views depend on call state.

### Call States (`CallState`)
| State | View | Description |
|-------|------|-------------|
| `initial` | — | Controller created |
| `connecting` | `CallConnectingView` | Connecting to peer, pulsing avatar |
| `connected` | `CallRoomView` (video) or `AudioCallView` (audio) | Active call |
| `reconnecting` | Status bar overlay | Network reconnection |
| `ended` | Auto-pop | Call completed |
| `failed` | Error snackbar, auto-pop | Call failed |

### CallConnectingView
- Partner name, profile picture (pulsing animation)
- "Connecting..." status text
- End call button (red)

### CallRoomView (Video Calls)
**User Interactions**:
- Remote video (full-screen) / Remote video placeholder (avatar when video off)
- Local video preview (draggable PiP overlay - 120x160)
- Control buttons bar:
  - Mute/unmute microphone
  - Toggle camera on/off
  - Switch camera (front/back)
  - Toggle speaker/earpiece
  - Audio device selector (bluetooth, headset, speaker, earpiece)
  - End call (red button)
- Call duration display (HH:MM:SS)
- Network quality indicator
- Mute indicator badge (shows when remote user muted)
- Call status bar (reconnecting, etc.)
- Auto-hide controls after 5 seconds

### AudioCallView
- Partner name, profile picture, breathing avatar animation
- Duration display
- Control buttons: mute, speaker, audio device select, end call

### Minimized Call View
- Floating draggable PiP window (shows mini view of active call)
- Tap to restore full-screen
- Drag to reposition

### Call Flow (Caller)
1. `CallCoordinator.startCall()` — rate limiting (2s), auth check
2. `CallNavigationCoordinator.initiateCall()` — creates `CallController`
3. `CallController.connect()`:
   - Create room via `SignalingService` (Firestore or LiveKit)
   - Initialize media (camera/mic via `MediaManager`)
   - Wait for remote peer to join
   - Call timeout timer (30s configurable via Remote Config)
4. On connected: Start duration timer
5. On ended: Cleanup, pop page, show rating prompt if eligible

### Call Flow (Callee)
1. Incoming call detected via Firestore listener or CallKit VoIP push
2. `IncomingCallBanner` or `IncomingCallDialog` shown
3. User accepts → `CallController` joins existing room
4. User declines → call rejected

### Post-Call Rating
- After call ends, if caller AND call lasted ≥30 seconds:
  - Check if already rated this call
  - Show `RatingPage` as fullscreen dialog

### Media Management
- **LiveKit**: `livekit_client` for WebRTC via LiveKit SFU
- **WebRTC**: `flutter_webrtc` for peer-to-peer (configurable via Remote Config `call_provider`)
- Camera switching (front/back)
- Audio device selection (bluetooth, headset, speaker, earpiece)
- Wakelock during calls (`wakelock_plus`)
- HFP call controls (Bluetooth headset buttons)

### Resilience
- Circuit breaker pattern
- Retry manager
- Network quality monitoring
- Call quality analyzer
- Reconnection handling

### Platform-Specific
- **iOS**: CallKit integration (VoIP push for background incoming calls)
- **Android**: FCM for incoming call notifications
- **Web**: WebRTC error filter for microtask scheduling issues

### Analytics
- Call analytics (duration, quality, end reason)
- Network quality metrics

---

## 14. Call History

**File**: `lib/features/calling/pages/call_history_page.dart`

### Screen Description
List of all past call records with selection mode.

### User Interactions
- Each call card shows: partner name, profile picture, call direction (incoming/outgoing), duration, timestamp, call type (audio/video)
- Tap call card → context options (call back, chat, rate)
- Long press → enters selection mode
- **Selection mode**:
  - Checkbox per item
  - Select all / Deselect all toggle
  - Delete selected (with confirmation dialog)
- **AppBar actions** (normal mode):
  - More menu: "Select", "Clear All"
- **Clear All** → confirmation dialog → deletes all call history

### State Transitions
- Loading (shimmer skeleton) → Loaded / Error / Empty
- Normal mode ↔ Selection mode

### Per-Call Actions
- Call back (audio/video)
- Open chat with partner
- Rate expert (shows `RatingPage`)

---

## 15. Incoming Call Handling

**Files**: `lib/features/calling/widgets/call_overlay.dart`, `lib/features/calling/widgets/incoming_call_banner.dart`, `lib/features/calling/widgets/incoming_call_dialog.dart`, `lib/features/calling/services/incoming_call_strategy.dart`

### CallOverlay (Global Widget)
- Wraps entire app (in `MaterialApp.builder`)
- Listens to `CallNavigationCoordinator` and `IncomingCallManager`
- Shows three overlay types based on state:
  1. **Incoming call banner** (compact top banner, expandable to full-screen)
  2. **Active call minimized PiP** (draggable floating window)
  3. **Full-screen call page** (push navigation)

### Incoming Call Banner (`IncomingCallBanner`)
- iOS CallKit-style design
- Compact mode: shows at top with caller name, accept/decline buttons
- Expandable: tap to expand to full-screen with profile picture, animated accept/decline
- Fetches caller profile picture from Firestore via `UserCacheService`
- Auto-dismiss on timeout or answer

### Incoming Call Dialog (`IncomingCallDialog`)
- Modal dialog alternative (used as fallback)
- Profile picture, "Video Call" / "Audio Call" title
- Accept (green) and Decline (red) buttons
- Ringing animation on accept button

### Incoming Call Strategy
- **iOS**: VoIP push → CallKit native UI → Firestore fallback for in-app
- **Android/Web**: Firestore listener → Flutter dialog/banner
- Duplicate prevention: tracks call IDs handled by CallKit to prevent double display
- Call tracking expiration: 2 minutes

---

## 16. User Profile Management

**Files**: `lib/features/profile/pages/user_profile_page.dart`, `lib/features/profile/pages/skill_selection_page.dart`, `lib/features/profile/widgets/` (5 files), `lib/features/profile/services/` (3 files)

### User Profile Page

**Screen Sections**:
1. **Profile Picture** — Tap to show options
2. **Display Name** — Text field with profanity filter, max 32 chars
3. **Role** — Read-only chips (Expert/Merchant/Other)
4. **Expert-only sections**:
   - Bio text field (profanity filtered)
   - Skills card (tap → skill selection modal)
   - Selected skills as Chips
   - Languages FilterChip grid (11 languages)
5. **Storage Section** — App cache size, "Clear" button
6. **Security Section** (if biometric available):
   - Toggle "Enable Biometric Login"
   - Shows biometric type name (Face ID, Touch ID, Fingerprint)
7. **"Save Profile" button**

### Profile Picture Options (Action Sheet)
- **Take Photo** — uses camera
- **Choose from Gallery** — uses image_picker
- **Delete Photo** — confirmation dialog → removes from Firebase Storage

### Skill Selection Modal
- Search bar
- Skills grouped by category (expandable)
- Checkbox per skill
- Selected count display
- Refresh skills button

### Storage Section
- Shows total app cache size (calculated from `MediaCacheService`)
- "Clear" button → confirmation dialog:
  - Warns about clearing cached media, downloads, recordings, thumbnails
  - "Clear" action → `clearAllCaches()` → shows new size

### State Transitions
- Loading profile → Loaded / Error (with retry)
- Saving profile → Success (pop with result) / Error
- Loading/refreshing skills
- Uploading profile picture (progress)
- Deleting profile picture

### Profile Menu (PopupMenu in Home AppBar)

**File**: `lib/features/profile/widgets/profile_menu.dart`

**Menu Items**:
| Item | Action |
|------|--------|
| "Hi [userName]" | Header (disabled) |
| Update Profile | Opens `UserProfilePage` |
| Notifications On/Off | Toggle notification preference (with switch indicator) |
| Help Center | Opens `SupportHubPage` |
| Admin Dashboard | Opens `AdminDashboardPage` (only for Support/Admin/SuperAdmin roles) |
| Delete Account | Confirmation → account deletion flow |
| Log Out | Confirmation dialog → `signOut()` → clear profile → navigate to `PhoneAuthPage` |

### Delete Account Flow
- Confirmation dialog
- Re-authentication if needed
- FCM token cleanup
- VoIP token cleanup
- User presence cleanup
- Firebase Auth delete
- Navigate to phone auth

---

## 17. Admin Dashboard

**File**: `lib/features/admin/pages/admin_dashboard_page.dart`

### Access Control
- `AdminRouteGuard` wrapper with `minimumRole: UserRole.support`
- Roles hierarchy: User < Support < Admin < SuperAdmin

### Screen Description
Dashboard with 4 bottom nav tabs: Tickets, Users, Skills, FAQs. Pill-shaped floating bottom navigation.

### Tab 0: Ticket Dashboard
- Summary stats cards: Total tickets, Open, In Progress, Closed
- Quick filters: "Urgent/High Only", "Unassigned Only"
- Recent tickets list
- Tap stat card → filtered `AdminTicketsPage`
- Tap ticket → `AdminTicketDetailPage`

### Tab 1: Users (via `AdminUsersContent`)
- User list with search
- User details bottom sheet
- Role management

### Tab 2: Skills (via `AdminSkillsContent`)
- Skills list
- Quick actions (activate/deactivate, edit, delete)

### Tab 3: FAQs (via `AdminFaqsContent`)
- FAQ list
- Quick actions (publish/unpublish, edit, delete)

### App Bar Actions
- Back button
- Refresh button (refreshes current tab)
- Dynamic title based on selected tab

---

## 18. Admin — Ticket Management

**Files**: `lib/features/admin/pages/admin_tickets_page.dart`, `lib/features/admin/pages/admin_ticket_detail_page.dart`, `lib/features/admin/pages/admin_ticket_detail_page_refactored.dart`

### Tickets List Page
**Access**: Support, Admin, SuperAdmin

**User Interactions**:
- search bar (search tickets)
- Filter toolbar:
  - Status filter (Open, In Progress, Waiting, Resolved, Closed)
  - Priority filter (Low, Medium, High, Urgent)
  - Unassigned only toggle
- Ticket cards with: ticket number, subject, status chip, priority badge, timestamp
- Tap ticket → `AdminTicketDetailPage`
- Scrollable with pagination (load more on scroll)

### Ticket Detail Page
**Access**: Support, Admin, SuperAdmin

**Two tabs**: Messages | Internal Notes

**User Interactions**:
- View ticket info header (status, priority, category, created date, user info)
- Description (expandable/collapsible)
- **Messages tab**: conversation thread, reply input
- **Internal Notes tab**: admin-only notes (not visible to users)
- **Admin actions**:
  - Change status (dropdown)
  - Change priority (dropdown)
  - Assign to self
  - Add reply message
  - Add internal note
- Attachments viewer

### State Transitions
- Loading → Loaded / Error
- Sending reply → Success / Error
- Status change → Optimistic update / Error

---

## 19. Admin — User Management

**Files**: `lib/features/admin/pages/admin_users_page.dart`, `lib/features/admin/widgets/user/` (3 files)

### Screen Description
**Access**: Admin, SuperAdmin

### User Interactions
- Search users by name/email
- User list items showing: name, role badges, suspended status
- Tap user → `UserDetailsSheet` (modal bottom sheet)
  - Full user info
  - Edit Roles button
  - Suspend/Unsuspend button
- **Role Editor** (bottom sheet):
  - Toggle roles: Expert, Merchant, Support, Admin, SuperAdmin
  - SuperAdmin can assign Admin roles
- **Suspend User** → Confirmation dialog → suspend with reason
- **Unsuspend User** → Confirmation dialog

### Role Badges
- Color-coded badge per role (Expert=green, Merchant=blue, Support=orange, Admin=red, SuperAdmin=purple)

---

## 20. Admin — Skills Management

**Files**: `lib/features/admin/pages/admin_skills_page.dart`, `lib/features/admin/pages/admin_skill_editor_page.dart`

### Skills List Page
**Access**: Admin, SuperAdmin

**Two tabs**: Categories | All Skills

**User Interactions**:
- Stats cards: Total skills, Active, Categories
- Per skill: Activate/Deactivate toggle, Edit, Delete (with confirmation)
- Create new skill → `AdminSkillEditorPage`
- Create new category
- Delete category (with empty check)

### Skill Editor Page
**Form Fields**:
- Skill name (required)
- Description
- Category dropdown (from existing categories)
- Tags (comma-separated)
- Active toggle

### State Transitions
- Loading → Loaded / Error
- Saving → Success (pop) / Error
- Toggling active state
- Deleting (confirmation → delete)

---

## 21. Admin — FAQ Management

**Files**: `lib/features/admin/pages/admin_faqs_page.dart`, `lib/features/admin/pages/admin_faq_editor_page.dart`

### FAQ List Page
**Access**: Support, Admin, SuperAdmin

**Two tabs**: Categories | All FAQs

**User Interactions**:
- Stats cards: Total FAQs, Published, Categories
- Per FAQ: Toggle published (show/hide from users), Edit, Delete (with confirmation)
- Create new FAQ → `AdminFaqEditorPage`
- Create new category
- Delete category (with "move FAQs first" check)

### FAQ Editor Page
**Form Fields**:
- Question (required)
- Answer (required, multiline)
- Category dropdown
- Tags (comma-separated)
- Published toggle

---

## 22. Support / Help Center

**Files**: `lib/features/support/pages/` (5 files), `lib/features/support/widgets/` (10 files), `lib/features/support/services/` (7 files)

### Support Hub Page
**Screen Description**: Main help center with quick actions and FAQ browser.

**User Interactions**:
- Quick Action: **New Ticket** → `NewTicketPage`
- Quick Action: **My Tickets** → `TicketListPage` (with unread count badge)
- **FAQ Section**: Categorized FAQ list, expand to see answers
- FAQ feedback (helpful/not helpful)

### New Ticket Page
**Form Fields**:
1. **Ticket Type** selector (`TicketTypeSelector`): Bug, Feature Request, Question, Other
2. **Category** dropdown (`CategoryDropdown`)
3. **Subject** text field (required)
4. **Description** text field (required, multiline)
5. **Attachments** (`AttachmentPicker`):
   - Pick from Gallery
   - Pick file
   - Max 5 attachments
   - Preview with remove option
6. **Submit button**

**State Transitions**:
- Idle → Submitting → Success (pop with result + snackbar) / Error (banner)
- Auto-collects device info (model, OS, app version via `DeviceInfoService`)

### Ticket List Page
**User Interactions**:
- List of user's tickets (cards with subject, status chip, timestamp)
- Tap ticket → `TicketDetailPage`
- "+" button → new ticket
- Pull-to-refresh

**State Transitions**:
- Loading (shimmer skeleton) → Loaded / Error / Empty (with empty state widget)

### Ticket Detail Page
**Screen Description**: Conversation-style ticket view

**User Interactions**:
- Ticket info header (number, status chip, priority)
- Message thread (user + support replies)
- Message input for replies
- **Satisfaction rating** — can rate resolved ticket (1-5 stars dialog)
- Status updates visible in thread

**State Transitions**:
- Loading → Loaded / Error
- Sending message → scroll to bottom
- canRate flag for resolved tickets

### Support Analytics
- Track hub opened, ticket created, ticket viewed, message sent
- Ticket categories and priorities tracked

---

## 23. Ratings & Reviews

**Files**: `lib/features/ratings/pages/` (2 files), `lib/features/ratings/widgets/` (3 files), `lib/features/ratings/services/rating_service.dart`, `lib/features/ratings/utils/post_call_rating_prompt.dart`

### Rating Page
**Screen Description**: Star rating submission for an expert.

**User Interactions**:
- Expert name display
- Session date (if provided)
- **Star rating input** (1-5 stars, tap to select)
  - Labels: 1=Poor, 2=Fair, 3=Good, 4=Very Good, 5=Excellent
- **Comment field** (optional, max 200 chars)
- **Anonymous toggle** (checkbox)
- **Submit button** (disabled until stars selected, or while loading/submitted)

**State Transitions**:
- Idle → Selected stars → Writing comment → Submitting → Success (pop) / Error

### Expert Reviews Page
**Screen Description**: All reviews for an expert with summary header.

**Content**:
- Rating summary (average, total count, star distribution)
- Paginated review cards
- Each card: star rating, comment, date, reviewer name (or "Anonymous")
- Pull-to-refresh
- Scroll-based pagination (load more at 200px from bottom)

**State Transitions**:
- Loading (shimmer) → Loaded / Error / Empty

### Post-Call Rating Prompt
**Trigger**: After call ends, if:
- User was the caller (not callee)
- Call lasted ≥30 seconds
- User hasn't already rated this call

**Flow**:
1. 300ms delay after call page pops
2. Check `ratingService.hasRatedBooking(callId)`
3. If eligible → navigate to `RatingPage` via global navigator key

### Firestore Rules
- Anyone authenticated can read ratings
- Users can create ratings (immutable, 1-5 stars required)
- No update or delete allowed

---

## 24. Push Notifications

**Files**: `lib/shared/services/notification_service.dart`, `lib/shared/services/firebase_messaging_service.dart`, `lib/shared/services/pending_notification_handler.dart`

### Notification Channels (Android)
- Chat messages
- Call notifications (high importance)
- System notifications

### Notification Types Handled
| Type | Action on Tap |
|------|---------------|
| `new_message` | Navigate to `ChatConversationPage` with sender |
| `incoming_call` | Navigate to Call History (call likely ended by tap time) |
| `missed_call` | Navigate to Call History |
| `expert_request` | Navigate to chat with requester |
| `support_message` | Navigate to `TicketDetailPage` |
| `support_status_change` | Navigate to `TicketDetailPage` |

### Cold Start Notification
- `getInitialMessage()` called in `main()` before `runApp`
- Stored via `PendingNotificationHandler.setPendingMessage()`
- Processed after splash screen loads via `processPendingNotification()`

### Foreground Notifications
- iOS: alert, badge, sound enabled via `setForegroundNotificationPresentationOptions`
- Android: `flutter_local_notifications` displays local notification
- Chat messages in current room suppressed via presence system

### Token Management
- FCM token saved to user document in Firestore
- Token refresh listener updates Firestore
- Old token replacement on refresh
- Token cleanup on logout
- VoIP token (iOS) managed via `VoIPTokenRepository`

### Badge Management
- Badge cleared on app resume (foreground)
- Badge cleared on app startup

---

## 25. User Presence System

**File**: `lib/features/chat/services/user_presence_service.dart`

### Purpose
- Track online/offline status
- Track which chat room user is currently viewing
- Enable Cloud Functions to suppress push notifications for active chat

### Implementation
- **Firebase Realtime Database**: `presence/{userId}` document
- Fields: `isOnline`, `currentChatRoomId`, `lastUpdated`
- `onDisconnect()` handler: automatically sets offline when client disconnects (even if app killed)
- Listens to `.info/connected` for connection state

### State Updates
- `initialize()` — called after auth
- `enterChatRoom(roomId)` — when opening a chat
- `leaveChatRoom()` — when leaving a chat
- `setAppInForeground()` — on app resume
- `setAppInBackground()` — on app pause/inactive
- `dispose()` — on logout

---

## 26. Firebase Services Used

| Service | Purpose | Collections/Paths |
|---------|---------|-------------------|
| **Firebase Auth** | Phone authentication, user management | — |
| **Cloud Firestore** | Main database (named: `green-hive-db`) | `users`, `chat_rooms`, `active_calls`, `livekit_rooms`, `call_history`, `skills`, `products`, `faqs`, `faq_categories`, `faq_feedback`, `support_tickets`, `support_counters`, `support_analytics`, `ratings`, `admin_audit_logs` |
| **Firebase Storage** | Media files (chat, profile pictures, support attachments) | — |
| **Firebase Realtime Database** | User presence tracking | `presence/{userId}` |
| **Firebase Cloud Messaging** | Push notifications (chat, calls, support) | FCM tokens in user documents |
| **Firebase Remote Config** | Dynamic configuration (call timeouts, feature flags, URLs, TURN servers) | 50+ config keys |
| **Firebase Analytics** | Event tracking, screen views, user properties | Custom events |
| **Firebase Crashlytics** | Crash reporting, non-fatal errors (mobile only) | — |
| **Firebase Performance** | App performance monitoring, custom traces | Media upload traces, screen load traces |
| **Cloud Functions** | Backend logic (notification triggers, call management, etc.) | `functions/` directory (TypeScript) |

### Key Firestore Collections Structure

```
users/{userId}
  └─ rooms/{roomId}           // unread count per room
  └─ incoming_calls/{callId}  // real-time incoming call notification
  └─ call_history/{callId}    // per-user call records

chat_rooms/{roomId}
  └─ messages/{messageId}     // chat messages

active_calls/{callId}
  └─ ice_candidates/{id}      // WebRTC ICE signaling

livekit_rooms/{roomId}
  └─ ice_candidates/{id}      // LiveKit room signaling

support_tickets/{ticketId}
  └─ messages/{messageId}     // ticket conversation
  └─ internal_notes/{noteId}  // admin-only notes
```

### Firestore Rules Role System
- `isAuthenticated()` — basic auth check
- `isExpert()` — checks `Expert` in `roles` array
- `isSupport()` — checks `Support`, `Admin`, or `SuperAdmin`
- `isAdmin()` — checks `Admin` or `SuperAdmin`
- `isSuperAdmin()` — checks `SuperAdmin`
- Role changes restricted: only SuperAdmin can modify admin roles

---

## 27. Device Capabilities Used

| Capability | Package | Usage |
|------------|---------|-------|
| **Camera** | `camera` | Inline photo capture in chat input, profile photo |
| **Microphone** | `record` | Audio message recording in chat |
| **Gallery/Photos** | `image_picker` | Profile picture, chat image attachments |
| **File System** | `file_picker`, `path_provider` | Document attachments, file downloads, caching |
| **Biometric Auth** | `local_auth` | Face ID / Touch ID / Fingerprint for app lock |
| **Push Notifications** | `firebase_messaging`, `flutter_local_notifications` | Chat, call, support notifications |
| **Shake Detection** | `shake_detector` | Shake to toggle verbose debug logging |
| **Screen Wake Lock** | `wakelock_plus` | Keep screen on during calls |
| **WebRTC** | `flutter_webrtc`, `livekit_client` | Audio/video calling |
| **Shared Preferences** | `shared_preferences` | Biometric settings, FCM token cache |
| **Device Info** | `device_info_plus` | Support ticket device info collection |
| **Package Info** | `package_info_plus` | App version in support tickets |
| **URL Launcher** | `url_launcher` | Open links from chat, external file viewing |
| **Image Compression** | `flutter_image_compress` | HEIC→JPEG conversion, profile picture optimization |
| **Video Thumbnails** | `video_thumbnail` | Generate thumbnails for video messages |
| **Bluetooth Audio** | HFP call control service | Bluetooth headset button handling (answer/hangup) |
| **Permissions** | `permission_handler` | Camera, microphone, notification permission requests |

---

## 28. Cross-Cutting Concerns

### Error Handling (`ErrorHandler`)
- `handle<T>()` — generic async with fallback
- `executeAsync()` / `executeVoid()` — with operation name, context, optional snackbar
- All service calls wrapped in error handlers
- Errors suppressed for non-critical operations (notifications, analytics)

### Profanity Filtering (`ProfanityFilterService`)
- Applied to: display names, bios, chat messages
- Substring matching for display names
- Loads profanity word lists from `assets/profanity/`
- Custom allowlist for false positives
- Text normalization (l33tspeak, unicode, etc.)
- `ProfanityFilteredTextField` widget used throughout

### Logging (`AppLogger`)
- Debug mode: `DebugAppLogger` (full output)
- Production: `ProductionAppLogger` (limited output)
- Verbose mode toggle via device shake
- Tagged logging per module
- Supports: debug, info, warning, error levels

### Analytics (`AnalyticsService`)
- Screen view tracking (automatic via `AnalyticsRouteObserver`)
- Custom events (call started, message sent, ticket created, etc.)
- Performance traces (media upload, screen load)
- Crashlytics context breadcrumbs (mobile only)

### Caching
- `MediaCacheService` — file-based caching for chat media
- `UserCacheService` — in-memory user profile cache
- `flutter_cache_manager` — network image caching
- `cached_network_image` — profile pictures, chat images

### Remote Config (Feature Flags)
- `enable_video_calling` — toggle video call feature
- `enable_screen_sharing` — toggle screen sharing (currently false)
- `enable_call_recording` — toggle call recording (currently false)
- `enable_camera_switching` — toggle camera switch
- `call_provider` — `'livekit'` or `'webrtc'`
- Timing configs: call timeout, connection timeout, ICE debounce
- Video/audio quality settings
- TURN/LiveKit server URLs
- Error messages

### Event Bus (`EventBus`)
- `profileUpdated` event — triggers Home refresh, profile picture update
- Loose coupling between features

### Upload Manager (Global)
- Background media uploads that persist across navigation
- Multiple simultaneous uploads
- Progress tracking per upload
- Room-scoped upload queries
- Cancellation support
- `GlobalUploadIndicator` widget shows upload status

---

## 29. Platform-Specific Behavior

### iOS
- **CallKit** integration for native incoming call UI via VoIP push
- **BiometricAuth**: Face ID / Touch ID
- **File saving**: Documents directory (accessible via Files app)
- **Foreground notifications**: System alert, badge, sound
- **VoIP token**: Registered for CallKit push notifications
- **HEIC image handling**: Auto-conversion to JPEG
- **Notification badging**: Cleared on app resume

### Android
- **Incoming calls**: FCM push → local notification → Flutter dialog
- **BiometricAuth**: Fingerprint / Face Unlock
- **File saving**: `/storage/emulated/0/Download`
- **Notification channels**: Chat, Calls (high importance), System
- **Auto-verification**: SMS auto-read for OTP

### Web
- **WebRTC error filter**: Suppresses `InvalidStateError` during call termination
- **No biometric**: Biometric auth disabled on web
- **No CallKit**: Firestore listener only for incoming calls
- **PDF viewer**: Separate `PDFViewerPageWeb` (URL-based)
- **Text viewer**: Direct HTTP fetch (no file caching)
- **Notifications**: FCM web token, browser notification permission
- **No file system**: Limited file operations
- **No shake detection**: Shake handler may not work on web

### macOS/Windows
- Firebase configured (same project `greenhive-service`)
- Desktop-specific file paths for downloads
- Otherwise same as mobile behavior

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Feature directories | 12 |
| Page/Screen files | 30+ |
| Widget files | 70+ |
| Service files | 50+ |
| View Model files | 15+ |
| Named routes | 9 |
| Firestore collections | 14+ |
| Firebase services | 10 |
| Device capabilities | 16+ |
| Remote Config flags | 50+ |
| Bottom nav tabs (Home) | 4 |
| Bottom nav tabs (Admin) | 4 |
| Notification types | 6 |
| User roles | 5 (User, Expert, Merchant, Support, Admin, SuperAdmin) |
| Call states | 6 |
| Message types | 7+ (text, image, video, audio, document, call log, uploading) |
