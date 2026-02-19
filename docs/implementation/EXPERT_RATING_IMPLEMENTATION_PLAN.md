# Expert Rating System - Implementation Plan

**Version:** 2.0 (Simplified)  
**Status:** Ready for Implementation  
**Based on:** EXPERT_RATING_SYSTEM_DESIGN.md  
**Estimated Duration:** 1.5-2 weeks  

---

## 📋 Overview

This document outlines the phased implementation plan for the simplified Expert Rating System. The design focuses on core functionality:

- **1-5 star rating** for experts
- **Optional brief comment** (200 characters)
- **Anonymous submission** option
- **Rating display** on expert profiles

### What's NOT Included (Simplified Out)

- Category-based ratings (communication, expertise, etc.)
- Quick feedback tags
- Expert responses to reviews
- Review reporting/moderation
- Helpfulness voting
- Push notification reminders

---

## 🎯 Implementation Phases Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 1 (Days 1-3)                           │
│         Data Models, Repository & Cloud Function                │
├─────────────────────────────────────────────────────────────────┤
│                    PHASE 2 (Days 4-6)                           │
│         Rating Service & Submission UI                          │
├─────────────────────────────────────────────────────────────────┤
│                    PHASE 3 (Days 7-9)                           │
│         Expert Profile Integration & Reviews Page               │
├─────────────────────────────────────────────────────────────────┤
│                    PHASE 4 (Days 10-11)                         │
│         User Flow Integration & Testing                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 Phase 1: Foundation - Data Layer & Cloud Function

**Duration:** 3 days  
**Dependencies:** None  
**Deliverables:** Rating model, repository, Cloud Function deployed

### Tasks

#### 1.1 Create Rating Model (0.5 day)

| Task | File | Priority |
|------|------|----------|
| Create `Rating` model | `lib/features/ratings/data/models/rating.dart` | P0 |
| Create barrel export | `lib/features/ratings/data/models/models.dart` | P0 |

**Rating Model:**
```dart
class Rating {
  final String id;
  final String expertId;
  final String expertName;
  final String userId;
  final String? userName;
  final String? bookingId;
  final int stars;              // 1-5
  final String? comment;        // Optional, max 200 chars
  final bool isAnonymous;
  final DateTime createdAt;
}
```

**Acceptance Criteria:**
- [ ] Model has `fromJson` and `toJson` methods
- [ ] Model has `fromFirestore` factory
- [ ] Unit tests for serialization

#### 1.2 Create Rating Repository (1 day)

| Task | File | Priority |
|------|------|----------|
| Create `RatingRepository` | `lib/features/ratings/data/repositories/rating_repository.dart` | P0 |

**Repository Methods:**
```dart
Future<String> createRating(Rating rating);
Future<Rating?> getRatingByBooking(String bookingId);
Future<List<Rating>> getExpertRatings(String expertId, {int limit, Rating? lastRating});
Future<List<Rating>> getUserRatings(String userId);
```

**Acceptance Criteria:**
- [ ] Repository follows existing patterns
- [ ] Error handling with `ErrorHandler`
- [ ] Logging with `AppLogger`
- [ ] Unit tests with mocked Firestore

#### 1.3 Deploy Cloud Function (1 day)

| Task | File | Priority |
|------|------|----------|
| Create `onRatingCreated` trigger | `functions/src/ratings/index.ts` | P0 |
| Export in main index | `functions/src/index.ts` | P0 |

**Function Logic:**
1. Trigger on `ratings/{ratingId}` create
2. Fetch all ratings for the expert
3. Calculate average and count
4. Update `experts/{expertId}.rating` field

**Acceptance Criteria:**
- [ ] Function triggers on new rating
- [ ] Expert document updated with averageRating and totalRatings
- [ ] Handles first rating correctly
- [ ] Function deployed to Firebase

#### 1.4 Update Firestore Configuration (0.5 day)

| Task | File | Priority |
|------|------|----------|
| Add Firestore indexes | `firestore.indexes.json` | P0 |
| Update security rules | `firestore.rules` | P0 |

**Indexes:**
- `ratings`: `expertId` ASC, `createdAt` DESC
- `ratings`: `userId` ASC, `createdAt` DESC
- `ratings`: `bookingId` ASC

**Security Rules:**
- Anyone can read ratings
- Authenticated users can create (own userId, valid stars 1-5)
- No update/delete allowed

**Acceptance Criteria:**
- [ ] Indexes deployed
- [ ] Security rules deployed
- [ ] Rules tested with emulator

---

## 🎨 Phase 2: Service & Submission UI

**Duration:** 3 days  
**Dependencies:** Phase 1 complete  
**Deliverables:** Rating submission flow working

### Tasks

#### 2.1 Create Rating Service (1 day)

| Task | File | Priority |
|------|------|----------|
| Create `RatingService` | `lib/features/ratings/services/rating_service.dart` | P0 |
| Register in service locator | `lib/core/service_locator.dart` | P0 |

**Service Methods:**
```dart
Future<Rating> submitRating({
  required String expertId,
  required String expertName,
  required String bookingId,
  required int stars,
  String? comment,
  bool isAnonymous = false,
});

Future<List<Rating>> getExpertRatings({
  required String expertId,
  int limit = 20,
  Rating? lastRating,
});

Future<List<Rating>> getMyRatings();
```

**Acceptance Criteria:**
- [ ] Validates stars (1-5)
- [ ] Prevents duplicate rating per booking
- [ ] Trims and validates comment length
- [ ] Unit tests with 80%+ coverage

#### 2.2 Create UI Widgets (1 day)

| Task | File | Priority |
|------|------|----------|
| Create `StarRatingInput` | `lib/features/ratings/widgets/star_rating_input.dart` | P0 |
| Create `RatingCard` | `lib/features/ratings/widgets/rating_card.dart` | P0 |
| Create `ExpertRatingSummary` | `lib/features/ratings/widgets/expert_rating_summary.dart` | P0 |

**Acceptance Criteria:**
- [ ] Widgets follow app theme
- [ ] StarRatingInput allows tap to select 1-5
- [ ] RatingCard displays user name, date, stars, comment
- [ ] ExpertRatingSummary shows average + count
- [ ] Widget tests for interactions

#### 2.3 Create Rating Submission Page (1 day)

| Task | File | Priority |
|------|------|----------|
| Create `RatingViewModel` | `lib/features/ratings/view_models/rating_view_model.dart` | P0 |
| Create `RatingPage` | `lib/features/ratings/pages/rating_page.dart` | P0 |
| Add navigation route | Router configuration | P0 |

**Page Elements:**
1. Expert name and session date display
2. Star rating input (required)
3. Comment text field (optional, 200 chars max)
4. Anonymous checkbox
5. Submit button with loading state

**Acceptance Criteria:**
- [ ] All form elements work correctly
- [ ] Submit disabled until stars selected
- [ ] Loading state during submission
- [ ] Success snackbar and navigation back
- [ ] Error handling with snackbar

---

## 🔗 Phase 3: Profile Integration & Reviews Page

**Duration:** 3 days  
**Dependencies:** Phase 2 complete  
**Deliverables:** Ratings visible on expert profile

### Tasks

#### 3.1 Update Expert Details Page (1 day)

| Task | File | Priority |
|------|------|----------|
| Add `ExpertRatingSummary` to expert details | `lib/features/home/pages/expert_details_page.dart` | P0 |
| Display recent reviews (2-3) | Same file | P0 |
| Add "See all reviews" link | Same file | P0 |

**Integration:**
- Show rating below expert name: ★ 4.7 (42 reviews)
- Show 2-3 recent reviews
- "See all reviews" navigates to full list

**Acceptance Criteria:**
- [ ] Rating loads with expert data
- [ ] Graceful handling when no ratings
- [ ] Navigation to reviews page works

#### 3.2 Create Expert Reviews Page (1.5 days)

| Task | File | Priority |
|------|------|----------|
| Create `ExpertReviewsViewModel` | `lib/features/ratings/view_models/expert_reviews_view_model.dart` | P0 |
| Create `ExpertReviewsPage` | `lib/features/ratings/pages/expert_reviews_page.dart` | P0 |

**Page Features:**
- Header with expert name and rating summary
- List of all reviews with pagination
- Load more on scroll
- Empty state when no reviews

**Acceptance Criteria:**
- [ ] Pagination works correctly
- [ ] Performance acceptable (< 2s load)
- [ ] Empty state displayed properly

#### 3.3 Update Expert Card (0.5 day)

| Task | File | Priority |
|------|------|----------|
| Add rating display to `ExpertCard` | `lib/features/home/widgets/expert_card.dart` | P0 |

**Display:** ★ 4.7 (42)

**Acceptance Criteria:**
- [ ] Rating shows on expert list cards
- [ ] Handles experts with no ratings

---

## 🚀 Phase 4: User Flow Integration & Testing

**Duration:** 2 days  
**Dependencies:** Phase 3 complete  
**Deliverables:** Complete user flow, all tests passing

### Tasks

#### 4.1 After-Session Rating Prompt (1 day)

| Task | File | Priority |
|------|------|----------|
| Show rating modal after session ends | Session/call completion handler | P0 |
| Pass booking details to rating page | Navigation | P0 |

**Flow:**
1. Session ends (call disconnects)
2. Show rating modal/page immediately
3. User can submit or dismiss
4. If dismissed, can rate later from booking history

**Acceptance Criteria:**
- [ ] Rating modal appears after session
- [ ] Dismiss option available
- [ ] Booking info passed correctly

#### 4.2 Booking History Integration (0.5 day)

| Task | File | Priority |
|------|------|----------|
| Add "Rate" button to completed bookings | Booking history page | P0 |
| Show rating status (rated/unrated) | Same file | P0 |

**Display:**
- Unrated completed bookings: "Rate Now" button
- Rated bookings: Show stars given (★★★★★)

**Acceptance Criteria:**
- [ ] Rate button navigates to rating page
- [ ] Already rated bookings show the rating
- [ ] Only completed bookings can be rated

#### 4.3 Testing (0.5 day)

| Task | Type | Priority |
|------|------|----------|
| Unit tests for Rating model | Unit | P0 |
| Unit tests for RatingRepository | Unit | P0 |
| Unit tests for RatingService | Unit | P0 |
| Widget tests for StarRatingInput | Widget | P0 |
| Widget tests for RatingCard | Widget | P0 |
| Integration test for submission flow | Integration | P1 |

**Coverage Target:** 80% for core files

**Acceptance Criteria:**
- [ ] All tests pass
- [ ] No regression in existing tests

---

## 📁 Final File Structure

```
lib/features/ratings/
├── data/
│   ├── models/
│   │   ├── models.dart              # Barrel export
│   │   └── rating.dart
│   └── repositories/
│       └── rating_repository.dart
├── services/
│   └── rating_service.dart
├── view_models/
│   ├── rating_view_model.dart
│   └── expert_reviews_view_model.dart
├── pages/
│   ├── rating_page.dart
│   └── expert_reviews_page.dart
└── widgets/
    ├── star_rating_input.dart
    ├── rating_card.dart
    └── expert_rating_summary.dart

functions/src/ratings/
└── index.ts                         # onRatingCreated function

test/features/ratings/
├── data/
│   ├── models/
│   │   └── rating_test.dart
│   └── repositories/
│       └── rating_repository_test.dart
├── services/
│   └── rating_service_test.dart
└── widgets/
    ├── star_rating_input_test.dart
    └── rating_card_test.dart
```

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] All tests passing
- [ ] Code review completed
- [ ] Firestore indexes deployed
- [ ] Security rules deployed
- [ ] Cloud Function deployed

### Deployment
- [ ] Deploy to staging
- [ ] QA verification
- [ ] Deploy to production

### Post-Deployment
- [ ] Verify Cloud Function triggers correctly
- [ ] Verify ratings display on expert profiles
- [ ] Monitor for errors

---

## 📊 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Cloud Function cold starts | Medium | Low | Acceptable for non-realtime aggregation |
| Duplicate ratings | Low | Medium | Check by bookingId before insert |
| Large number of reviews | Low | Low | Pagination implemented |

---

## 📝 Notes

1. **Booking Dependency**: Requires `bookingId` from existing booking system
2. **No Feature Flag Needed**: Simple feature, deploy directly
3. **Future Enhancements**: Expert responses, reporting, notifications can be added later (see design doc section 10)

---

*This implementation plan aligns with the simplified design in `EXPERT_RATING_SYSTEM_DESIGN.md`.*
