/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {db, getUserData, sendFCMToUser} from "./utils";
import {sendCallNotification} from "./callNotifications";
import {shouldSendPushNotification} from "./presence/checkPresenceBeforePush";

// APNS secrets — declared at top level so the unified `api` function has access
const apnsKeyId = defineSecret("APNS_KEY_ID");
const apnsTeamId = defineSecret("APNS_TEAM_ID");
const apnsPrivateKey = defineSecret("APNS_PRIVATE_KEY");
const apnsBundleId = defineSecret("APNS_BUNDLE_ID");

// Re-export call notifications functions
export {sendCallNotification};
// Re-export presence utilities
export {
  shouldSendPushNotification,
  getUserPresence,
  batchCheckPresence,
} from "./presence/checkPresenceBeforePush";
// Re-export rating functions
export {onRatingCreated} from "./ratings";
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// ============================================================================
// Chat Message Notification
// ============================================================================

interface ChatMessageData {
  sender_id?: string;
  senderName?: string;
  text?: string;
  type?: string;
}

/**
 * Derives the recipient ID from a chat room ID
 * Room IDs are in format: userA_userB
 */
function deriveRecipientFromRoomId(roomId: string, senderId?: string): string | null {
  const [partA, partB] = roomId.split("_").filter(Boolean);

  if (!partA || !partB) {
    return null;
  }

  if (senderId === partA) {
    return partB;
  } else if (senderId === partB) {
    return partA;
  }

  // Default to second segment when sender is missing or mismatched
  return partB;
}

/**
 * Cloud Function: Merged handler for new chat messages
 * Combines notification sending + unread count update into a single trigger
 * to halve cold starts per message (see CLOUD_FUNCTION_OPTIMIZATION.md, Optimization 2).
 *
 * Previously: chatMessageCreated + updateUnreadCount (2 separate triggers on same path)
 * Now: onMessageCreated (single trigger, both tasks run in parallel via Promise.allSettled)
 */
export const onMessageCreated = onDocumentCreated(
  {
    document: "chat_rooms/{room_id}/messages/{messageid}",
  },
  async (event) => {
    const {room_id: roomId, messageid: messageId} = event.params;
    logger.info("🔔 onMessageCreated trigger invoked", {roomId, messageId});

    const messageData = event.data?.data() as ChatMessageData | undefined;
    if (!messageData) {
      logger.warn("❌ No message data found", {roomId, messageId});
      return;
    }

    // Run notification + unread count update in parallel
    // Use allSettled so one failing doesn't block the other
    const [notifResult, unreadResult] = await Promise.allSettled([
      handleNotification(roomId, messageId, messageData),
      handleUnreadCountUpdate(roomId, messageId, messageData),
    ]);

    if (notifResult.status === "rejected") {
      logger.error("❌ Notification handler failed", {
        roomId,
        messageId,
        error: notifResult.reason instanceof Error ? notifResult.reason.message : String(notifResult.reason),
      });
    }

    if (unreadResult.status === "rejected") {
      logger.error("❌ Unread count handler failed", {
        roomId,
        messageId,
        error: unreadResult.reason instanceof Error ? unreadResult.reason.message : String(unreadResult.reason),
      });
    }
  },
);

/**
 * Notification handler — extracted from former chatMessageCreated
 */
async function handleNotification(
  roomId: string,
  messageId: string,
  messageData: ChatMessageData,
): Promise<void> {
  const senderId = messageData.sender_id;
  const recipientId = deriveRecipientFromRoomId(roomId, senderId);

  if (!recipientId) {
    logger.warn("❌ Unable to derive recipientId from roomId", {roomId, messageId});
    return;
  }

  logger.debug("Message routing", {senderId, recipientId, roomId});

  // Fetch sender and recipient data in parallel
  const [senderData, recipientData] = await Promise.all([
    senderId ? getUserData(senderId) : null,
    getUserData(recipientId),
  ]);

  if (!recipientData) {
    logger.warn("❌ Recipient user document not found", {recipientId});
    return;
  }

  // Check if recipient is currently viewing this chat room (presence check)
  const shouldSend = await shouldSendPushNotification(
    recipientId,
    roomId,
    messageData.type,
    recipientData?.notifications_enabled !== false
  );
  if (!shouldSend) {
    logger.info("⏭️ Skipping FCM - notification filtered by shouldSendPushNotification", {
      recipientId,
      roomId,
      messageId,
    });
    return;
  }

  const senderName = senderData?.name ?? "Unknown sender";
  const messageText = messageData.text ?? "You have a new message";

  // Send FCM notification with automatic token cleanup
  const result = await sendFCMToUser(
    recipientId,
    {
      title: senderName,
      body: messageText,
    },
    {
      roomId,
      messageId,
      type: "chat_message",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    }
  );

  logger.info("✅ FCM send completed", {
    roomId,
    recipientId,
    successCount: result.successCount,
    failureCount: result.failureCount,
    tokenCount: result.tokens.length,
  });
}

/**
 * Unread count handler — extracted from former updateUnreadCount
 */
async function handleUnreadCountUpdate(
  roomId: string,
  messageId: string,
  messageData: ChatMessageData,
): Promise<void> {
  const senderId = messageData.sender_id;
  const messageCreateAt = (messageData as any).timestamp || admin.firestore.Timestamp.now();
  const participants = roomId.split("_").filter(Boolean);
  logger.debug("Updating unread counts", {roomId, participants, senderId});

  const batch = db.batch();

  for (const userId of participants) {
    const userRoomRef = db.collection("users").doc(userId).collection("rooms").doc(roomId);
    if (userId === senderId) {
      // Sender has no unread
      batch.set(
        userRoomRef,
        {
          unreadCount: 0,
          lastReadAt: messageCreateAt,
          lastMessageAt: messageCreateAt,
        },
        {merge: true}
      );
    } else {
      // Increment unread for others
      batch.set(
        userRoomRef,
        {
          unreadCount: admin.firestore.FieldValue.increment(1),
          lastMessageAt: messageCreateAt,
        },
        {merge: true}
      );

      // Maintain totalUnreadCount on user doc
      const userRef = db.collection("users").doc(userId);
      batch.set(
        userRef,
        {
          totalUnreadCount: admin.firestore.FieldValue.increment(1),
        },
        {merge: true}
      );
    }
  }

  await batch.commit();
  logger.info("✅ Unread counts updated", {roomId, messageId});
}


// ============================================================================
// Unified Callable Facade (Optimization 3 + 4)
// ============================================================================
// All callable functions consolidated into a single `api` endpoint to minimize
// cold starts. See CLOUD_FUNCTION_OPTIMIZATION.md.
//
// markRoomRead removed entirely — now handled client-side (Optimization 1).
// generateLiveKitTokenFunction removed — tokens returned from createCall/acceptCall (Optimization 4).
//
// Previously: createCall, acceptCall, rejectCall, endCall, generateLiveKitTokenFunction, markRoomRead
// Now: single `api` function routing by action field
// ============================================================================

import {
  handleCreateCall,
  handleAcceptCall,
  handleRejectCall,
  handleEndCall,
  handleCallTimeouts,
} from "./callStateManagement";
// Account deletion now uses Firestore-triggered background function
export {onAccountDeletionRequested} from "./accountDeletion";

export {handleCallTimeouts};

/**
 * Unified API callable — single entry point for all client-callable operations.
 * Routes to handlers based on `action` field in request payload.
 *
 * Request format: { action: string, payload: Record<string, any> }
 * Response format: handler-specific (typically { success: boolean, message: string, data?: any })
 */
export const api = onCall(
  {
    enforceAppCheck: false,
    cors: true,
    // Secrets required for createCall (VoIP push via APNS)
    secrets: [apnsKeyId, apnsTeamId, apnsPrivateKey, apnsBundleId],
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      logger.warn("❌ api: Unauthorized access attempt");
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const {action, payload} = request.data as {action: string; payload: Record<string, any>};

    if (!action) {
      throw new HttpsError("invalid-argument", "Missing required field: action");
    }

    logger.info(`[${action}] Request received`, {
      userId: request.auth.uid,
      action,
    });

    switch (action) {
    case "createCall":
      return handleCreateCall(request.auth, payload);
    case "acceptCall":
      return handleAcceptCall(request.auth, payload);
    case "rejectCall":
      return handleRejectCall(request.auth, payload);
    case "endCall":
      return handleEndCall(request.auth, payload);
    default:
      throw new HttpsError("invalid-argument", `Unknown action: ${action}`);
    }
  }
);

// Import and re-export support ticket functions
import {
  onTicketCreate,
  onSupportMessageCreate,
  onTicketUpdate,
  autoCloseResolvedTickets,
} from "./support";

// Re-export support functions
export {onTicketCreate, onSupportMessageCreate, onTicketUpdate, autoCloseResolvedTickets};
