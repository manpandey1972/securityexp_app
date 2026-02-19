/**
 * Account Deletion Cloud Function (Background / Firestore-triggered)
 *
 * Handles complete user data cleanup for GDPR/privacy compliance.
 * Uses Admin SDK to bypass security rules and ensure all data is removed.
 *
 * Flow:
 * 1. Client writes a document to `deletion_requests/{userId}`
 * 2. This function triggers on that document creation
 * 3. Function updates the request document with status as it progresses
 * 4. Client does NOT wait — it signs out immediately after writing the request
 *
 * Data cleaned up:
 * - Firestore: user doc + subcollections, chat rooms + messages, call data,
 *   ratings, support tickets, presence, FCM tokens
 * - Storage: profile pictures, chat attachments, support attachments
 * - RTDB: presence data
 * - Auth: Firebase Auth account
 */

import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {db} from "./utils";

const BATCH_SIZE = 500;

/**
 * Delete all documents in a collection/subcollection in batches.
 */
async function deleteCollection(
  collectionRef: admin.firestore.CollectionReference,
  label: string,
): Promise<number> {
  let totalDeleted = 0;
  let snapshot = await collectionRef.limit(BATCH_SIZE).get();

  while (!snapshot.empty) {
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    totalDeleted += snapshot.docs.length;
    logger.info(`🗑️ Deleted ${snapshot.docs.length} docs from ${label}`, {totalDeleted});

    if (snapshot.docs.length < BATCH_SIZE) break;
    snapshot = await collectionRef.limit(BATCH_SIZE).get();
  }

  return totalDeleted;
}

/**
 * Delete all files under a Storage prefix (folder).
 */
async function deleteStorageFolder(prefix: string): Promise<number> {
  try {
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({prefix});

    if (files.length === 0) return 0;

    await Promise.all(files.map((file) => file.delete().catch((e) => {
      logger.warn(`Failed to delete storage file: ${file.name}`, {error: String(e)});
    })));

    logger.info(`🗑️ Deleted ${files.length} storage files under ${prefix}`);
    return files.length;
  } catch (error) {
    logger.warn(`No storage folder or error for prefix ${prefix}`, {error: String(error)});
    return 0;
  }
}

/**
 * Firestore-triggered account deletion.
 * Triggers when a document is created at `deletion_requests/{userId}`.
 */
export const onAccountDeletionRequested = onDocumentCreated(
  {
    document: "deletion_requests/{userId}",
    database: "green-hive-db",
  },
  async (event) => {
    const userId = event.params.userId;
    const requestRef = db.collection("deletion_requests").doc(userId);

    logger.info("🔒 Account deletion triggered", {userId});

    // Mark as processing
    await requestRef.update({
      status: "processing",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const summary: Record<string, number> = {};

  try {
    // ================================================================
    // 1. Delete user document subcollections
    // ================================================================
    const userDocRef = db.collection("users").doc(userId);

    // 1a. users/{userId}/rooms/*
    summary.userRooms = await deleteCollection(
      userDocRef.collection("rooms"),
      `users/${userId}/rooms`,
    );

    // 1b. users/{userId}/incoming_calls/*
    summary.incomingCalls = await deleteCollection(
      userDocRef.collection("incoming_calls"),
      `users/${userId}/incoming_calls`,
    );

    // 1c. users/{userId}/call_history/*
    summary.userCallHistory = await deleteCollection(
      userDocRef.collection("call_history"),
      `users/${userId}/call_history`,
    );

    // 1d. Delete the user document itself
    await userDocRef.delete();
    summary.userDoc = 1;
    logger.info("✅ User document and subcollections deleted", {userId});

    // ================================================================
    // 2. Delete chat rooms where user is a participant
    //    Room ID format: {sortedUserId1}_{sortedUserId2}
    // ================================================================
    const chatRoomsSnapshot = await db
      .collection("chat_rooms")
      .where("participants", "array-contains", userId)
      .get();

    let chatRoomsDeleted = 0;
    let chatMessagesDeleted = 0;
    let chatAttachmentsDeleted = 0;

    for (const roomDoc of chatRoomsSnapshot.docs) {
      const roomId = roomDoc.id;
      const participants = (roomDoc.data().participants as string[]) || [];

      // 2a. Delete all messages in the room
      chatMessagesDeleted += await deleteCollection(
        db.collection("chat_rooms").doc(roomId).collection("messages"),
        `chat_rooms/${roomId}/messages`,
      );

      // 2b. Delete chat attachments from Storage
      chatAttachmentsDeleted += await deleteStorageFolder(`chat_attachments/${roomId}/`);

      // 2c. Delete room tracking docs from the OTHER participant's user subcollection
      for (const participantId of participants) {
        if (participantId !== userId) {
          try {
            await db
              .collection("users")
              .doc(participantId)
              .collection("rooms")
              .doc(roomId)
              .delete();
          } catch (e) {
            logger.warn(`Failed to delete room tracking for ${participantId}`, {roomId});
          }

          // Also decrement the other user's totalUnreadCount if needed
          try {
            const otherRoomDoc = await db
              .collection("users")
              .doc(participantId)
              .collection("rooms")
              .doc(roomId)
              .get();
            const unread = otherRoomDoc.data()?.unreadCount || 0;
            if (unread > 0) {
              await db.collection("users").doc(participantId).update({
                totalUnreadCount: admin.firestore.FieldValue.increment(-unread),
              });
            }
          } catch (e) {
            // Room doc may already be deleted above, that's OK
          }
        }
      }

      // 2d. Delete the chat room document
      await db.collection("chat_rooms").doc(roomId).delete();
      chatRoomsDeleted++;
    }

    summary.chatRooms = chatRoomsDeleted;
    summary.chatMessages = chatMessagesDeleted;
    summary.chatAttachments = chatAttachmentsDeleted;
    logger.info("✅ Chat rooms cleaned up", {userId, chatRoomsDeleted});

    // Note: livekit_rooms and active_calls have TTL expiration configured.
    // Legacy WebRTC (active_calls) is deprecated and won't be reintroduced.
    // No manual cleanup needed.

    // ================================================================
    // 3. Delete ratings authored by user
    // ================================================================
    const userRatings = await db
      .collection("ratings")
      .where("userId", "==", userId)
      .get();
    let ratingsDeleted = 0;
    for (const doc of userRatings.docs) {
      await doc.ref.delete();
      ratingsDeleted++;
    }

    // Anonymize ratings where user was the expert (preserve aggregate data)
    const expertRatings = await db
      .collection("ratings")
      .where("expertId", "==", userId)
      .get();
    let ratingsAnonymized = 0;
    for (const doc of expertRatings.docs) {
      await doc.ref.update({
        expertId: "deleted_user",
        expertName: "Deleted User",
      });
      ratingsAnonymized++;
    }

    summary.ratingsDeleted = ratingsDeleted;
    summary.ratingsAnonymized = ratingsAnonymized;

    // ================================================================
    // 4. Delete support tickets + subcollections
    // ================================================================
    const supportTickets = await db
      .collection("support_tickets")
      .where("userId", "==", userId)
      .get();
    let ticketsDeleted = 0;

    for (const ticketDoc of supportTickets.docs) {
      const ticketId = ticketDoc.id;

      // Delete messages subcollection
      await deleteCollection(
        db.collection("support_tickets").doc(ticketId).collection("messages"),
        `support_tickets/${ticketId}/messages`,
      );

      // Delete internal notes subcollection
      await deleteCollection(
        db.collection("support_tickets").doc(ticketId).collection("internal_notes"),
        `support_tickets/${ticketId}/internal_notes`,
      );

      // Delete support attachments from Storage
      await deleteStorageFolder(`support/${ticketId}/`);

      // Delete the ticket document
      await ticketDoc.ref.delete();
      ticketsDeleted++;
    }

    summary.supportTickets = ticketsDeleted;

    // ================================================================
    // 5. Delete FAQ feedback submitted by user
    // ================================================================
    const faqFeedback = await db
      .collection("faq_feedback")
      .where("userId", "==", userId)
      .get();
    let feedbackDeleted = 0;
    for (const doc of faqFeedback.docs) {
      await doc.ref.delete();
      feedbackDeleted++;
    }
    summary.faqFeedback = feedbackDeleted;

    // ================================================================
    // 6. Delete profile pictures from Storage
    // ================================================================
    summary.profilePictures = await deleteStorageFolder(`profile_pictures/${userId}/`);

    // ================================================================
    // 7. Delete user documents from Storage
    // ================================================================
    summary.userDocuments = await deleteStorageFolder(`user_documents/${userId}/`);

    // ================================================================
    // 8. Delete temp uploads from Storage
    // ================================================================
    summary.tempUploads = await deleteStorageFolder(`temp/${userId}/`);

    // ================================================================
    // 9. Delete presence from Realtime Database
    // ================================================================
    try {
      await admin.database().ref(`presence/${userId}`).remove();
      summary.presence = 1;
      logger.info("✅ RTDB presence deleted", {userId});
    } catch (e) {
      logger.warn("Failed to delete RTDB presence", {userId, error: String(e)});
      summary.presence = 0;
    }

    // ================================================================
    // 10. Anonymize admin audit logs (retain for audit trail)
    // ================================================================
    const auditLogs = await db
      .collection("admin_audit_logs")
      .where("targetUserId", "==", userId)
      .get();
    let auditLogsAnonymized = 0;
    for (const doc of auditLogs.docs) {
      await doc.ref.update({
        targetUserId: "deleted_user",
        targetUserName: "Deleted User",
      });
      auditLogsAnonymized++;
    }
    summary.auditLogsAnonymized = auditLogsAnonymized;

    // ================================================================
    // 11. Delete Firebase Auth account
    // ================================================================
    try {
      await admin.auth().deleteUser(userId);
      summary.authDeleted = 1;
      logger.info("✅ Firebase Auth user deleted", {userId});
    } catch (e) {
      // Auth deletion might fail if already deleted client-side
      logger.warn("Firebase Auth deletion failed (may already be deleted)", {
        userId,
        error: String(e),
      });
      summary.authDeleted = 0;
    }

    logger.info("✅ Account deletion completed", {userId, summary});

    // Mark request as completed
    await requestRef.update({
      status: "completed",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      summary,
    });
  } catch (error) {
    logger.error("❌ Account deletion failed", {
      userId,
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });

    // Mark request as failed so it can be retried or investigated
    try {
      await requestRef.update({
        status: "failed",
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error instanceof Error ? error.message : String(error),
      });
    } catch (updateErr) {
      logger.error("Failed to update deletion request status", {
        userId,
        error: String(updateErr),
      });
    }
  }
});
