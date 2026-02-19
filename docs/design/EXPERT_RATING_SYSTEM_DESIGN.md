# Expert Rating System - Simplified Design

## Overview

A simple rating system that allows users to rate experts with 1-5 stars and an optional brief comment after completed sessions.

---

## 1. User Flow

### When Rating UI is Shown

Users can rate experts in two ways:

#### Primary: After Session Ends
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  User completes video/chat session with expert              │
│                         ↓                                   │
│  Session ends (call disconnects or chat closed)             │
│                         ↓                                   │
│  App immediately shows rating modal                         │
│                         ↓                                   │
│        ┌────────────────┴────────────────┐                 │
│        ↓                                 ↓                  │
│  User submits rating              User dismisses            │
│        ↓                          (can rate later)          │
│  Thank you message                       ↓                  │
│        ↓                          Booking marked as         │
│  Return to home                   "unrated"                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Fallback: From Booking History
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  User opens "My Bookings" page                              │
│                         ↓                                   │
│  Sees list of completed sessions                            │
│                         ↓                                   │
│  Unrated sessions show "Rate" button                        │
│  Already rated sessions show the star rating given          │
│                         ↓                                   │
│  User taps "Rate" button                                    │
│                         ↓                                   │
│  Rating modal appears                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Booking History UI

```
┌─────────────────────────────────────────────────────────────┐
│  My Bookings                                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 👤 Dr. Sarah Chen                                    │   │
│  │ 📅 Jan 24, 2026 • 1 hour session                    │   │
│  │ ✓ Completed                                          │   │
│  │                                    [ ★★★★★ Rated ]   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 👤 John Smith                                        │   │
│  │ 📅 Jan 20, 2026 • 30 min session                    │   │
│  │ ✓ Completed                                          │   │
│  │                                         [ Rate Now ]  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Data Models

### Firestore Collections Structure

```
├── ratings/
│   └── {ratingId}
│
├── experts/
│   └── {expertId}
│       └── rating (embedded field)
```

### Dart Models

```dart
// lib/features/ratings/data/models/rating.dart

class Rating {
  final String id;
  final String expertId;
  final String expertName;        // Denormalized for display
  final String userId;
  final String? userName;         // Null if anonymous
  final String? bookingId;
  final int stars;                // 1-5
  final String? comment;          // Optional brief comment
  final bool isAnonymous;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.expertId,
    required this.expertName,
    required this.userId,
    this.userName,
    this.bookingId,
    required this.stars,
    this.comment,
    this.isAnonymous = false,
    required this.createdAt,
  });
}

// Embedded in expert document
class ExpertRating {
  final double averageRating;
  final int totalRatings;

  const ExpertRating({
    this.averageRating = 0.0,
    this.totalRatings = 0,
  });
}
```

### Firestore Document Examples

**Rating Document (`ratings/{ratingId}`)**
```json
{
  "id": "rating_123",
  "expertId": "expert_456",
  "expertName": "Dr. Sarah Chen",
  "userId": "user_789",
  "userName": "John D.",
  "bookingId": "booking_012",
  "stars": 5,
  "comment": "Very helpful and knowledgeable!",
  "isAnonymous": false,
  "createdAt": "2026-01-24T10:30:00Z"
}
```

**Expert Document Rating Field (`experts/{expertId}`)**
```json
{
  "name": "Dr. Sarah Chen",
  "rating": {
    "averageRating": 4.7,
    "totalRatings": 42
  }
}
```

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
├─────────────────────────────────────────────────────────────┤
│  Pages:                    │  Widgets:                       │
│  • RatingPage              │  • StarRatingInput              │
│  • ExpertReviewsPage       │  • RatingCard                   │
│                            │  • ExpertRatingSummary          │
├─────────────────────────────────────────────────────────────┤
│  ViewModels:                                                 │
│  • RatingViewModel                                           │
│  • ExpertReviewsViewModel                                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    SERVICE LAYER                             │
├─────────────────────────────────────────────────────────────┤
│  RatingService                                               │
│  • submitRating()                                            │
│  • getExpertRatings()                                        │
│  • getUserRatings()                                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                │
├─────────────────────────────────────────────────────────────┤
│  RatingRepository                                            │
│  • CRUD operations for ratings collection                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. RatingService

```dart
// lib/features/ratings/services/rating_service.dart

class RatingService {
  final RatingRepository _repository;
  final AuthService _authService;

  /// Submit a new rating
  Future<Rating> submitRating({
    required String expertId,
    required String expertName,
    String? bookingId,
    required int stars,
    String? comment,
    bool isAnonymous = false,
  }) async {
    // Validate stars
    if (stars < 1 || stars > 5) {
      throw RatingException('Rating must be between 1 and 5 stars');
    }

    // Check for existing rating on this booking
    if (bookingId != null) {
      final existing = await _repository.getRatingByBooking(bookingId);
      if (existing != null) {
        throw RatingException('You have already rated this session');
      }
    }

    final user = _authService.currentUser;
    final rating = Rating(
      id: _uuid.v4(),
      expertId: expertId,
      expertName: expertName,
      userId: user!.uid,
      userName: isAnonymous ? null : user.displayName,
      bookingId: bookingId,
      stars: stars,
      comment: comment?.trim(),
      isAnonymous: isAnonymous,
      createdAt: DateTime.now(),
    );

    await _repository.createRating(rating);
    return rating;
  }

  /// Get all ratings for an expert (paginated)
  Future<List<Rating>> getExpertRatings({
    required String expertId,
    int limit = 20,
    Rating? lastRating,
  }) {
    return _repository.getExpertRatings(
      expertId: expertId,
      limit: limit,
      lastRating: lastRating,
    );
  }

  /// Get all ratings by current user
  Future<List<Rating>> getMyRatings() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return Future.value([]);
    return _repository.getUserRatings(userId);
  }
}
```

---

## 5. Cloud Function

A single Cloud Function updates the expert's average rating when ratings are added.

```typescript
// functions/src/ratings/index.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Update expert's average rating when a rating is created
 */
export const onRatingCreated = functions.firestore
  .document('ratings/{ratingId}')
  .onCreate(async (snapshot) => {
    const rating = snapshot.data();
    const expertId = rating.expertId;

    await updateExpertRating(expertId);
  });

async function updateExpertRating(expertId: string) {
  const ratingsSnap = await admin.firestore()
    .collection('ratings')
    .where('expertId', '==', expertId)
    .get();

  if (ratingsSnap.empty) {
    await admin.firestore()
      .collection('experts')
      .doc(expertId)
      .update({
        'rating.averageRating': 0,
        'rating.totalRatings': 0,
      });
    return;
  }

  const ratings = ratingsSnap.docs.map(d => d.data());
  const totalStars = ratings.reduce((sum, r) => sum + r.stars, 0);
  const averageRating = Math.round((totalStars / ratings.length) * 10) / 10;

  await admin.firestore()
    .collection('experts')
    .doc(expertId)
    .update({
      'rating.averageRating': averageRating,
      'rating.totalRatings': ratings.length,
    });
}
```

---

## 6. UI Design

### Rating Submission

```
┌─────────────────────────────────────────────────────────────┐
│  Rate Your Session                              [X Close]   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  👤 Dr. Sarah Chen                                         │
│  📅 Jan 24, 2026                                           │
│                                                             │
│  How was your experience?                                   │
│                                                             │
│          ★  ★  ★  ★  ☆                                    │
│             4 out of 5                                      │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  Leave a comment (optional)                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Very helpful and knowledgeable...                    │   │
│  │                                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                            200 characters   │
│                                                             │
│  ☐ Submit anonymously                                       │
│                                                             │
│              [ Submit Rating ]                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Expert Profile Rating Display

```
┌─────────────────────────────────────────────────────────────┐
│  ★ 4.7  (42 reviews)                     [See all reviews] │
└─────────────────────────────────────────────────────────────┘
```

### Reviews List

```
┌─────────────────────────────────────────────────────────────┐
│  Reviews (42)                                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │ John D.                           ★★★★★  5 stars   │   │
│  │ Jan 24, 2026                                        │   │
│  │                                                      │   │
│  │ "Very helpful and knowledgeable! Would definitely   │   │
│  │  recommend."                                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Anonymous                         ★★★★☆  4 stars   │   │
│  │ Jan 22, 2026                                        │   │
│  │                                                      │   │
│  │ "Good session overall."                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│              [ Load More Reviews ]                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Widgets

### StarRatingInput

```dart
// lib/features/ratings/widgets/star_rating_input.dart

class StarRatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return GestureDetector(
          onTap: () => onChanged(starNumber),
          child: Icon(
            starNumber <= rating ? Icons.star : Icons.star_border,
            color: AppColors.starYellow,
            size: size,
          ),
        );
      }),
    );
  }
}
```

### RatingCard

```dart
// lib/features/ratings/widgets/rating_card.dart

class RatingCard extends StatelessWidget {
  final Rating rating;

  const RatingCard({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rating.isAnonymous ? 'Anonymous' : (rating.userName ?? 'User'),
                  style: AppTypography.bodyEmphasis,
                ),
                Row(
                  children: List.generate(5, (i) => Icon(
                    i < rating.stars ? Icons.star : Icons.star_border,
                    color: AppColors.starYellow,
                    size: 16,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(rating.createdAt),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (rating.comment != null) ...[
              const SizedBox(height: 8),
              Text(
                rating.comment!,
                style: AppTypography.bodyRegular,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
```

### ExpertRatingSummary

```dart
// lib/features/ratings/widgets/expert_rating_summary.dart

class ExpertRatingSummary extends StatelessWidget {
  final double averageRating;
  final int totalRatings;
  final VoidCallback? onTap;

  const ExpertRatingSummary({
    super.key,
    required this.averageRating,
    required this.totalRatings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.star, color: AppColors.starYellow, size: 20),
          const SizedBox(width: 4),
          Text(
            averageRating.toStringAsFixed(1),
            style: AppTypography.bodyEmphasis,
          ),
          const SizedBox(width: 4),
          Text(
            '($totalRatings ${totalRatings == 1 ? 'review' : 'reviews'})',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16),
          ],
        ],
      ),
    );
  }
}
```

---

## 8. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Ratings collection
    match /ratings/{ratingId} {
      // Anyone can read ratings
      allow read: if true;
      
      // Authenticated users can create ratings
      allow create: if request.auth != null
        && request.resource.data.userId == request.auth.uid
        && request.resource.data.stars >= 1
        && request.resource.data.stars <= 5;
      
      // Users cannot update or delete ratings
      allow update, delete: if false;
    }
  }
}
```

---

## 9. Implementation Checklist

### Phase 1: Core Implementation
- [ ] Create Rating model
- [ ] Create RatingRepository
- [ ] Create RatingService
- [ ] Deploy Cloud Function for rating aggregation

### Phase 2: UI Implementation
- [ ] Create StarRatingInput widget
- [ ] Create RatingCard widget
- [ ] Create ExpertRatingSummary widget
- [ ] Create RatingPage for submission
- [ ] Create ExpertReviewsPage for listing

### Phase 3: Integration
- [ ] Add rating prompt after booking completion
- [ ] Display ratings on expert profile
- [ ] Show rating summary in expert search results

---

## 10. Future Enhancements (Optional)

These features are not in scope but could be added later:
- Edit/delete rating within 24 hours
- Report inappropriate reviews
- Expert responses to reviews
- Helpful/unhelpful voting on reviews
- Category-based ratings (communication, expertise, etc.)
- Rating distribution chart
