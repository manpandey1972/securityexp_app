# Customer Support System - Implementation Plan

**Version:** 1.0  
**Status:** Approved for Implementation  
**Created:** January 28, 2026  
**Based On:** SUPPORT_FEEDBACK_SYSTEM_DESIGN.md  
**Estimated Duration:** 3-4 weeks  

---

## 📋 Executive Summary

This document outlines the phased implementation plan for the Customer Support, Feedback & Issue Reporting System. The design has been architected to:

- **Align with existing patterns** - Follows GreenHive's layered architecture
- **Enable scalability** - Cloud Functions handle ticket processing
- **Ensure security** - Comprehensive Firestore security rules
- **Provide excellent UX** - Intuitive submission flow with minimal friction

---

## 🎯 Implementation Phases Overview

| Phase | Focus | Duration | Key Deliverables |
|-------|-------|----------|------------------|
| **Phase 1** | Foundation | 4 days | Data models, repositories, Firestore setup |
| **Phase 2** | Core Service | 4 days | SupportService, ticket submission |
| **Phase 3** | Ticket Management UI | 4 days | List page, detail page |
| **Phase 4** | Messaging | 4 days | Conversation threading, real-time updates |
| **Phase 5** | Cloud Functions | 3 days | Triggers, notifications, auto-close |
| **Phase 6** | Polish | 3 days | Ratings, analytics, testing |

**Total: ~22 working days (3-4 weeks)**

---

## 📦 Phase 1: Foundation - Data Models & Repository Layer

**Duration:** 4 days  
**Dependencies:** None  
**Deliverables:** Data models, repositories, Firestore indexes, security rules

### Day 1-2: Data Models

#### Task 1.1: Create Enum Definitions

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/data/models/support_enums.dart` | P0 | 2h |

**Enums to implement:**
- `TicketType` - bug, featureRequest, feedback, support, account, payment
- `TicketCategory` - calling, chat, profile, notifications, experts, performance, other
- `TicketStatus` - open, inReview, inProgress, resolved, closed
- `TicketPriority` - critical, high, medium, low
- `MessageSenderType` - user, support, system
- `SystemMessageType` - statusChange, assignmentChange, autoResponse, ticketCreated, ticketResolved, ticketClosed

**Acceptance Criteria:**
- [ ] All enums have `displayName` getters
- [ ] `TicketType` has `emoji` getter
- [ ] `TicketStatus` has `color` getter
- [ ] `TicketPriority.fromTicketType()` factory method works
- [ ] JSON serialization methods (toJson/fromJson)

#### Task 1.2: Create DeviceContext Model

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/data/models/device_context.dart` | P0 | 2h |

**Fields:**
- platform, osVersion, appVersion, buildNumber
- deviceModel, locale, timezone, screenSize

**Acceptance Criteria:**
- [ ] `fromJson` / `toJson` methods
- [ ] `DeviceContext.capture()` factory using device_info_plus
- [ ] Unit tests for serialization

#### Task 1.3: Create TicketAttachment Model

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/data/models/ticket_attachment.dart` | P0 | 1h |

**Fields:**
- id, url, fileName, fileSize, mimeType, uploadedAt

**Acceptance Criteria:**
- [ ] Immutable class
- [ ] JSON serialization
- [ ] Unit tests

#### Task 1.4: Create SupportTicket Model

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/data/models/support_ticket.dart` | P0 | 3h |

**Fields:** (See design doc for full list)
- Identifiers: id, ticketNumber
- User info: userId, userEmail, userName
- Content: type, category, subject, description, attachments
- Context: deviceContext
- Status: status, priority, assignedTo, tags
- Timestamps: createdAt, updatedAt, resolvedAt, closedAt, lastActivityAt
- Metadata: messageCount, hasUnreadSupportMessages
- Resolution: resolution, resolutionType, userSatisfactionRating, userSatisfactionComment

**Acceptance Criteria:**
- [ ] `fromJson` / `toJson` methods
- [ ] `copyWith` method
- [ ] Computed properties: `isOpen`, `canReply`
- [ ] Unit tests with 100% coverage

#### Task 1.5: Create SupportMessage Model

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/data/models/support_message.dart` | P0 | 2h |

**Acceptance Criteria:**
- [ ] Full JSON serialization
- [ ] Computed properties: `isSystemMessage`, `isFromSupport`, `isFromUser`, `isRead`
- [ ] Unit tests

#### Task 1.6: Create Barrel Export

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/data/models/models.dart` | P0 | 0.5h |

```dart
export 'support_enums.dart';
export 'device_context.dart';
export 'ticket_attachment.dart';
export 'support_ticket.dart';
export 'support_message.dart';
```

### Day 3: Repositories

#### Task 1.7: Create SupportRepository

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/data/repositories/support_repository.dart` | P0 | 4h |

**Methods:**
```dart
// Ticket CRUD
Future<SupportTicket?> getTicket(String ticketId);
Future<Result<SupportTicket, SupportError>> createTicket(SupportTicket ticket);
Future<Result<void, SupportError>> updateTicket(String ticketId, Map<String, dynamic> updates);

// Queries
Future<Result<List<SupportTicket>, SupportError>> getTicketsByUser({
  required String userId,
  TicketStatus? statusFilter,
  TicketType? typeFilter,
  int limit = 20,
  DocumentSnapshot? startAfter,
});

// Real-time
Stream<SupportTicket?> watchTicket(String ticketId);

// Messages
Future<Result<SupportMessage, SupportError>> addMessage(String ticketId, SupportMessage message);
Stream<List<SupportMessage>> watchMessages(String ticketId);
Future<void> markUserMessagesAsRead(String ticketId);
```

**Acceptance Criteria:**
- [ ] Follows existing repository patterns (see ExpertRepository)
- [ ] Uses `ErrorHandler` for error handling
- [ ] Uses `AppLogger` for logging
- [ ] Pagination support with `startAfter`
- [ ] Unit tests with mocked Firestore

#### Task 1.8: Create SupportAttachmentRepository

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/data/repositories/support_attachment_repository.dart` | P0 | 3h |

**Methods:**
```dart
Future<Result<List<TicketAttachment>, SupportError>> uploadAttachments({
  required String ticketId,
  required List<File> files,
  String? subPath,
});

Future<String> getDownloadUrl(String path);
```

**Acceptance Criteria:**
- [ ] Upload to Firebase Storage at `support/{ticketId}/`
- [ ] Generate unique file IDs
- [ ] Return URLs after upload
- [ ] Progress callback support (optional)

### Day 4: Firestore Setup

#### Task 1.9: Update Firestore Indexes

| File | Priority | Est. |
|------|----------|------|
| `firestore.indexes.json` | P0 | 1h |

**Indexes to add:**
```json
{
  "collectionGroup": "support_tickets",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "support_tickets",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "lastActivityAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "messages",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "ticketId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "ASCENDING" }
  ]
}
```

**Acceptance Criteria:**
- [ ] Indexes added to `firestore.indexes.json`
- [ ] Deployed with `firebase deploy --only firestore:indexes`
- [ ] Verified queries work without warnings

#### Task 1.10: Update Firestore Security Rules

| File | Priority | Est. |
|------|----------|------|
| `firestore.rules` | P0 | 2h |

**Acceptance Criteria:**
- [ ] Rules from design doc implemented
- [ ] Users can only read own tickets
- [ ] Users can only create tickets with own userId
- [ ] Users can only update satisfaction rating
- [ ] Messages subcollection properly secured
- [ ] Rules tested with Firebase emulator

#### Task 1.11: Update Storage Rules

| File | Priority | Est. |
|------|----------|------|
| `storage.rules` | P0 | 1h |

```javascript
match /support/{ticketId}/{allPaths=**} {
  allow read: if request.auth != null;
  allow write: if request.auth != null 
               && request.resource.size < 10 * 1024 * 1024
               && request.resource.contentType.matches('image/.*|text/.*|application/pdf');
}
```

---

## ⚙️ Phase 2: Core Service & Ticket Submission

**Duration:** 4 days  
**Dependencies:** Phase 1 complete  
**Deliverables:** SupportService, DeviceInfoService, ticket submission UI

### Day 5: Services

#### Task 2.1: Create DeviceInfoService

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/domain/services/device_info_service.dart` | P0 | 2h |

**Acceptance Criteria:**
- [ ] Captures platform, OS version, device model
- [ ] Gets app version and build number from package_info_plus
- [ ] Gets locale and timezone
- [ ] Gets screen dimensions
- [ ] Handles web platform gracefully

#### Task 2.2: Create SupportService - Core

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/domain/services/support_service.dart` | P0 | 4h |

**Methods to implement (Day 1):**
- `createTicket()` - Full implementation with validation
- `getUserTickets()` - List with filters
- `getTicketById()` - Single ticket with ownership check

**Acceptance Criteria:**
- [ ] Input validation (subject length, description length, attachment limits)
- [ ] Device context captured automatically
- [ ] Attachment upload orchestration
- [ ] Error handling with `Result<T, SupportError>` pattern
- [ ] Logging with `AppLogger`

### Day 6: Service Completion & Registration

#### Task 2.3: Complete SupportService

**Methods to implement:**
- `watchTicket()` - Real-time updates
- `watchTicketMessages()` - Message stream
- `replyToTicket()` - Add user message
- `markMessagesAsRead()` - Mark as read
- `rateSupportExperience()` - Post-resolution rating

**Acceptance Criteria:**
- [ ] All methods implemented per design
- [ ] Unit tests with 80%+ coverage

#### Task 2.4: Register Services in Service Locator

| File | Priority | Est. |
|------|----------|------|
| `lib/core/service_locator.dart` | P0 | 1h |

```dart
// Support Feature Services
sl.registerLazySingleton<DeviceInfoService>(() => DeviceInfoService());
sl.registerLazySingleton<SupportRepository>(() => SupportRepository(
  firestore: sl<FirestoreInstance>(),
  log: sl<AppLogger>(),
));
sl.registerLazySingleton<SupportAttachmentRepository>(() => SupportAttachmentRepository());
sl.registerLazySingleton<SupportService>(() => SupportService(
  repository: sl<SupportRepository>(),
  attachmentRepository: sl<SupportAttachmentRepository>(),
  deviceInfoService: sl<DeviceInfoService>(),
  notificationService: sl<NotificationService>(),
  log: sl<AppLogger>(),
));
```

### Day 7-8: Ticket Submission UI

#### Task 2.5: Create NewTicketViewModel

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/view_models/new_ticket_view_model.dart` | P0 | 3h |

**State:**
- selectedType, selectedCategory
- subject, description
- attachments (List<File>)
- isSubmitting, error

**Methods:**
- selectType(), selectCategory()
- updateSubject(), updateDescription()
- addAttachment(), removeAttachment()
- submit()

**Acceptance Criteria:**
- [ ] ChangeNotifier implementation
- [ ] Validation state computed
- [ ] Submit orchestrates service call
- [ ] Error handling and loading state

#### Task 2.6: Create TicketTypeSelector Widget

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/widgets/ticket_type_selector.dart` | P0 | 2h |

**Acceptance Criteria:**
- [ ] Displays all ticket types with emoji
- [ ] Selection highlighting
- [ ] Follows app theme
- [ ] Widget test

#### Task 2.7: Create CategoryDropdown Widget

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/widgets/category_dropdown.dart` | P0 | 1h |

#### Task 2.8: Create AttachmentPicker Widget

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/widgets/attachment_picker.dart` | P0 | 2h |

**Features:**
- Grid display of selected images
- Add button (camera/gallery)
- Remove button on each image
- Max 5 limit indicator

#### Task 2.9: Create NewTicketPage

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/pages/new_ticket_page.dart` | P0 | 4h |

**Flow:**
1. Step 1: Type selection (TicketTypeSelector)
2. Step 2: Form (category, subject, description, attachments)
3. Submit with loading state
4. Success → Navigate to ticket detail

**Acceptance Criteria:**
- [ ] Two-step flow as per wireframe
- [ ] Form validation
- [ ] Loading state during submission
- [ ] Success/error feedback
- [ ] Device info note shown
- [ ] Widget tests

---

## 🎨 Phase 3: Ticket Management UI

**Duration:** 4 days  
**Dependencies:** Phase 2 complete  
**Deliverables:** Ticket list page, ticket detail page, navigation

### Day 9-10: Ticket List Page

#### Task 3.1: Create TicketListViewModel

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/view_models/ticket_list_view_model.dart` | P0 | 3h |

**State:**
- tickets (List<SupportTicket>)
- statusFilter, isLoading, hasMore
- error

**Methods:**
- loadTickets(), loadMore()
- setStatusFilter()
- refresh()

**Acceptance Criteria:**
- [ ] Pagination support
- [ ] Filter by status
- [ ] Pull-to-refresh support
- [ ] Unit tests

#### Task 3.2: Create TicketCard Widget

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/widgets/ticket_card.dart` | P0 | 2h |

**Display:**
- Type emoji + subject
- Ticket number
- Status chip + last activity date
- Unread indicator
- Rate prompt for resolved tickets

**Acceptance Criteria:**
- [ ] Matches wireframe design
- [ ] Proper date formatting
- [ ] Widget test

#### Task 3.3: Create TicketStatusChip Widget

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/widgets/ticket_status_chip.dart` | P0 | 1h |

#### Task 3.4: Create TicketListPage

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/pages/ticket_list_page.dart` | P0 | 4h |

**Features:**
- Filter tabs (All, Open, Resolved, Closed)
- Ticket list with TicketCard
- Pull-to-refresh
- Infinite scroll pagination
- Empty state
- New ticket FAB

**Acceptance Criteria:**
- [ ] Filter tabs work correctly
- [ ] Pagination loads more on scroll
- [ ] Empty state when no tickets
- [ ] Navigation to ticket detail
- [ ] Navigation to new ticket

### Day 11-12: Ticket Detail Page

#### Task 3.5: Create TicketDetailViewModel

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/view_models/ticket_detail_view_model.dart` | P0 | 3h |

**State:**
- ticket (SupportTicket)
- messages (List<SupportMessage>)
- replyText, isReplying

**Methods:**
- loadTicket(), sendReply()
- subscribeToUpdates()

**Acceptance Criteria:**
- [ ] Real-time ticket updates
- [ ] Real-time message updates
- [ ] Reply submission
- [ ] Mark as read on view

#### Task 3.6: Create MessageBubble Widget

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/widgets/message_bubble.dart` | P0 | 3h |

**Types:**
- User message (aligned right, primary color)
- Support message (aligned left, surface color)
- System message (centered, bordered)

**Acceptance Criteria:**
- [ ] Different styling per sender type
- [ ] Attachment display
- [ ] Timestamp formatting
- [ ] Widget tests

#### Task 3.7: Create MessageInput Widget

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/widgets/message_input.dart` | P0 | 2h |

**Features:**
- Text input
- Attachment button
- Send button
- Disabled state when ticket closed

#### Task 3.8: Create TicketDetailPage

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/pages/ticket_detail_page.dart` | P0 | 4h |

**Sections:**
- Header: Subject, status, priority, category, created date
- Conversation: Message list
- Input: Message input (if ticket open)

**Acceptance Criteria:**
- [ ] Ticket info header
- [ ] Scrollable message list
- [ ] Real-time updates
- [ ] Reply functionality
- [ ] Disabled input for closed tickets

---

## 💬 Phase 4: Messaging & Real-time Updates

**Duration:** 4 days  
**Dependencies:** Phase 3 complete  
**Deliverables:** Complete messaging flow, push notification handling

### Day 13-14: Messaging Enhancement

#### Task 4.1: Implement Attachment Upload in Messages

| File | Priority | Est. |
|------|----------|------|
| `support_service.dart` | P0 | 2h |

**Acceptance Criteria:**
- [ ] Upload attachments with messages
- [ ] Progress indication
- [ ] Error handling

#### Task 4.2: Create AttachmentViewer Widget

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/widgets/attachment_viewer.dart` | P1 | 2h |

**Features:**
- Thumbnail display
- Tap to open full screen
- Support for images and PDFs

#### Task 4.3: Implement Read Receipts

| File | Priority | Est. |
|------|----------|------|
| Multiple | P1 | 2h |

**Acceptance Criteria:**
- [ ] Messages marked as read when viewed
- [ ] Ticket `hasUnreadSupportMessages` updated
- [ ] Unread indicator removed from list

### Day 15-16: Support Hub & Navigation

#### Task 4.4: Create SupportHubPage

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/pages/support_hub_page.dart` | P0 | 3h |

**Sections:**
- Quick actions: New ticket, View my tickets
- Ticket types grid (for quick submission)
- Recent tickets preview (last 3)

**Acceptance Criteria:**
- [ ] Clean landing page for support
- [ ] Quick navigation to common actions
- [ ] Recent tickets shown if any

#### Task 4.5: Add Navigation Routes

| File | Priority | Est. |
|------|----------|------|
| Router configuration | P0 | 2h |

**Routes:**
- `/support` → SupportHubPage
- `/support/tickets` → TicketListPage
- `/support/tickets/:id` → TicketDetailPage
- `/support/new` → NewTicketPage (with optional arguments)

**Acceptance Criteria:**
- [ ] All routes registered
- [ ] Deep linking support
- [ ] Arguments passing works

#### Task 4.6: Integrate with Settings/Profile

| File | Priority | Est. |
|------|----------|------|
| Profile/Settings page | P0 | 1h |

**Add:**
- "Help & Support" menu item
- Badge for unread support messages (optional)

---

## ☁️ Phase 5: Cloud Functions & Notifications

**Duration:** 3 days  
**Dependencies:** Phase 4 complete  
**Deliverables:** Backend automation, notifications

### Day 17: Core Cloud Functions

#### Task 5.1: Create onTicketCreate Function

| File | Priority | Est. |
|------|----------|------|
| `functions/src/support/onTicketCreate.ts` | P0 | 3h |

**Logic:**
1. Generate ticket number (GH-YYYY-XXXXX)
2. Create welcome system message
3. Send confirmation email (optional)
4. Notify support team for urgent tickets
5. Update analytics

**Acceptance Criteria:**
- [ ] Ticket number generation with counter
- [ ] Atomic transaction for counter
- [ ] System message created
- [ ] Unit tests

#### Task 5.2: Create onMessageCreate Function

| File | Priority | Est. |
|------|----------|------|
| `functions/src/support/onMessageCreate.ts` | P0 | 2h |

**Logic:**
1. Update ticket messageCount
2. Update lastActivityAt
3. If from support → notify user
4. Update unread flags

**Acceptance Criteria:**
- [ ] Ticket metadata updated
- [ ] Push notification sent to user
- [ ] Unit tests

### Day 18: Scheduled Tasks & Index

#### Task 5.3: Create Auto-Close Function

| File | Priority | Est. |
|------|----------|------|
| `functions/src/support/scheduledTasks.ts` | P1 | 2h |

**Logic:**
- Run daily
- Find resolved tickets older than 7 days
- Auto-close with system message

**Acceptance Criteria:**
- [ ] Scheduled function works
- [ ] Batch processing for efficiency
- [ ] System message added

#### Task 5.4: Export Functions

| File | Priority | Est. |
|------|----------|------|
| `functions/src/support/index.ts` | P0 | 0.5h |

```typescript
export { onTicketCreate } from './onTicketCreate';
export { onSupportMessageCreate } from './onMessageCreate';
export { autoCloseResolvedTickets } from './scheduledTasks';
```

#### Task 5.5: Update Main Index

| File | Priority | Est. |
|------|----------|------|
| `functions/src/index.ts` | P0 | 0.5h |

```typescript
export * from './support';
```

### Day 19: Push Notifications

#### Task 5.6: Handle Support Push Notifications

| File | Priority | Est. |
|------|----------|------|
| `lib/shared/services/firebase_messaging_service.dart` | P0 | 2h |

**Add handler for:**
- Type: `support_message`
- Action: Navigate to ticket detail

**Acceptance Criteria:**
- [ ] Notification displayed correctly
- [ ] Tap opens correct ticket
- [ ] Deep link works from terminated state

#### Task 5.7: Deploy Cloud Functions

**Acceptance Criteria:**
- [ ] `npm run build` succeeds
- [ ] `firebase deploy --only functions` succeeds
- [ ] Functions visible in Firebase Console
- [ ] Test ticket creation triggers function

---

## ✨ Phase 6: Polish - Ratings, Analytics & Testing

**Duration:** 3 days  
**Dependencies:** Phase 5 complete  
**Deliverables:** Complete feature with testing

### Day 20: Satisfaction Ratings

#### Task 6.1: Create SatisfactionRatingDialog

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/presentation/widgets/satisfaction_rating_dialog.dart` | P1 | 2h |

**Features:**
- 5-star rating input
- Optional comment field
- Submit button

**Acceptance Criteria:**
- [ ] Appears for resolved tickets
- [ ] Rating saved to ticket
- [ ] Thank you confirmation

#### Task 6.2: Integrate Rating Prompt

| File | Priority | Est. |
|------|----------|------|
| `ticket_detail_page.dart`, `ticket_card.dart` | P1 | 1h |

**Acceptance Criteria:**
- [ ] Prompt shown for resolved unrated tickets
- [ ] Banner in ticket detail
- [ ] Indicator in ticket card

### Day 21: Analytics & Error Reporting

#### Task 6.3: Add Analytics Events

| File | Priority | Est. |
|------|----------|------|
| Analytics service | P1 | 2h |

**Events:**
- `support_hub_opened`
- `support_ticket_started`
- `support_ticket_submitted`
- `support_ticket_viewed`
- `support_message_sent`
- `support_satisfaction_rated`

#### Task 6.4: Add Error Context for Bug Reports

| File | Priority | Est. |
|------|----------|------|
| Error handler integration | P2 | 2h |

**Add "Report Issue" option to error dialogs:**
- Pre-fill ticket type as bug
- Include error details in description

### Day 22: Testing & Documentation

#### Task 6.5: Unit Tests

| Files | Priority | Est. |
|-------|----------|------|
| Models, Service, Repositories | P0 | 4h |

**Target:** 80% coverage on core files

#### Task 6.6: Widget Tests

| Files | Priority | Est. |
|-------|----------|------|
| Widgets, Pages | P0 | 3h |

#### Task 6.7: Integration Tests

| File | Priority | Est. |
|------|----------|------|
| `test/features/support/integration/support_flow_test.dart` | P1 | 2h |

**Test full flow:**
1. Open support hub
2. Create ticket
3. View ticket
4. Send reply
5. Rate satisfaction

#### Task 6.8: Create Feature Registration

| File | Priority | Est. |
|------|----------|------|
| `lib/features/support/support_feature.dart` | P0 | 0.5h |

---

## 📁 Final File Structure

```
lib/features/support/
├── data/
│   ├── models/
│   │   ├── models.dart
│   │   ├── device_context.dart
│   │   ├── support_enums.dart
│   │   ├── support_message.dart
│   │   ├── support_ticket.dart
│   │   └── ticket_attachment.dart
│   └── repositories/
│       ├── support_attachment_repository.dart
│       └── support_repository.dart
├── domain/
│   └── services/
│       ├── device_info_service.dart
│       └── support_service.dart
├── presentation/
│   ├── pages/
│   │   ├── new_ticket_page.dart
│   │   ├── support_hub_page.dart
│   │   ├── ticket_detail_page.dart
│   │   └── ticket_list_page.dart
│   ├── view_models/
│   │   ├── new_ticket_view_model.dart
│   │   ├── ticket_detail_view_model.dart
│   │   └── ticket_list_view_model.dart
│   └── widgets/
│       ├── attachment_picker.dart
│       ├── attachment_viewer.dart
│       ├── category_dropdown.dart
│       ├── message_bubble.dart
│       ├── message_input.dart
│       ├── satisfaction_rating_dialog.dart
│       ├── ticket_card.dart
│       ├── ticket_status_chip.dart
│       └── ticket_type_selector.dart
└── support_feature.dart

functions/src/support/
├── index.ts
├── onMessageCreate.ts
├── onTicketCreate.ts
└── scheduledTasks.ts

test/features/support/
├── data/
│   ├── models/
│   │   ├── support_ticket_test.dart
│   │   └── support_message_test.dart
│   └── repositories/
│       └── support_repository_test.dart
├── domain/
│   └── services/
│       └── support_service_test.dart
├── presentation/
│   ├── pages/
│   │   ├── new_ticket_page_test.dart
│   │   ├── ticket_list_page_test.dart
│   │   └── ticket_detail_page_test.dart
│   └── widgets/
│       ├── ticket_card_test.dart
│       └── message_bubble_test.dart
└── integration/
    └── support_flow_test.dart
```

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] All unit tests passing
- [ ] All widget tests passing
- [ ] Integration tests passing
- [ ] Code review completed
- [ ] Firestore indexes deployed
- [ ] Security rules deployed
- [ ] Storage rules deployed
- [ ] Cloud Functions deployed
- [ ] Push notifications tested

### Deployment
- [ ] Deploy to staging environment
- [ ] QA verification
- [ ] Performance testing
- [ ] Deploy to production
- [ ] Monitor error rates

### Post-Deployment
- [ ] Verify Cloud Functions triggering
- [ ] Verify push notifications
- [ ] Monitor analytics events
- [ ] Collect initial user feedback

---

## 📊 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Attachment upload failures | Medium | Medium | Retry logic, local caching |
| Push notification delivery | Low | Medium | Email fallback, in-app badge |
| Cloud Function cold starts | Medium | Low | Minimum instances for critical functions |
| Large ticket volume | Low | Medium | Pagination, archiving strategy |
| Spam submissions | Low | Medium | Rate limiting (future) |

---

## 📝 Dependencies to Add

```yaml
# pubspec.yaml additions
dependencies:
  device_info_plus: ^9.0.0      # Device information
  package_info_plus: ^4.0.0     # App version info  
  image_picker: ^1.0.0          # Attachment picker (may already exist)
```

---

## ✅ Approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer | | | |
| Tech Lead | | | |
| Product Owner | | | |

---

*This implementation plan follows the design specifications in `SUPPORT_FEEDBACK_SYSTEM_DESIGN.md` and aligns with the existing GreenHive architecture patterns.*
