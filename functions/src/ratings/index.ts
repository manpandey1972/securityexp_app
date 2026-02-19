/**
 * Cloud Functions for Expert Ratings
 *
 * This module handles rating-related background processing:
 * - onRatingCreated: Aggregates ratings and updates expert profile
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {db} from "../utils";

// ============================================================================
// Types
// ============================================================================

interface RatingData {
  expertId?: string;
  expertName?: string;
  userId?: string;
  userName?: string;
  bookingId?: string;
  stars?: number;
  comment?: string;
  isAnonymous?: boolean;
  createdAt?: FirebaseFirestore.Timestamp;
}

interface ExpertRating {
  averageRating: number;
  totalRatings: number;
  lastRatingAt: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue;
}

// ============================================================================
// Rating Aggregation Function
// ============================================================================

/**
 * Triggered when a new rating is created.
 *
 * This function:
 * 1. Fetches all ratings for the expert
 * 2. Calculates the new average rating
 * 3. Updates the expert's user document with rating stats
 *
 * Document structure updated:
 * ```json
 * users/{expertId}: {
 *   "rating": {
 *     "averageRating": 4.5,
 *     "totalRatings": 42,
 *     "lastRatingAt": Timestamp
 *   }
 * }
 * ```
 */
export const onRatingCreated = onDocumentCreated(
  {
    document: "ratings/{ratingId}",
    database: "green-hive-db",
  },
  async (event) => {
    const {ratingId} = event.params;
    logger.info("🌟 Rating trigger invoked", {ratingId});

    const ratingData = event.data?.data() as RatingData | undefined;

    if (!ratingData) {
      logger.warn("❌ No rating data found", {ratingId});
      return;
    }

    const {expertId, userId, stars} = ratingData;

    if (!expertId) {
      logger.error("❌ Rating missing expertId", {ratingId});
      return;
    }

    // Prevent self-rating
    if (userId && userId === expertId) {
      logger.error("❌ Self-rating detected", {ratingId, userId, expertId});
      // Delete the invalid rating document
      await event.data?.ref.delete();
      return;
    }

    if (typeof stars !== "number" || stars < 1 || stars > 5) {
      logger.error("❌ Invalid stars value", {ratingId, stars});
      return;
    }

    try {
      // Verify the target user has the Expert role
      const expertDoc = await db.collection("users").doc(expertId).get();
      if (!expertDoc.exists) {
        logger.error("❌ Expert user document not found", {ratingId, expertId});
        await event.data?.ref.delete();
        return;
      }

      const expertData = expertDoc.data();
      const roles: string[] = expertData?.roles ?? [];
      if (!roles.includes("Expert")) {
        logger.error("❌ Target user is not an expert", {
          ratingId,
          expertId,
          roles,
        });
        // Delete the invalid rating document
        await event.data?.ref.delete();
        return;
      }

      // Fetch all ratings for this expert
      const ratingsSnapshot = await db
        .collection("ratings")
        .where("expertId", "==", expertId)
        .get();

      if (ratingsSnapshot.empty) {
        logger.warn("⚠️ No ratings found for expert after creation", {
          expertId,
          ratingId,
        });
        return;
      }

      // Calculate average
      let totalStars = 0;
      let count = 0;

      for (const doc of ratingsSnapshot.docs) {
        const data = doc.data() as RatingData;
        if (data.stars && data.stars >= 1 && data.stars <= 5) {
          totalStars += data.stars;
          count++;
        }
      }

      if (count === 0) {
        logger.warn("⚠️ No valid ratings found", {expertId});
        return;
      }

      const averageRating = Math.round((totalStars / count) * 10) / 10; // Round to 1 decimal

      // Update expert's user document with rating stats
      const expertRef = db.collection("users").doc(expertId);

      const ratingUpdate: ExpertRating = {
        averageRating,
        totalRatings: count,
        lastRatingAt: event.data?.createTime ||
          FirebaseFirestore.FieldValue.serverTimestamp(),
      };

      await expertRef.update({
        rating: ratingUpdate,
      });

      logger.info("✅ Expert rating stats updated", {
        expertId,
        averageRating,
        totalRatings: count,
        ratingId,
      });
    } catch (error) {
      logger.error("❌ Error updating expert rating stats", {
        expertId,
        ratingId,
        error,
      });
      throw error; // Re-throw to trigger retry
    }
  }
);

// Import FieldValue for serverTimestamp
import * as FirebaseFirestore from "firebase-admin/firestore";
