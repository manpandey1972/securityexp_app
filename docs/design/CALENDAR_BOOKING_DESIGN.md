# Calendar Booking System - Architecture & Design

## Overview

A calendar booking system allowing users to book time slots with experts, with a minimum duration of 1 hour.

---

## 1. Data Models

### Firestore Collections Structure

```
├── expert_availability/
│   └── {expertId}/
│       ├── weeklySchedule (subcollection)
│       │   └── {dayOfWeek} (mon, tue, wed...)
│       └── exceptions (subcollection)
│           └── {date} (2026-01-24)
│
├── bookings/
│   └── {bookingId}
│
├── booking_requests/
│   └── {requestId}
```

### Dart Models

```dart
// lib/features/booking/data/models/expert_availability.dart
class ExpertAvailability {
  final String expertId;
  final Map<DayOfWeek, DaySchedule> weeklySchedule;
  final int minBookingDurationMinutes; // default: 60
  final int maxBookingDurationMinutes; // default: 180
  final int bufferBetweenBookingsMinutes; // default: 15
  final int advanceBookingDays; // how far ahead can book (e.g., 30 days)
  final String timezone;
}

class DaySchedule {
  final bool isAvailable;
  final List<TimeWindow> windows; // e.g., 9AM-12PM, 2PM-6PM
}

class TimeWindow {
  final TimeOfDay start;
  final TimeOfDay end;
}

class AvailabilityException {
  final DateTime date;
  final ExceptionType type; // unavailable, custom_hours
  final List<TimeWindow>? customWindows;
  final String? reason;
}

// lib/features/booking/data/models/booking.dart
class Booking {
  final String id;
  final String expertId;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final BookingStatus status;
  final BookingType type; // video_call, audio_call, in_person
  final String? topic;
  final String? notes;
  final double? price;
  final String? paymentId;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final CancelledBy? cancelledBy;
}

enum BookingStatus {
  pending,      // awaiting expert confirmation
  confirmed,    // expert accepted
  cancelled,    // cancelled by either party
  completed,    // session finished
  noShow,       // user didn't join
}

class BookingRequest {
  final String id;
  final String expertId;
  final String userId;
  final List<ProposedSlot> proposedSlots; // user can propose multiple
  final int requestedDurationMinutes;
  final BookingType type;
  final String? message;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
}
```

---

## 2. Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
├─────────────────────────────────────────────────────────────┤
│  Pages:                    │  Widgets:                       │
│  • BookingCalendarPage     │  • CalendarGridWidget           │
│  • TimeSlotPickerPage      │  • TimeSlotCard                 │
│  • BookingConfirmationPage │  • AvailabilityIndicator        │
│  • MyBookingsPage          │  • BookingCard                  │
│  • ExpertSchedulePage      │  • DurationPicker               │
│                            │  • BookingStatusBadge           │
├─────────────────────────────────────────────────────────────┤
│  ViewModels:                                                 │
│  • BookingCalendarViewModel                                  │
│  • ExpertAvailabilityViewModel                               │
│  • MyBookingsViewModel                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER                              │
├─────────────────────────────────────────────────────────────┤
│  Services:                                                   │
│  • BookingService          - Core booking logic              │
│  • AvailabilityService     - Slot calculation & validation   │
│  • BookingNotificationSvc  - Reminders & updates             │
│  • CalendarSyncService     - External calendar integration   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                │
├─────────────────────────────────────────────────────────────┤
│  Repositories:                                               │
│  • BookingRepository       - CRUD for bookings               │
│  • AvailabilityRepository  - Expert schedule management      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE                            │
├─────────────────────────────────────────────────────────────┤
│  • Firestore (bookings, availability)                        │
│  • Cloud Functions (conflict detection, notifications)       │
│  • Cloud Scheduler (reminders, expiry cleanup)               │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Key Services Design

### AvailabilityService

```dart
class AvailabilityService {
  /// Get available time slots for an expert on a specific date
  Future<List<AvailableSlot>> getAvailableSlots({
    required String expertId,
    required DateTime date,
    required int durationMinutes, // minimum 60
  });

  /// Check if a specific time range is available
  Future<bool> isSlotAvailable({
    required String expertId,
    required DateTime start,
    required DateTime end,
  });

  /// Get expert's booked slots (for calendar display)
  Future<List<BookedSlot>> getBookedSlots({
    required String expertId,
    required DateTime startDate,
    required DateTime endDate,
  });
}
```

### BookingService

```dart
class BookingService {
  /// Create a new booking (with validation)
  Future<Result<Booking, BookingError>> createBooking({
    required String expertId,
    required DateTime startTime,
    required int durationMinutes,
    required BookingType type,
    String? topic,
    String? notes,
  });

  /// Cancel a booking
  Future<Result<void, BookingError>> cancelBooking({
    required String bookingId,
    required String reason,
  });

  /// Expert confirms/rejects a booking request
  Future<Result<Booking, BookingError>> respondToRequest({
    required String requestId,
    required bool accept,
    String? message,
  });

  /// Reschedule a booking
  Future<Result<Booking, BookingError>> rescheduleBooking({
    required String bookingId,
    required DateTime newStartTime,
  });
}
```

---

## 4. User Flows

### Flow 1: User Books Expert

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Expert       │     │ Calendar     │     │ Time Slot    │     │ Confirmation │
│ Profile      │────▶│ View         │────▶│ Selection    │────▶│ & Payment    │
│ "Book Now"   │     │ (Pick Date)  │     │ (Pick Time)  │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                            │                    │                     │
                            ▼                    ▼                     ▼
                     Load expert's        Show available         Create booking
                     availability         slots (1hr+)           Send notification
                     for 30 days          with pricing           to expert
```

### Flow 2: Expert Sets Availability

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Expert       │     │ Weekly       │     │ Exceptions   │
│ Settings     │────▶│ Schedule     │────▶│ (Days off,   │
│              │     │ Setup        │     │ holidays)    │
└──────────────┘     └──────────────┘     └──────────────┘
        │
        ▼
  ┌──────────────┐
  │ Sync with    │
  │ Google/Apple │
  │ Calendar     │
  └──────────────┘
```

---

## 5. UI Components

### Calendar View (Month)

```
┌─────────────────────────────────────────────┐
│  ◀  January 2026  ▶                         │
├─────────────────────────────────────────────┤
│  Su   Mo   Tu   We   Th   Fr   Sa           │
│                  1    2    3    4           │
│  5    6    7    8    9   10   11           │
│  12   13   14  [15]  16   17   18          │
│  19   20   21   22   23   24   25          │
│  26   27   28   29   30   31               │
├─────────────────────────────────────────────┤
│  ● Available  ○ Partially  ━ Unavailable   │
└─────────────────────────────────────────────┘
```

### Time Slot Picker

```
┌─────────────────────────────────────────────┐
│  Wednesday, January 15, 2026                │
├─────────────────────────────────────────────┤
│  Duration: [1 hour ▼]  [1.5 hr] [2 hr]     │
├─────────────────────────────────────────────┤
│  Morning                                    │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │ 9:00 AM │ │10:00 AM │ │11:00 AM │       │
│  │   $50   │ │   $50   │ │  Booked │       │
│  └─────────┘ └─────────┘ └─────────┘       │
│                                             │
│  Afternoon                                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │ 2:00 PM │ │ 3:00 PM │ │ 4:00 PM │       │
│  │   $50   │ │   $50   │ │   $50   │       │
│  └─────────┘ └─────────┘ └─────────┘       │
└─────────────────────────────────────────────┘
```

---

## 6. Firestore Security Rules

```javascript
// firestore.rules additions
match /expert_availability/{expertId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == expertId;
  
  match /weeklySchedule/{day} {
    allow read: if request.auth != null;
    allow write: if request.auth.uid == expertId;
  }
}

match /bookings/{bookingId} {
  allow read: if request.auth.uid == resource.data.userId 
              || request.auth.uid == resource.data.expertId;
  allow create: if request.auth.uid == request.resource.data.userId
                && request.resource.data.durationMinutes >= 60;
  allow update: if request.auth.uid in [resource.data.userId, resource.data.expertId];
}
```

---

## 7. Cloud Functions

```typescript
// functions/src/booking/index.ts

// 1. On booking created - notify expert
export const onBookingCreated = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    // Send push notification to expert
    // Send email confirmation to user
    // Create calendar event
  });

// 2. Booking reminder - 1 hour before
export const sendBookingReminders = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    // Find bookings starting in ~1 hour
    // Send push notifications to both parties
  });

// 3. Auto-complete bookings
export const autoCompleteBookings = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(async () => {
    // Mark past confirmed bookings as completed
  });

// 4. Conflict detection (on write)
export const validateBookingSlot = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    // Double-check no conflicts exist
    // If conflict, mark as cancelled with reason
  });
```

---

## 8. Integration Points

### With Existing Features

| Feature | Integration |
|---------|-------------|
| **Calling** | Auto-initiate call at booking start time |
| **Chat** | Create chat thread for booking communication |
| **Notifications** | Reminders, confirmations, cancellations |
| **Payments** | Pre-payment or post-session billing |
| **Profile** | Show expert's calendar on their profile |

### External Calendar Sync

```dart
class CalendarSyncService {
  // Import busy times from Google/Apple Calendar
  Future<List<BusySlot>> importBusyTimes(CalendarProvider provider);
  
  // Export booking to user's calendar
  Future<void> exportBookingToCalendar(Booking booking);
}
```

---

## 9. File Structure

```
lib/features/booking/
├── data/
│   ├── models/
│   │   ├── booking.dart
│   │   ├── expert_availability.dart
│   │   ├── time_slot.dart
│   │   └── booking_request.dart
│   └── repositories/
│       ├── booking_repository.dart
│       └── availability_repository.dart
├── domain/
│   └── services/
│       ├── booking_service.dart
│       ├── availability_service.dart
│       └── calendar_sync_service.dart
├── presentation/
│   ├── pages/
│   │   ├── booking_calendar_page.dart
│   │   ├── time_slot_picker_page.dart
│   │   ├── booking_confirmation_page.dart
│   │   ├── my_bookings_page.dart
│   │   └── expert_schedule_page.dart
│   ├── view_models/
│   │   ├── booking_calendar_view_model.dart
│   │   ├── expert_availability_view_model.dart
│   │   └── my_bookings_view_model.dart
│   └── widgets/
│       ├── calendar_grid.dart
│       ├── time_slot_card.dart
│       ├── duration_picker.dart
│       ├── booking_card.dart
│       └── availability_indicator.dart
└── booking_feature.dart  // Feature barrel export
```

---

## 10. Implementation Phases

| Phase | Scope | Estimate |
|-------|-------|----------|
| **Phase 1** | Data models, repositories, basic availability service | 1 week |
| **Phase 2** | Calendar UI, time slot picker, booking creation | 1.5 weeks |
| **Phase 3** | Expert availability management UI | 1 week |
| **Phase 4** | Notifications, reminders (Cloud Functions) | 1 week |
| **Phase 5** | Payment integration, calendar sync | 1.5 weeks |

**Total Estimated Time: ~6 weeks**

---

## 11. Recommended Flutter Packages

| Package | Purpose |
|---------|---------|
| `table_calendar` | Calendar grid widget |
| `intl` | Date/time formatting & timezone |
| `timezone` | Timezone handling |
| `googleapis` / `google_sign_in` | Google Calendar sync |
| `flutter_local_notifications` | Local reminders |

---

## 12. Edge Cases & Validation

### Business Rules

1. **Minimum booking duration**: 60 minutes (enforced at UI, service, and Firestore rules level)
2. **Buffer time**: 15 minutes between bookings by default
3. **Advance booking limit**: Configurable per expert (default: 30 days)
4. **Cancellation policy**: 
   - Free cancellation up to 24 hours before
   - 50% charge within 24 hours
   - No refund within 2 hours

### Conflict Resolution

- Use Firestore transactions for booking creation
- Cloud Function validates no overlapping bookings exist
- Optimistic locking with version field on availability documents

### Timezone Handling

- Store all times in UTC
- Expert sets their timezone in profile
- Convert to user's local timezone for display
- Use `timezone` package for accurate DST handling
