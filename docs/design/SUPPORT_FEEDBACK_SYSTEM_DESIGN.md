# Customer Support, Feedback & Issue Reporting System

**Version:** 1.0  
**Status:** Design Complete  
**Created:** January 28, 2026  
**Author:** Engineering Architecture Team  

---

## 📑 Table of Contents

1. [Overview](#1-overview)
2. [Requirements](#2-requirements)
3. [Data Models](#3-data-models)
4. [Architecture](#4-architecture)
5. [Service Layer](#5-service-layer)
6. [Cloud Functions](#6-cloud-functions)
7. [UI Components](#7-ui-components)
8. [File Structure](#8-file-structure)
9. [Firestore Security Rules](#9-firestore-security-rules)
10. [Implementation Phases](#10-implementation-phases)
11. [Integration Points](#11-integration-points)
12. [Analytics & Reporting](#12-analytics--reporting)

---

## 1. Overview

### Purpose

A comprehensive in-app system allowing users to:
- **Submit Feedback** - Feature requests, suggestions, general feedback
- **Report Issues** - Bugs, crashes, technical problems
- **Contact Support** - Direct support requests with conversation threading
- **Track Status** - View history and status of submitted tickets

### Goals

| Goal | Description |
|------|-------------|
| **User Experience** | Easy, intuitive ticket submission with minimal friction |
| **Categorization** | Smart categorization for efficient support routing |
| **Context Collection** | Automatic capture of device/app context for debugging |
| **Communication** | Two-way conversation between user and support team |
| **Transparency** | Users can track ticket status and history |
| **Analytics** | Insights into common issues for product improvement |

### Scope

| In Scope | Out of Scope |
|----------|--------------|
| Feedback submission | Live chat support |
| Issue/bug reporting | Phone support |
| Support ticket threading | AI chatbot |
| Attachment support (screenshots) | Knowledge base/FAQ (Phase 2) |
| Status tracking | Community forums |
| Push notifications for updates | |
| Admin dashboard (Cloud Functions) | Full admin web portal |

---

## 2. Requirements

### Functional Requirements

#### FR-1: Ticket Submission
- Users can submit tickets with: type, category, subject, description
- Support for image attachments (max 5 images, 10MB each)
- Optional email for non-authenticated contact
- Automatic capture of device info and app version

#### FR-2: Ticket Types
| Type | Use Case | Priority Default |
|------|----------|------------------|
| `bug` | App crashes, errors, unexpected behavior | High |
| `feature_request` | New feature suggestions | Low |
| `feedback` | General feedback, UX improvements | Low |
| `support` | Help requests, how-to questions | Medium |
| `account` | Account-related issues | High |
| `payment` | Billing, payment issues | Critical |

#### FR-3: Ticket Categories
| Category | Applies To |
|----------|------------|
| `calling` | Audio/video call issues |
| `chat` | Messaging issues |
| `profile` | Profile, settings issues |
| `notifications` | Push notification issues |
| `experts` | Expert-related issues |
| `performance` | App speed, crashes |
| `other` | Uncategorized |

#### FR-4: Ticket Lifecycle
```
┌─────────┐    ┌────────────┐    ┌─────────────┐    ┌──────────┐
│  Open   │───▶│ In Review  │───▶│ In Progress │───▶│ Resolved │
└─────────┘    └────────────┘    └─────────────┘    └──────────┘
     │                                                    │
     │              ┌───────────────┐                     │
     └─────────────▶│    Closed     │◀────────────────────┘
                    │ (No Response) │
                    └───────────────┘
```

#### FR-5: Communication
- Support team can reply to tickets
- Users receive push notifications on new replies
- Users can reply to support responses
- Conversation history preserved

#### FR-6: User Ticket History
- View all submitted tickets
- Filter by status, type
- Search tickets

### Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Submission latency | < 2 seconds (excluding uploads) |
| Image upload | < 30 seconds for 5 images |
| Ticket list load | < 1 second |
| Offline support | Queue submissions when offline |
| Data retention | 2 years |

---

## 3. Data Models

### 3.1 Firestore Collections

```
firestore/
├── support_tickets/                    # Main tickets collection
│   └── {ticketId}/
│       ├── ... ticket fields ...
│       └── messages/                   # Subcollection for conversation
│           └── {messageId}/
│               └── ... message fields ...
├── support_categories/                 # Configurable categories
│   └── {categoryId}/
└── support_analytics/                  # Aggregated analytics (admin)
    └── {period}/
```

### 3.2 Support Ticket Document

```javascript
// Collection: support_tickets/{ticketId}
{
  // Identifiers
  "id": "ticket_abc123",
  "ticketNumber": "GH-2026-00042",      // Human-readable ID
  
  // User Info
  "userId": "user_xyz",                  // Firebase Auth UID (nullable for anonymous)
  "userEmail": "user@example.com",       // For contact
  "userName": "John Doe",                // Display name
  
  // Ticket Content
  "type": "bug",                         // bug | feature_request | feedback | support | account | payment
  "category": "calling",                 // calling | chat | profile | notifications | experts | performance | other
  "subject": "App crashes during video call",
  "description": "Detailed description of the issue...",
  "attachments": [                       // Optional screenshots/files
    {
      "id": "att_001",
      "url": "gs://bucket/support/ticket_abc123/screenshot1.png",
      "fileName": "screenshot1.png",
      "fileSize": 245678,
      "mimeType": "image/png",
      "uploadedAt": Timestamp
    }
  ],
  
  // Device Context (auto-captured)
  "deviceContext": {
    "platform": "iOS",                   // iOS | Android | Web
    "osVersion": "17.2",
    "appVersion": "2.4.1",
    "buildNumber": "142",
    "deviceModel": "iPhone 15 Pro",
    "locale": "en_US",
    "timezone": "America/Los_Angeles",
    "screenSize": "393x852"
  },
  
  // Status & Priority
  "status": "open",                      // open | in_review | in_progress | resolved | closed
  "priority": "high",                    // critical | high | medium | low
  "assignedTo": null,                    // Support agent ID (nullable)
  "tags": ["crash", "video"],            // For filtering/searching
  
  // Timestamps
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  "resolvedAt": null,                    // Timestamp when resolved
  "closedAt": null,                      // Timestamp when closed
  "lastActivityAt": Timestamp,           // Last message or status change
  
  // Metadata
  "messageCount": 3,                     // Denormalized for display
  "hasUnreadUserMessages": false,        // For support dashboard
  "hasUnreadSupportMessages": true,      // For user notification
  "isAutoCreated": false,                // True if created from crash report
  
  // Resolution
  "resolution": null,                    // Resolution summary when closed
  "resolutionType": null,                // fixed | duplicate | wont_fix | invalid | user_resolved
  "userSatisfactionRating": null,        // 1-5 post-resolution rating
  "userSatisfactionComment": null        // Optional feedback on support
}
```

### 3.3 Support Message Document

```javascript
// Collection: support_tickets/{ticketId}/messages/{messageId}
{
  "id": "msg_def456",
  "ticketId": "ticket_abc123",
  
  // Sender
  "senderId": "user_xyz",                // User ID or support agent ID
  "senderType": "user",                  // user | support | system
  "senderName": "John Doe",
  
  // Content
  "content": "Thanks for reaching out. Can you provide more details?",
  "attachments": [                       // Optional
    {
      "id": "att_002",
      "url": "gs://bucket/support/ticket_abc123/messages/log.txt",
      "fileName": "log.txt",
      "fileSize": 12456,
      "mimeType": "text/plain"
    }
  ],
  
  // Metadata
  "createdAt": Timestamp,
  "readAt": null,                        // When recipient read it
  "isInternal": false,                   // True for internal notes (support only)
  
  // System message fields
  "systemMessageType": null,             // status_change | assignment_change | auto_response
  "systemMessageData": null              // Additional data for system messages
}
```

### 3.4 Dart Models

```dart
// lib/features/support/data/models/support_ticket.dart

enum TicketType {
  bug,
  featureRequest,
  feedback,
  support,
  account,
  payment;
  
  String get displayName {
    switch (this) {
      case TicketType.bug: return 'Bug Report';
      case TicketType.featureRequest: return 'Feature Request';
      case TicketType.feedback: return 'Feedback';
      case TicketType.support: return 'Support Request';
      case TicketType.account: return 'Account Issue';
      case TicketType.payment: return 'Payment Issue';
    }
  }
  
  String get emoji {
    switch (this) {
      case TicketType.bug: return '🐛';
      case TicketType.featureRequest: return '💡';
      case TicketType.feedback: return '💬';
      case TicketType.support: return '🆘';
      case TicketType.account: return '👤';
      case TicketType.payment: return '💳';
    }
  }
}

enum TicketCategory {
  calling,
  chat,
  profile,
  notifications,
  experts,
  performance,
  other;
  
  String get displayName {
    switch (this) {
      case TicketCategory.calling: return 'Calling & Video';
      case TicketCategory.chat: return 'Chat & Messaging';
      case TicketCategory.profile: return 'Profile & Settings';
      case TicketCategory.notifications: return 'Notifications';
      case TicketCategory.experts: return 'Experts';
      case TicketCategory.performance: return 'Performance';
      case TicketCategory.other: return 'Other';
    }
  }
}

enum TicketStatus {
  open,
  inReview,
  inProgress,
  resolved,
  closed;
  
  String get displayName {
    switch (this) {
      case TicketStatus.open: return 'Open';
      case TicketStatus.inReview: return 'In Review';
      case TicketStatus.inProgress: return 'In Progress';
      case TicketStatus.resolved: return 'Resolved';
      case TicketStatus.closed: return 'Closed';
    }
  }
  
  Color get color {
    switch (this) {
      case TicketStatus.open: return Colors.blue;
      case TicketStatus.inReview: return Colors.orange;
      case TicketStatus.inProgress: return Colors.purple;
      case TicketStatus.resolved: return Colors.green;
      case TicketStatus.closed: return Colors.grey;
    }
  }
}

enum TicketPriority {
  critical,
  high,
  medium,
  low;
  
  static TicketPriority fromTicketType(TicketType type) {
    switch (type) {
      case TicketType.payment: return TicketPriority.critical;
      case TicketType.bug:
      case TicketType.account: return TicketPriority.high;
      case TicketType.support: return TicketPriority.medium;
      case TicketType.featureRequest:
      case TicketType.feedback: return TicketPriority.low;
    }
  }
}

class DeviceContext {
  final String platform;
  final String osVersion;
  final String appVersion;
  final String buildNumber;
  final String? deviceModel;
  final String locale;
  final String timezone;
  final String? screenSize;
  
  const DeviceContext({
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.buildNumber,
    this.deviceModel,
    required this.locale,
    required this.timezone,
    this.screenSize,
  });
  
  factory DeviceContext.capture() {
    // Implementation captures current device info
    // Uses package_info_plus, device_info_plus
  }
  
  factory DeviceContext.fromJson(Map<String, dynamic> json) => DeviceContext(
    platform: json['platform'] as String,
    osVersion: json['osVersion'] as String,
    appVersion: json['appVersion'] as String,
    buildNumber: json['buildNumber'] as String,
    deviceModel: json['deviceModel'] as String?,
    locale: json['locale'] as String,
    timezone: json['timezone'] as String,
    screenSize: json['screenSize'] as String?,
  );
  
  Map<String, dynamic> toJson() => {
    'platform': platform,
    'osVersion': osVersion,
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'deviceModel': deviceModel,
    'locale': locale,
    'timezone': timezone,
    'screenSize': screenSize,
  };
}

class TicketAttachment {
  final String id;
  final String url;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final DateTime uploadedAt;
  
  const TicketAttachment({
    required this.id,
    required this.url,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.uploadedAt,
  });
  
  factory TicketAttachment.fromJson(Map<String, dynamic> json) => TicketAttachment(
    id: json['id'] as String,
    url: json['url'] as String,
    fileName: json['fileName'] as String,
    fileSize: json['fileSize'] as int,
    mimeType: json['mimeType'] as String,
    uploadedAt: (json['uploadedAt'] as Timestamp).toDate(),
  );
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'fileName': fileName,
    'fileSize': fileSize,
    'mimeType': mimeType,
    'uploadedAt': Timestamp.fromDate(uploadedAt),
  };
}

class SupportTicket {
  final String id;
  final String ticketNumber;
  
  // User info
  final String? userId;
  final String userEmail;
  final String? userName;
  
  // Content
  final TicketType type;
  final TicketCategory category;
  final String subject;
  final String description;
  final List<TicketAttachment> attachments;
  
  // Context
  final DeviceContext deviceContext;
  
  // Status
  final TicketStatus status;
  final TicketPriority priority;
  final String? assignedTo;
  final List<String> tags;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final DateTime lastActivityAt;
  
  // Metadata
  final int messageCount;
  final bool hasUnreadSupportMessages;
  
  // Resolution
  final String? resolution;
  final String? resolutionType;
  final int? userSatisfactionRating;
  final String? userSatisfactionComment;
  
  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    this.userId,
    required this.userEmail,
    this.userName,
    required this.type,
    required this.category,
    required this.subject,
    required this.description,
    this.attachments = const [],
    required this.deviceContext,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedAt,
    required this.lastActivityAt,
    this.messageCount = 0,
    this.hasUnreadSupportMessages = false,
    this.resolution,
    this.resolutionType,
    this.userSatisfactionRating,
    this.userSatisfactionComment,
  });
  
  bool get isOpen => status == TicketStatus.open || 
                     status == TicketStatus.inReview || 
                     status == TicketStatus.inProgress;
  
  bool get canReply => status != TicketStatus.closed;
  
  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    // Implementation
  }
  
  Map<String, dynamic> toJson() {
    // Implementation
  }
  
  SupportTicket copyWith({/* ... */}) {
    // Implementation
  }
}
```

```dart
// lib/features/support/data/models/support_message.dart

enum MessageSenderType {
  user,
  support,
  system;
}

enum SystemMessageType {
  statusChange,
  assignmentChange,
  autoResponse,
  ticketCreated,
  ticketResolved,
  ticketClosed;
}

class SupportMessage {
  final String id;
  final String ticketId;
  
  // Sender
  final String senderId;
  final MessageSenderType senderType;
  final String senderName;
  
  // Content
  final String content;
  final List<TicketAttachment> attachments;
  
  // Metadata
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isInternal;
  
  // System message
  final SystemMessageType? systemMessageType;
  final Map<String, dynamic>? systemMessageData;
  
  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.content,
    this.attachments = const [],
    required this.createdAt,
    this.readAt,
    this.isInternal = false,
    this.systemMessageType,
    this.systemMessageData,
  });
  
  bool get isSystemMessage => senderType == MessageSenderType.system;
  bool get isFromSupport => senderType == MessageSenderType.support;
  bool get isFromUser => senderType == MessageSenderType.user;
  bool get isRead => readAt != null;
  
  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    // Implementation
  }
  
  Map<String, dynamic> toJson() {
    // Implementation
  }
}
```

---

## 4. Architecture

### 4.1 Layer Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │
│  │ TicketListPage  │  │ TicketDetailPage│  │ NewTicketPage  │  │
│  └────────┬────────┘  └────────┬────────┘  └───────┬────────┘  │
│           │                    │                    │           │
│  ┌────────▼────────┐  ┌────────▼────────┐  ┌───────▼────────┐  │
│  │TicketListVM     │  │TicketDetailVM   │  │ NewTicketVM    │  │
│  └────────┬────────┘  └────────┬────────┘  └───────┬────────┘  │
└───────────┼────────────────────┼───────────────────┼───────────┘
            │                    │                   │
┌───────────▼────────────────────▼───────────────────▼───────────┐
│                       DOMAIN LAYER                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    SupportService                         │  │
│  │  • createTicket()    • replyToTicket()                   │  │
│  │  • getTickets()      • updateTicketStatus()              │  │
│  │  • getTicketById()   • uploadAttachment()                │  │
│  │  • watchTicket()     • rateSupport()                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  DeviceInfoService                        │  │
│  │  • captureDeviceContext()                                │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────────┬────────────────────────────────────────────────────┘
            │
┌───────────▼────────────────────────────────────────────────────┐
│                        DATA LAYER                               │
│  ┌────────────────────────┐  ┌────────────────────────────┐   │
│  │   SupportRepository    │  │  SupportAttachmentRepo     │   │
│  │  • CRUD operations     │  │  • Upload to Storage       │   │
│  │  • Query tickets       │  │  • Generate URLs           │   │
│  │  • Real-time streams   │  │                            │   │
│  └───────────┬────────────┘  └────────────┬───────────────┘   │
└──────────────┼─────────────────────────────┼───────────────────┘
               │                             │
┌──────────────▼─────────────────────────────▼───────────────────┐
│                    INFRASTRUCTURE LAYER                         │
│  ┌────────────────────────┐  ┌────────────────────────────┐   │
│  │       Firestore        │  │    Firebase Storage        │   │
│  │  support_tickets/      │  │  support/{ticketId}/       │   │
│  └────────────────────────┘  └────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

### 4.2 Data Flow

```
User Action                    App Layer                    Firebase
    │                              │                            │
    │  Submit Ticket               │                            │
    ├─────────────────────────────▶│                            │
    │                              │  Capture Device Context    │
    │                              ├───────────────────────────▶│
    │                              │                            │
    │                              │  Upload Attachments        │
    │                              ├───────────────────────────▶│
    │                              │  (Firebase Storage)        │
    │                              │◀───────────────────────────┤
    │                              │  Return URLs               │
    │                              │                            │
    │                              │  Create Ticket Document    │
    │                              ├───────────────────────────▶│
    │                              │  (Firestore)               │
    │                              │◀───────────────────────────┤
    │                              │  Return Ticket             │
    │  Show Success                │                            │
    │◀─────────────────────────────┤                            │
    │                              │                            │
    │                              │  Trigger: onTicketCreate   │
    │                              │◀───────────────────────────┤
    │                              │  (Cloud Function)          │
    │                              │  • Generate ticket number  │
    │                              │  • Send email notification │
    │                              │  • Update analytics        │
```

---

## 5. Service Layer

### 5.1 SupportService

```dart
// lib/features/support/domain/services/support_service.dart

class SupportService {
  final SupportRepository _repository;
  final SupportAttachmentRepository _attachmentRepository;
  final DeviceInfoService _deviceInfoService;
  final NotificationService _notificationService;
  final AppLogger _log;
  
  static const String _tag = 'SupportService';
  static const int maxAttachments = 5;
  static const int maxAttachmentSizeMB = 10;
  static const int maxSubjectLength = 100;
  static const int maxDescriptionLength = 5000;
  
  SupportService({
    required SupportRepository repository,
    required SupportAttachmentRepository attachmentRepository,
    required DeviceInfoService deviceInfoService,
    required NotificationService notificationService,
    required AppLogger log,
  }) : _repository = repository,
       _attachmentRepository = attachmentRepository,
       _deviceInfoService = deviceInfoService,
       _notificationService = notificationService,
       _log = log;
  
  /// Create a new support ticket
  Future<Result<SupportTicket, SupportError>> createTicket({
    required TicketType type,
    required TicketCategory category,
    required String subject,
    required String description,
    List<File>? attachments,
    String? userEmail,
  }) async {
    _log.info('Creating ticket: type=$type, category=$category', tag: _tag);
    
    // 1. Validate input
    if (subject.trim().isEmpty) {
      return Result.failure(SupportError.invalidSubject);
    }
    if (subject.length > maxSubjectLength) {
      return Result.failure(SupportError.subjectTooLong);
    }
    if (description.trim().isEmpty) {
      return Result.failure(SupportError.invalidDescription);
    }
    if (description.length > maxDescriptionLength) {
      return Result.failure(SupportError.descriptionTooLong);
    }
    if (attachments != null && attachments.length > maxAttachments) {
      return Result.failure(SupportError.tooManyAttachments);
    }
    
    // 2. Validate attachments size
    if (attachments != null) {
      for (final file in attachments) {
        final sizeMB = await file.length() / (1024 * 1024);
        if (sizeMB > maxAttachmentSizeMB) {
          return Result.failure(SupportError.attachmentTooLarge);
        }
      }
    }
    
    // 3. Capture device context
    final deviceContext = await _deviceInfoService.captureDeviceContext();
    
    // 4. Upload attachments
    List<TicketAttachment> uploadedAttachments = [];
    if (attachments != null && attachments.isNotEmpty) {
      final uploadResult = await _attachmentRepository.uploadAttachments(
        ticketId: 'temp', // Will be updated after ticket creation
        files: attachments,
      );
      if (uploadResult.isFailure) {
        return Result.failure(SupportError.attachmentUploadFailed);
      }
      uploadedAttachments = uploadResult.value;
    }
    
    // 5. Create ticket
    final ticket = SupportTicket(
      id: '', // Generated by Firestore
      ticketNumber: '', // Generated by Cloud Function
      userId: _getCurrentUserId(),
      userEmail: userEmail ?? _getCurrentUserEmail() ?? '',
      userName: _getCurrentUserName(),
      type: type,
      category: category,
      subject: subject.trim(),
      description: description.trim(),
      attachments: uploadedAttachments,
      deviceContext: deviceContext,
      status: TicketStatus.open,
      priority: TicketPriority.fromTicketType(type),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
    );
    
    final result = await _repository.createTicket(ticket);
    
    if (result.isSuccess) {
      _log.info('Ticket created: ${result.value.id}', tag: _tag);
    }
    
    return result;
  }
  
  /// Get all tickets for current user
  Future<Result<List<SupportTicket>, SupportError>> getUserTickets({
    TicketStatus? statusFilter,
    TicketType? typeFilter,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      return Result.failure(SupportError.notAuthenticated);
    }
    
    return _repository.getTicketsByUser(
      userId: userId,
      statusFilter: statusFilter,
      typeFilter: typeFilter,
      limit: limit,
      startAfter: startAfter,
    );
  }
  
  /// Get a specific ticket by ID
  Future<Result<SupportTicket, SupportError>> getTicketById(String ticketId) async {
    final ticket = await _repository.getTicket(ticketId);
    if (ticket == null) {
      return Result.failure(SupportError.ticketNotFound);
    }
    
    // Verify ownership
    final userId = _getCurrentUserId();
    if (ticket.userId != userId) {
      return Result.failure(SupportError.accessDenied);
    }
    
    return Result.success(ticket);
  }
  
  /// Watch a ticket for real-time updates
  Stream<SupportTicket?> watchTicket(String ticketId) {
    return _repository.watchTicket(ticketId);
  }
  
  /// Get messages for a ticket
  Stream<List<SupportMessage>> watchTicketMessages(String ticketId) {
    return _repository.watchMessages(ticketId);
  }
  
  /// Reply to a ticket
  Future<Result<SupportMessage, SupportError>> replyToTicket({
    required String ticketId,
    required String content,
    List<File>? attachments,
  }) async {
    _log.info('Replying to ticket: $ticketId', tag: _tag);
    
    // 1. Validate ticket
    final ticketResult = await getTicketById(ticketId);
    if (ticketResult.isFailure) {
      return Result.failure(ticketResult.error);
    }
    
    final ticket = ticketResult.value;
    if (!ticket.canReply) {
      return Result.failure(SupportError.ticketClosed);
    }
    
    // 2. Validate content
    if (content.trim().isEmpty) {
      return Result.failure(SupportError.invalidMessage);
    }
    
    // 3. Upload attachments if any
    List<TicketAttachment> uploadedAttachments = [];
    if (attachments != null && attachments.isNotEmpty) {
      final uploadResult = await _attachmentRepository.uploadAttachments(
        ticketId: ticketId,
        files: attachments,
        subPath: 'messages',
      );
      if (uploadResult.isSuccess) {
        uploadedAttachments = uploadResult.value;
      }
    }
    
    // 4. Create message
    final message = SupportMessage(
      id: '',
      ticketId: ticketId,
      senderId: _getCurrentUserId() ?? 'anonymous',
      senderType: MessageSenderType.user,
      senderName: _getCurrentUserName() ?? 'User',
      content: content.trim(),
      attachments: uploadedAttachments,
      createdAt: DateTime.now(),
    );
    
    return _repository.addMessage(ticketId, message);
  }
  
  /// Mark support messages as read
  Future<void> markMessagesAsRead(String ticketId) async {
    await _repository.markUserMessagesAsRead(ticketId);
  }
  
  /// Rate support experience (after resolution)
  Future<Result<void, SupportError>> rateSupportExperience({
    required String ticketId,
    required int rating,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      return Result.failure(SupportError.invalidRating);
    }
    
    final ticketResult = await getTicketById(ticketId);
    if (ticketResult.isFailure) {
      return Result.failure(ticketResult.error);
    }
    
    final ticket = ticketResult.value;
    if (ticket.status != TicketStatus.resolved && 
        ticket.status != TicketStatus.closed) {
      return Result.failure(SupportError.cannotRateUnresolvedTicket);
    }
    
    return _repository.updateTicket(ticketId, {
      'userSatisfactionRating': rating,
      'userSatisfactionComment': comment,
    });
  }
  
  // Helper methods
  String? _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
  
  String? _getCurrentUserEmail() {
    return FirebaseAuth.instance.currentUser?.email;
  }
  
  String? _getCurrentUserName() {
    return FirebaseAuth.instance.currentUser?.displayName;
  }
}

/// Support operation errors
enum SupportError {
  invalidSubject,
  subjectTooLong,
  invalidDescription,
  descriptionTooLong,
  tooManyAttachments,
  attachmentTooLarge,
  attachmentUploadFailed,
  notAuthenticated,
  ticketNotFound,
  accessDenied,
  ticketClosed,
  invalidMessage,
  invalidRating,
  cannotRateUnresolvedTicket,
  networkError,
  unknown;
  
  String get message {
    switch (this) {
      case SupportError.invalidSubject: return 'Please enter a subject';
      case SupportError.subjectTooLong: return 'Subject is too long (max 100 characters)';
      case SupportError.invalidDescription: return 'Please describe your issue';
      case SupportError.descriptionTooLong: return 'Description is too long (max 5000 characters)';
      case SupportError.tooManyAttachments: return 'Maximum 5 attachments allowed';
      case SupportError.attachmentTooLarge: return 'Attachment too large (max 10MB)';
      case SupportError.attachmentUploadFailed: return 'Failed to upload attachment';
      case SupportError.notAuthenticated: return 'Please sign in to continue';
      case SupportError.ticketNotFound: return 'Ticket not found';
      case SupportError.accessDenied: return 'Access denied';
      case SupportError.ticketClosed: return 'This ticket is closed';
      case SupportError.invalidMessage: return 'Please enter a message';
      case SupportError.invalidRating: return 'Please select a rating';
      case SupportError.cannotRateUnresolvedTicket: return 'Cannot rate unresolved ticket';
      case SupportError.networkError: return 'Network error. Please try again';
      case SupportError.unknown: return 'An error occurred';
    }
  }
}
```

### 5.2 DeviceInfoService

```dart
// lib/features/support/domain/services/device_info_service.dart

class DeviceInfoService {
  /// Capture current device context
  Future<DeviceContext> captureDeviceContext() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    
    String platform;
    String osVersion;
    String? deviceModel;
    
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      platform = 'iOS';
      osVersion = iosInfo.systemVersion;
      deviceModel = iosInfo.model;
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      platform = 'Android';
      osVersion = androidInfo.version.release;
      deviceModel = androidInfo.model;
    } else {
      platform = 'Web';
      osVersion = 'N/A';
      deviceModel = null;
    }
    
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenSize = '${view.physicalSize.width.toInt()}x${view.physicalSize.height.toInt()}';
    
    return DeviceContext(
      platform: platform,
      osVersion: osVersion,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      deviceModel: deviceModel,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      screenSize: screenSize,
    );
  }
}
```

---

## 6. Cloud Functions

### 6.1 Ticket Creation Trigger

```typescript
// functions/src/support/onTicketCreate.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Triggered when a new support ticket is created.
 * - Generates human-readable ticket number
 * - Sends confirmation email to user
 * - Notifies support team
 * - Updates analytics
 */
export const onTicketCreate = functions.firestore
  .document('support_tickets/{ticketId}')
  .onCreate(async (snapshot, context) => {
    const ticketId = context.params.ticketId;
    const ticket = snapshot.data();
    
    console.log(`Processing new ticket: ${ticketId}`);
    
    // 1. Generate ticket number (GH-YYYY-XXXXX)
    const ticketNumber = await generateTicketNumber();
    
    // 2. Update ticket with number
    await snapshot.ref.update({
      ticketNumber: ticketNumber,
    });
    
    // 3. Create initial system message
    await snapshot.ref.collection('messages').add({
      id: admin.firestore.FieldPath.documentId(),
      ticketId: ticketId,
      senderId: 'system',
      senderType: 'system',
      senderName: 'GreenHive Support',
      content: `Thank you for contacting GreenHive Support. Your ticket number is ${ticketNumber}. Our team will review your request and respond as soon as possible.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isInternal: false,
      systemMessageType: 'ticket_created',
    });
    
    // 4. Send email confirmation
    if (ticket.userEmail) {
      await sendTicketConfirmationEmail(ticket.userEmail, ticketNumber, ticket);
    }
    
    // 5. Notify support team (Slack/Email)
    await notifySupportTeam(ticketNumber, ticket);
    
    // 6. Update analytics
    await updateAnalytics(ticket);
    
    console.log(`Ticket ${ticketNumber} processed successfully`);
  });

async function generateTicketNumber(): Promise<string> {
  const year = new Date().getFullYear();
  const counterRef = db.collection('support_counters').doc(year.toString());
  
  return db.runTransaction(async (transaction) => {
    const counterDoc = await transaction.get(counterRef);
    let nextNumber = 1;
    
    if (counterDoc.exists) {
      nextNumber = (counterDoc.data()?.count || 0) + 1;
    }
    
    transaction.set(counterRef, { count: nextNumber }, { merge: true });
    
    return `GH-${year}-${nextNumber.toString().padStart(5, '0')}`;
  });
}

async function sendTicketConfirmationEmail(
  email: string, 
  ticketNumber: string, 
  ticket: any
): Promise<void> {
  // Use SendGrid, Mailgun, or Firebase Email Extension
  const mailRef = db.collection('mail').doc();
  await mailRef.set({
    to: email,
    template: {
      name: 'support_ticket_confirmation',
      data: {
        ticketNumber: ticketNumber,
        subject: ticket.subject,
        type: ticket.type,
        userName: ticket.userName || 'User',
      },
    },
  });
}

async function notifySupportTeam(
  ticketNumber: string, 
  ticket: any
): Promise<void> {
  // Send to Slack webhook or support email
  const priority = ticket.priority;
  const isUrgent = priority === 'critical' || priority === 'high';
  
  if (isUrgent) {
    // Send immediate notification for urgent tickets
    console.log(`URGENT: New ${priority} priority ticket ${ticketNumber}`);
    // Implement Slack webhook call here
  }
}

async function updateAnalytics(ticket: any): Promise<void> {
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  const analyticsRef = db.collection('support_analytics').doc(today);
  
  await analyticsRef.set({
    totalTickets: admin.firestore.FieldValue.increment(1),
    [`byType.${ticket.type}`]: admin.firestore.FieldValue.increment(1),
    [`byCategory.${ticket.category}`]: admin.firestore.FieldValue.increment(1),
    [`byPriority.${ticket.priority}`]: admin.firestore.FieldValue.increment(1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}
```

### 6.2 Message Notification Trigger

```typescript
// functions/src/support/onMessageCreate.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Triggered when a new message is added to a ticket.
 * - Sends push notification to recipient
 * - Updates ticket metadata
 */
export const onSupportMessageCreate = functions.firestore
  .document('support_tickets/{ticketId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const { ticketId, messageId } = context.params;
    const message = snapshot.data();
    
    console.log(`New message ${messageId} on ticket ${ticketId}`);
    
    // Get the ticket
    const ticketRef = db.collection('support_tickets').doc(ticketId);
    const ticketDoc = await ticketRef.get();
    
    if (!ticketDoc.exists) {
      console.error(`Ticket ${ticketId} not found`);
      return;
    }
    
    const ticket = ticketDoc.data()!;
    
    // Update ticket metadata
    const updates: any = {
      messageCount: admin.firestore.FieldValue.increment(1),
      lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // If message from support, notify user
    if (message.senderType === 'support') {
      updates.hasUnreadSupportMessages = true;
      
      // Send push notification to user
      if (ticket.userId) {
        await sendPushToUser(ticket.userId, {
          title: 'Support Update',
          body: `New response on ticket ${ticket.ticketNumber}`,
          data: {
            type: 'support_message',
            ticketId: ticketId,
          },
        });
      }
    } else if (message.senderType === 'user') {
      updates.hasUnreadUserMessages = true;
    }
    
    await ticketRef.update(updates);
  });

async function sendPushToUser(
  userId: string, 
  notification: { title: string; body: string; data: any }
): Promise<void> {
  // Get user's FCM tokens
  const tokensSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('fcm_tokens')
    .get();
  
  const tokens = tokensSnapshot.docs.map(doc => doc.id);
  
  if (tokens.length === 0) {
    console.log(`No FCM tokens for user ${userId}`);
    return;
  }
  
  const message = {
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: notification.data,
    tokens: tokens,
  };
  
  const response = await admin.messaging().sendMulticast(message);
  console.log(`Sent push to ${response.successCount}/${tokens.length} devices`);
}
```

### 6.3 Auto-Close Stale Tickets

```typescript
// functions/src/support/scheduledTasks.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Runs daily to auto-close resolved tickets after 7 days of inactivity.
 */
export const autoCloseResolvedTickets = functions.pubsub
  .schedule('0 0 * * *') // Daily at midnight
  .onRun(async (context) => {
    const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );
    
    const resolvedTickets = await db
      .collection('support_tickets')
      .where('status', '==', 'resolved')
      .where('resolvedAt', '<', sevenDaysAgo)
      .get();
    
    console.log(`Found ${resolvedTickets.size} tickets to auto-close`);
    
    const batch = db.batch();
    
    resolvedTickets.forEach((doc) => {
      batch.update(doc.ref, {
        status: 'closed',
        closedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Add system message
      const messageRef = doc.ref.collection('messages').doc();
      batch.set(messageRef, {
        id: messageRef.id,
        ticketId: doc.id,
        senderId: 'system',
        senderType: 'system',
        senderName: 'System',
        content: 'This ticket has been automatically closed after 7 days of inactivity.',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isInternal: false,
        systemMessageType: 'ticket_closed',
      });
    });
    
    await batch.commit();
    console.log(`Auto-closed ${resolvedTickets.size} tickets`);
  });
```

---

## 7. UI Components

### 7.1 New Ticket Page Wireframe

```
┌─────────────────────────────────────┐
│ ←  Submit a Request                 │
├─────────────────────────────────────┤
│                                     │
│  What can we help you with?         │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🐛  Report a Bug            │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 💡  Request a Feature       │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 💬  Send Feedback           │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 🆘  Get Support             │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 👤  Account Issue           │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 💳  Payment Issue           │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘

[After selecting type]

┌─────────────────────────────────────┐
│ ←  Report a Bug                     │
├─────────────────────────────────────┤
│                                     │
│  Category                           │
│  ┌─────────────────────────────┐   │
│  │ Select category         ▼  │   │
│  └─────────────────────────────┘   │
│                                     │
│  Subject *                          │
│  ┌─────────────────────────────┐   │
│  │ Brief summary of the issue │   │
│  └─────────────────────────────┘   │
│                                     │
│  Description *                      │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │ Describe the issue in      │   │
│  │ detail...                   │   │
│  │                             │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                (0/5000)
│                                     │
│  Attachments (optional)             │
│  ┌───────┐ ┌───────┐ ┌───────┐    │
│  │  📷   │ │  📷   │ │   +   │    │
│  │ img1  │ │ img2  │ │  Add  │    │
│  └───────┘ └───────┘ └───────┘    │
│                                     │
│  📱 Device info will be included    │
│     automatically                   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │        Submit Ticket        │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### 7.2 Ticket List Page Wireframe

```
┌─────────────────────────────────────┐
│ ←  My Tickets          + New Ticket │
├─────────────────────────────────────┤
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐   │
│ │ All │ │Open │ │Resol│ │Closd│   │
│ └─────┘ └─────┘ └─────┘ └─────┘   │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 🐛 App crashes during video     ││
│ │    GH-2026-00042                ││
│ │    ┌──────────┐                 ││
│ │    │In Progress│  •  Jan 28     ││
│ │    └──────────┘                 ││
│ │    🔴 1 new response            ││
│ └─────────────────────────────────┘│
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 💡 Add dark mode                ││
│ │    GH-2026-00038                ││
│ │    ┌──────────┐                 ││
│ │    │  Open    │  •  Jan 25      ││
│ │    └──────────┘                 ││
│ └─────────────────────────────────┘│
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 🆘 Can't reset password         ││
│ │    GH-2026-00035                ││
│ │    ┌──────────┐                 ││
│ │    │ Resolved │  •  Jan 20      ││
│ │    └──────────┘                 ││
│ │    Rate your experience ⭐      ││
│ └─────────────────────────────────┘│
│                                     │
│             No more tickets         │
│                                     │
└─────────────────────────────────────┘
```

### 7.3 Ticket Detail Page Wireframe

```
┌─────────────────────────────────────┐
│ ←  GH-2026-00042                    │
├─────────────────────────────────────┤
│                                     │
│ 🐛 App crashes during video call    │
│ ┌───────────┐                       │
│ │In Progress│  High Priority        │
│ └───────────┘                       │
│                                     │
│ Category: Calling & Video           │
│ Created: Jan 28, 2026               │
│                                     │
├─────────────────────────────────────┤
│ CONVERSATION                        │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 👤 You • Jan 28, 10:30 AM   │    │
│ │                              │    │
│ │ The app crashes every time  │    │
│ │ I try to start a video      │    │
│ │ call. It happens on both    │    │
│ │ WiFi and cellular.          │    │
│ │                              │    │
│ │ [screenshot.png]             │    │
│ └─────────────────────────────┘    │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 🎧 Support • Jan 28, 2:15 PM│    │
│ │                              │    │
│ │ Thanks for reporting this.  │    │
│ │ Can you tell us:            │    │
│ │ 1. Which expert you were    │    │
│ │    trying to call?          │    │
│ │ 2. Have you tried           │    │
│ │    reinstalling the app?    │    │
│ └─────────────────────────────┘    │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 👤 You • Jan 28, 3:00 PM    │    │
│ │                              │    │
│ │ I was calling @DrSmith.     │    │
│ │ Yes, I reinstalled but      │    │
│ │ same issue.                  │    │
│ └─────────────────────────────┘    │
│                                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────┐    │
│ │ Type your reply...       📎 │    │
│ └─────────────────────────────┘    │
│              ┌──────────┐          │
│              │   Send   │          │
│              └──────────┘          │
└─────────────────────────────────────┘
```

### 7.4 Widget Implementations

```dart
// lib/features/support/presentation/widgets/ticket_type_selector.dart

class TicketTypeSelector extends StatelessWidget {
  final TicketType? selected;
  final ValueChanged<TicketType> onSelected;
  
  const TicketTypeSelector({
    super.key,
    this.selected,
    required this.onSelected,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: TicketType.values.map((type) {
        final isSelected = type == selected;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => onSelected(type),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected 
                    ? AppColors.primary 
                    : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected 
                  ? AppColors.primary.withOpacity(0.1) 
                  : null,
              ),
              child: Row(
                children: [
                  Text(type.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 16),
                  Text(
                    type.displayName,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: isSelected 
                        ? FontWeight.w600 
                        : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

```dart
// lib/features/support/presentation/widgets/ticket_card.dart

class TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;
  
  const TicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Type emoji + Subject
              Row(
                children: [
                  Text(ticket.type.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Ticket number
              Text(
                ticket.ticketNumber,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Status + Date
              Row(
                children: [
                  _StatusChip(status: ticket.status),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(ticket.lastActivityAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              
              // Unread indicator
              if (ticket.hasUnreadSupportMessages) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '1 new response',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Rate prompt for resolved tickets
              if (ticket.status == TicketStatus.resolved && 
                  ticket.userSatisfactionRating == null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_outline, 
                      size: 16, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      'Rate your experience',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final TicketStatus status;
  
  const _StatusChip({required this.status});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: AppTypography.caption.copyWith(
          color: status.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```

```dart
// lib/features/support/presentation/widgets/message_bubble.dart

class SupportMessageBubble extends StatelessWidget {
  final SupportMessage message;
  
  const SupportMessageBubble({
    super.key,
    required this.message,
  });
  
  @override
  Widget build(BuildContext context) {
    if (message.isSystemMessage) {
      return _SystemMessageBubble(message: message);
    }
    
    final isFromUser = message.isFromUser;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: isFromUser 
          ? CrossAxisAlignment.end 
          : CrossAxisAlignment.start,
        children: [
          // Sender info
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isFromUser) ...[
                const Icon(Icons.headset_mic, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
              ],
              Text(
                isFromUser ? 'You' : 'Support',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(message.createdAt),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // Message bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFromUser 
                ? AppColors.primary 
                : AppColors.surface,
              borderRadius: BorderRadius.circular(12).copyWith(
                bottomRight: isFromUser ? Radius.zero : null,
                bottomLeft: !isFromUser ? Radius.zero : null,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isFromUser ? Colors.white : null,
                  ),
                ),
                
                // Attachments
                if (message.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.attachments.map((att) {
                      return _AttachmentChip(
                        attachment: att,
                        isFromUser: isFromUser,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime date) {
    return DateFormat('MMM d, h:mm a').format(date);
  }
}

class _SystemMessageBubble extends StatelessWidget {
  final SupportMessage message;
  
  const _SystemMessageBubble({required this.message});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.content,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 8. File Structure

```
lib/features/support/
├── data/
│   ├── models/
│   │   ├── models.dart                    # Barrel export
│   │   ├── support_ticket.dart
│   │   ├── support_message.dart
│   │   ├── ticket_attachment.dart
│   │   ├── device_context.dart
│   │   └── support_enums.dart
│   └── repositories/
│       ├── support_repository.dart
│       └── support_attachment_repository.dart
├── domain/
│   └── services/
│       ├── support_service.dart
│       └── device_info_service.dart
├── presentation/
│   ├── pages/
│   │   ├── support_hub_page.dart          # Entry point
│   │   ├── new_ticket_page.dart
│   │   ├── ticket_list_page.dart
│   │   └── ticket_detail_page.dart
│   ├── view_models/
│   │   ├── new_ticket_view_model.dart
│   │   ├── ticket_list_view_model.dart
│   │   └── ticket_detail_view_model.dart
│   └── widgets/
│       ├── ticket_type_selector.dart
│       ├── category_dropdown.dart
│       ├── attachment_picker.dart
│       ├── ticket_card.dart
│       ├── ticket_status_chip.dart
│       ├── message_bubble.dart
│       ├── message_input.dart
│       └── satisfaction_rating_dialog.dart
└── support_feature.dart                    # Feature registration

functions/src/support/
├── index.ts
├── onTicketCreate.ts
├── onMessageCreate.ts
├── scheduledTasks.ts
└── adminActions.ts

test/features/support/
├── data/
│   ├── models/
│   │   └── support_ticket_test.dart
│   └── repositories/
│       └── support_repository_test.dart
├── domain/
│   └── services/
│       └── support_service_test.dart
├── presentation/
│   ├── pages/
│   │   ├── new_ticket_page_test.dart
│   │   └── ticket_list_page_test.dart
│   └── widgets/
│       ├── ticket_card_test.dart
│       └── message_bubble_test.dart
└── integration/
    └── support_flow_test.dart
```

---

## 9. Firestore Security Rules

```javascript
// firestore.rules additions for support

match /support_tickets/{ticketId} {
  // Users can read their own tickets
  allow read: if request.auth != null 
              && resource.data.userId == request.auth.uid;
  
  // Authenticated users can create tickets
  allow create: if request.auth != null
                && request.resource.data.userId == request.auth.uid
                && request.resource.data.subject.size() > 0
                && request.resource.data.subject.size() <= 100
                && request.resource.data.description.size() > 0
                && request.resource.data.description.size() <= 5000;
  
  // Users can only update certain fields (rating)
  allow update: if request.auth != null
                && resource.data.userId == request.auth.uid
                && request.resource.data.diff(resource.data).affectedKeys()
                   .hasOnly(['userSatisfactionRating', 'userSatisfactionComment']);
  
  // No direct delete
  allow delete: if false;
  
  // Messages subcollection
  match /messages/{messageId} {
    // Users can read messages on their tickets
    allow read: if request.auth != null
                && get(/databases/$(database)/documents/support_tickets/$(ticketId)).data.userId == request.auth.uid;
    
    // Users can create user messages
    allow create: if request.auth != null
                  && get(/databases/$(database)/documents/support_tickets/$(ticketId)).data.userId == request.auth.uid
                  && request.resource.data.senderType == 'user'
                  && request.resource.data.senderId == request.auth.uid
                  && request.resource.data.content.size() > 0;
    
    // Users can mark messages as read
    allow update: if request.auth != null
                  && get(/databases/$(database)/documents/support_tickets/$(ticketId)).data.userId == request.auth.uid
                  && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readAt']);
    
    allow delete: if false;
  }
}

match /support_counters/{counterId} {
  allow read, write: if false;  // Only Cloud Functions
}

match /support_analytics/{periodId} {
  allow read, write: if false;  // Only Cloud Functions / Admin
}
```

---

## 10. Implementation Phases

### Phase Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 1 (Days 1-4)                           │
│         Foundation: Data Models & Repository Layer              │
├─────────────────────────────────────────────────────────────────┤
│                    PHASE 2 (Days 5-8)                           │
│         Core: Support Service & Ticket Submission               │
├─────────────────────────────────────────────────────────────────┤
│                    PHASE 3 (Days 9-12)                          │
│         Frontend: Ticket List & Detail Pages                    │
├─────────────────────────────────────────────────────────────────┤
│                    PHASE 4 (Days 13-16)                         │
│         Communication: Messaging & Real-time Updates            │
├─────────────────────────────────────────────────────────────────┤
│                    PHASE 5 (Days 17-19)                         │
│         Backend: Cloud Functions & Notifications                │
├─────────────────────────────────────────────────────────────────┤
│                    PHASE 6 (Days 20-22)                         │
│         Polish: Satisfaction Ratings, Analytics & Testing       │
└─────────────────────────────────────────────────────────────────┘

Total Estimated Time: ~3-4 weeks
```

---

## 11. Integration Points

| Feature | Integration |
|---------|-------------|
| **Profile/Settings** | "Help & Support" menu item linking to Support Hub |
| **Error Handling** | Option to report error with auto-populated context |
| **Call End** | Quick feedback prompt after calls |
| **Push Notifications** | Notify on support responses |
| **Deep Linking** | Open specific ticket from notification |
| **Analytics** | Track support interactions |

### Entry Points

```dart
// From Settings/Profile page
ListTile(
  leading: const Icon(Icons.help_outline),
  title: const Text('Help & Support'),
  onTap: () => Navigator.pushNamed(context, '/support'),
),

// From Error Dialog
ElevatedButton(
  onPressed: () => Navigator.pushNamed(
    context, 
    '/support/new',
    arguments: NewTicketArgs(
      type: TicketType.bug,
      prefillDescription: errorDetails,
    ),
  ),
  child: const Text('Report this Issue'),
),
```

---

## 12. Analytics & Reporting

### Metrics to Track

```dart
class SupportAnalytics {
  // Ticket lifecycle
  void trackTicketCreated(TicketType type, TicketCategory category);
  void trackTicketViewed(String ticketId);
  void trackMessageSent(String ticketId, bool isFirstMessage);
  void trackTicketResolved(String ticketId, Duration resolutionTime);
  void trackSatisfactionRated(String ticketId, int rating);
  
  // User behavior
  void trackSupportHubOpened();
  void trackTypeSelected(TicketType type);
  void trackAttachmentAdded(int count);
  void trackTicketAbandoned(TicketType type, String lastField);
}
```

### Key Performance Indicators

| KPI | Description | Target |
|-----|-------------|--------|
| **Resolution Time** | Time from creation to resolution | < 48 hours |
| **First Response Time** | Time to first support response | < 4 hours |
| **Satisfaction Score** | Average user rating | > 4.0/5.0 |
| **Resolution Rate** | % of tickets resolved | > 95% |
| **Abandonment Rate** | % of started but not submitted tickets | < 20% |

---

## Appendix A: Dependencies

```yaml
# pubspec.yaml additions
dependencies:
  device_info_plus: ^9.0.0      # Device information
  package_info_plus: ^4.0.0     # App version info
  image_picker: ^1.0.0          # Attachment picker
  intl: ^0.18.0                 # Date formatting
```

---

## Appendix B: Error Handling

```dart
enum SupportError {
  // Validation
  invalidSubject,
  subjectTooLong,
  invalidDescription,
  descriptionTooLong,
  tooManyAttachments,
  attachmentTooLarge,
  invalidFileType,
  
  // Auth
  notAuthenticated,
  
  // Ticket
  ticketNotFound,
  accessDenied,
  ticketClosed,
  
  // Message
  invalidMessage,
  messageTooLong,
  
  // Rating
  invalidRating,
  cannotRateUnresolvedTicket,
  alreadyRated,
  
  // Network
  networkError,
  uploadFailed,
  
  // General
  unknown;
}
```

---

*This design provides a complete, production-ready customer support system that integrates seamlessly with the existing GreenHive architecture.*
