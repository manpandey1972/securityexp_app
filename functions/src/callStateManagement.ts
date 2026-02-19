import {HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {db} from "./utils";
import {Timestamp} from "firebase-admin/firestore";
import {randomUUID} from "crypto";
import {sendVoIPPushInternal} from "./voipPushService";
import {generateLiveKitToken} from "./livekit";

/**
 * Call State Management — Handler Functions
 *
 * Previously each function was a separate onCall Cloud Function.
 * Now exported as plain async handlers, called from the unified `api`
 * facade in index.ts (see CLOUD_FUNCTION_OPTIMIZATION.md, Optimization 3).
 *
 * Auth is pre-validated by the facade — handlers receive verified auth object.
 */

// Auth type matching what the facade passes through from request.auth
interface AuthData {
  uid: string;
  token?: Record<string, any>;
}

/**
 * Call State Management Cloud Functions
 *
 * These functions serve as the single source of truth for all call operations.
 * All state transitions are validated and executed on the backend to prevent
 * race conditions and unauthorized modifications.
 */

// Constants
const ACTIVE_CALLS_COLLECTION = "livekit_rooms";
const CALL_HISTORY_COLLECTION = "call_history";

// Types
type CallStatus = "pending" | "active" | "ended" | "rejected" | "cancelled" | "missed";

interface CreateCallRequest {
  callee_id: string;
  is_video: boolean;
  caller_name?: string;
  callee_name?: string;
}

interface CallStateUpdateRequest {
  room_id: string;
}

interface CallResponse {
  success: boolean;
  message: string;
  data?: Record<string, any>;
}

// Custom error classes for transaction error handling
class CallNotFoundError extends Error {
  constructor(message = "Call not found") {
    super(message);
    this.name = "CallNotFoundError";
  }
}

class CallAlreadyHandledError extends Error {
  constructor(message = "Call already handled") {
    super(message);
    this.name = "CallAlreadyHandledError";
  }
}

/**
 * Create a new call
 * Called by: Caller initiates a call via unified api facade
 * Auth: Pre-validated by facade
 */
export async function handleCreateCall(
  auth: AuthData,
  payload: Record<string, any>,
): Promise<CallResponse> {
    const callerId = auth.uid;

    // Debug: Log request data
    logger.info("🔍 createCall: Request data", {callerId, requestData: payload});

    const {callee_id: calleeId, is_video: isVideo, caller_name: callerName, callee_name: calleeName} = payload as unknown as CreateCallRequest;

    // Validation
    if (!calleeId || typeof isVideo !== "boolean") {
      logger.warn("❌ createCall: Invalid parameters", {callerId, calleeId, isVideo});
      throw new HttpsError("invalid-argument", "Missing or invalid parameters: callee_id and is_video required");
    }

    if (callerId === calleeId) {
      logger.warn("❌ createCall: Caller cannot call themselves", {callerId});
      throw new HttpsError("failed-precondition", "Cannot initiate a call with yourself");
    }

    // Validate ID format (basic check)
    if (!callerId.match(/^[a-zA-Z0-9_-]+$/) || !calleeId.match(/^[a-zA-Z0-9_-]+$/)) {
      logger.warn("❌ createCall: Invalid ID format", {callerId, calleeId});
      throw new HttpsError("invalid-argument", "Invalid user ID format");
    }

    // Validate caller name length
    if (callerName && callerName.length > 100) {
      logger.warn("❌ createCall: Caller name too long", {callerId});
      throw new HttpsError("invalid-argument", "Caller name must be 100 characters or less");
    }

    // Validate callee name length
    if (calleeName && calleeName.length > 100) {
      logger.warn("❌ createCall: Callee name too long", {callerId});
      throw new HttpsError("invalid-argument", "Callee name must be 100 characters or less");
    }

    try {
      // Verify callee exists
      const calleeSnap = await db.collection("users").doc(calleeId).get();
      if (!calleeSnap.exists) {
        logger.warn("❌ createCall: Callee not found", {callerId, calleeId});
        throw new HttpsError("not-found", "Callee does not exist");
      }

      // Generate unique room ID (opaque - doesn't leak user IDs)
      const roomId = `room_${randomUUID()}`;

      // Get caller info
      const callerSnap = await db.collection("users").doc(callerId).get();
      const callerData = callerSnap.data();
      const finalCallerName = callerName || callerData?.name || "Caller";

      // Get callee info for name
      const calleeData = calleeSnap.data();
      const finalCalleeName = calleeName || calleeData?.name || "Unknown";

      // Debug: Log callee name resolution
      logger.info("🔍 createCall: Callee name resolution", {
        callerId,
        calleeId,
        calleeName,
        calleeDataName: calleeData?.name,
        finalCalleeName,
      });

      // Create call document in livekit_rooms
      const callData = {
        room_id: roomId,
        caller_id: callerId,
        caller_name: finalCallerName,
        callee_id: calleeId,
        callee_name: finalCalleeName,
        participants: [callerId, calleeId],
        status: "pending" as CallStatus, // pending -> active -> ended/rejected/cancelled/missed
        is_video: isVideo,
        created_at: Timestamp.now(),
        expires_at: Timestamp.fromMillis(Date.now() + 15 * 60 * 1000), // 15 minutes
        media_enabled: {
          caller_video: isVideo,
          caller_audio: true,
          callee_video: true,
          callee_audio: true,
        },
        duration_seconds: 0,
      };

      await db.collection(ACTIVE_CALLS_COLLECTION).doc(roomId).set(callData);

      // Add to caller's active calls
      // await db.collection("users").doc(callerId).collection("active_calls").doc(roomId).set({
      //   room_id: roomId,
      //   peer_id: calleeId,
      //   is_video: isVideo,
      //   direction: "outgoing",
      //   status: "pending" as CallStatus,
      //   created_at: Timestamp.now(),
      // });

      // Add to callee's incoming_calls (so they can see incoming call)
      await db.collection("users").doc(calleeId).collection("incoming_calls").doc(roomId).set({
        room_id: roomId,
        caller_id: callerId,
        caller_name: finalCallerName,
        is_video: isVideo,
        direction: "incoming",
        status: "pending" as CallStatus,
        created_at: Timestamp.now(),
      });

      // Send VoIP push notification if callee has notifications enabled
      const notificationsEnabled = calleeData?.notifications_enabled !== false; // Default to true if not set
      if (notificationsEnabled) {
        logger.info("📱 Sending VoIP push to callee", {calleeId, roomId});
        try {
          const pushResult = await sendVoIPPushInternal({
            calleeId,
            callerId,
            callerName: finalCallerName,
            callId: roomId,
            hasVideo: isVideo,
            roomName: roomId,
          });
          if (!pushResult.success) {
            logger.warn("⚠️ VoIP push failed but call created", {error: pushResult.error});
          }
        } catch (pushError) {
          // Don't fail the call creation if push fails
          logger.error("❌ VoIP push error (non-fatal)", {error: pushError});
        }
      } else {
        logger.info("🔕 Skipping VoIP push - notifications disabled for callee", {calleeId});
      }

      // Generate LiveKit token for the caller
      const tokenResult = await generateLiveKitToken({
        userId: callerId,
        roomName: roomId,
        userName: finalCallerName,
      });

      logger.info("✅ Call created successfully", {
        callerId,
        calleeId,
        roomId,
        isVideo,
      });

      return {
        success: true,
        message: "Call created successfully",
        data: {
          room_id: roomId,
          expires_in_seconds: 15 * 60,
          livekit_token: tokenResult.token,
          livekit_url: tokenResult.url,
        },
      };
    } catch (error) {
      logger.error("❌ Error creating call:", {
        callerId,
        calleeId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
}

/**
 * Accept a call
 * Called by: Callee accepts an incoming call via unified api facade
 * Auth: Pre-validated by facade
 */
export async function handleAcceptCall(
  auth: AuthData,
  payload: Record<string, any>,
): Promise<CallResponse> {
    const userId = auth.uid;
    const {room_id: roomId} = payload as CallStateUpdateRequest;

    // Validation
    if (!roomId) {
      logger.warn("❌ acceptCall: Invalid parameters", {userId, roomId});
      throw new HttpsError("invalid-argument", "Missing parameter: room_id required");
    }

    try {
      // Use transaction as the single read point - avoids TOCTOU bugs
      const callRef = db.collection(ACTIVE_CALLS_COLLECTION).doc(roomId);
      const PENDING_STATUS: CallStatus = "pending";
      let callData: any = {};
      let callerId = "";
      let calleeId = "";

      try {
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(callRef);
          if (!snap.exists) throw new CallNotFoundError();

          callData = snap.data();
          callerId = callData?.caller_id;
          calleeId = callData?.callee_id;

          // Validate user is the callee
          if (userId !== calleeId) {
            throw new HttpsError("failed-precondition", "Only the callee can accept this call");
          }

          // Validate call is still pending
          if (callData?.status !== PENDING_STATUS) {
            throw new CallAlreadyHandledError();
          }

          tx.update(callRef, {
            status: "active" as CallStatus,
            answered_at: Timestamp.now(),
          });
        });
      } catch (e) {
        if (e instanceof CallNotFoundError) {
          logger.warn("❌ acceptCall: Call not found", {userId, roomId});
          throw new HttpsError("not-found", "Call does not exist");
        }
        if (e instanceof HttpsError) {
          logger.warn("❌ acceptCall: Authorization check failed", {userId, roomId});
          throw e;
        }
        if (e instanceof CallAlreadyHandledError) {
          logger.warn("❌ acceptCall: Call already handled", {userId, roomId});
          throw new HttpsError("failed-precondition", "Call already handled");
        }
        throw e;
      }

      // Move from incoming_calls to active_calls for callee
      await db.collection("users").doc(userId).collection("incoming_calls").doc(roomId).delete();
      /* await db.collection("users").doc(userId).collection("active_calls").doc(roomId).set({
        room_id: roomId,
        peer_id: callerId,
        direction: "incoming",
      }); */

      /* // Update caller's active_calls to reflect call is now active (use merge to avoid race conditions)
      await db.collection("users").doc(callerId).collection("active_calls").doc(roomId).set(
        {
          status: "active" as CallStatus,
          answered_at: Timestamp.now(),
        },
        { merge: true }
      ); */

      // Generate LiveKit token for the callee
      const calleeName = callData?.callee_name || "Callee";
      const tokenResult = await generateLiveKitToken({
        userId: userId,
        roomName: roomId,
        userName: calleeName,
      });

      logger.info("✅ Call accepted successfully", {
        userId,
        callerId,
        roomId,
      });

      return {
        success: true,
        message: "Call accepted",
        data: {
          room_id: roomId,
          livekit_token: tokenResult.token,
          livekit_url: tokenResult.url,
        },
      };
    } catch (error) {
      logger.error("❌ Error accepting call:", {
        userId,
        roomId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
}

/**
 * Reject a call
 * Called by: Callee rejects an incoming call via unified api facade
 * Auth: Pre-validated by facade
 */
export async function handleRejectCall(
  auth: AuthData,
  payload: Record<string, any>,
): Promise<CallResponse> {
    const userId = auth.uid;
    const {room_id: roomId} = payload as CallStateUpdateRequest;

    // Validation
    if (!roomId) {
      logger.warn("❌ rejectCall: Invalid parameters", {userId, roomId});
      throw new HttpsError("invalid-argument", "Missing parameter: room_id required");
    }

    try {
      // Use transaction as the single read point - avoids TOCTOU bugs
      const callRef = db.collection(ACTIVE_CALLS_COLLECTION).doc(roomId);
      const PENDING_STATUS: CallStatus = "pending";
      const rejectedAt = Timestamp.now();
      let callData: any = {};
      let callerId = "";
      let calleeId = "";

      try {
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(callRef);
          if (!snap.exists) throw new CallNotFoundError();

          callData = snap.data();
          callerId = callData?.caller_id;
          calleeId = callData?.callee_id;

          // Validate user is the callee
          if (userId !== calleeId) {
            throw new HttpsError("failed-precondition", "Only the callee can reject this call");
          }

          // Validate call is still pending
          if (callData?.status !== PENDING_STATUS) {
            throw new CallAlreadyHandledError();
          }

          // Extend expires_at by 15 minutes from now to keep document accessible
          const newExpiresAt = Timestamp.fromMillis(rejectedAt.toMillis() + 15 * 60 * 1000);

          tx.update(callRef, {
            status: "rejected" as CallStatus,
            rejected_at: rejectedAt,
            expires_at: newExpiresAt,
          });
        });
      } catch (e) {
        if (e instanceof CallNotFoundError) {
          logger.warn("❌ rejectCall: Call not found", {userId, roomId});
          throw new HttpsError("not-found", "Call does not exist");
        }
        if (e instanceof HttpsError) {
          logger.warn("❌ rejectCall: Authorization check failed", {userId, roomId});
          throw e;
        }
        if (e instanceof CallAlreadyHandledError) {
          logger.warn("❌ rejectCall: Call already handled", {userId, roomId});
          throw new HttpsError("failed-precondition", "Call already handled");
        }
        throw e;
      }

      // Remove from incoming_calls for callee
      await db.collection("users").doc(userId).collection("incoming_calls").doc(roomId).delete();

      // Remove from active_calls for caller
      // await db.collection("users").doc(callerId).collection("active_calls").doc(roomId).delete();

      // Archive to call history with final data
      await archiveCall({
        room_id: roomId,
        caller_id: callerId,
        caller_name: callData?.caller_name,
        callee_id: calleeId,
        callee_name: callData?.callee_name,
        status: "rejected" as CallStatus,
        is_video: callData?.is_video,
        created_at: callData?.created_at,
        answered_at: callData?.answered_at,
        ended_at: rejectedAt,
        duration_seconds: 0,
      });

      logger.info("✅ Call rejected successfully", {
        userId,
        roomId,
        callerId,
      });

      return {
        success: true,
        message: "Call rejected",
        data: {room_id: roomId},
      };
    } catch (error) {
      logger.error("❌ Error rejecting call:", {
        userId,
        roomId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
}

/**
 * End a call
 * Called by: Either participant ends an active call via unified api facade
 * Auth: Pre-validated by facade
 */
export async function handleEndCall(
  auth: AuthData,
  payload: Record<string, any>,
): Promise<CallResponse> {
    const userId = auth.uid;
    const {room_id: roomId} = payload as CallStateUpdateRequest;

    // Validation
    if (!roomId) {
      logger.warn("❌ endCall: Invalid parameters", {userId, roomId});
      throw new HttpsError("invalid-argument", "Missing parameter: room_id required");
    }

    try {
      // Use transaction as the single read point - avoids TOCTOU bugs
      const callRef = db.collection(ACTIVE_CALLS_COLLECTION).doc(roomId);
      const PENDING_STATUS: CallStatus = "pending";
      const ACTIVE_STATUS: CallStatus = "active";

      // Initialize variables - will be assigned inside transaction
      let callData: any = {};
      let callerId = "";
      let calleeId = "";
      let currentStatus: CallStatus = "pending";
      let finalStatus: CallStatus = "ended";
      let durationSeconds = 0;
      let createdAt: Timestamp | undefined;
      let answeredAt: Timestamp | undefined;
      const endedAt = Timestamp.now();

      try {
        await db.runTransaction(async (transaction) => {
          const snap = await transaction.get(callRef);
          if (!snap.exists) {
            throw new CallNotFoundError();
          }

          callData = snap.data();
          callerId = callData?.caller_id;
          calleeId = callData?.callee_id;
          currentStatus = callData?.status;
          createdAt = callData?.created_at as Timestamp;
          answeredAt = callData?.answered_at as Timestamp | undefined;

          // Validate user is a participant
          if (userId !== callerId && userId !== calleeId) {
            throw new HttpsError("failed-precondition", "You are not a participant in this call");
          }

          // Determine final status
          if (currentStatus === PENDING_STATUS) {
            finalStatus = userId === callerId ? ("cancelled" as CallStatus) : ("rejected" as CallStatus);
          } else if (currentStatus === ACTIVE_STATUS) {
            finalStatus = "ended";
          } else {
            // Call already in terminal state - return early without updating
            finalStatus = currentStatus;
            throw new Error("CALL_ALREADY_ENDED");
          }

          // Calculate duration only for ACTIVE calls
          if (currentStatus === ACTIVE_STATUS) {
            const startTime = answeredAt ?? createdAt;
            durationSeconds = Math.floor((endedAt.toDate().getTime() - startTime.toDate().getTime()) / 1000);
          } else {
            durationSeconds = 0;
          }

          // Extend expires_at by 15 minutes from now to keep document accessible
          const newExpiresAt = Timestamp.fromMillis(endedAt.toMillis() + 15 * 60 * 1000);

          transaction.update(callRef, {
            status: finalStatus,
            ended_at: endedAt,
            duration_seconds: durationSeconds,
            expires_at: newExpiresAt,
          });
        });
      } catch (e) {
        if (e instanceof CallNotFoundError) {
          logger.warn("❌ endCall: Call not found", {userId, roomId});
          throw new HttpsError("not-found", "Call does not exist");
        }
        if (e instanceof HttpsError) {
          logger.warn("❌ endCall: Validation failed", {userId, roomId});
          throw e;
        }
        if (e instanceof Error && e.message === "CALL_ALREADY_ENDED") {
          logger.warn("⚠️ endCall: Call already in terminal state", {userId, roomId, currentStatus});
          return {
            success: false,
            message: `Call is already ${currentStatus}`,
          };
        }
        throw e;
      }

      // Remove from active_calls for both participants
      // await db.collection("users").doc(callerId).collection("active_calls").doc(roomId).delete();
      // await db.collection("users").doc(calleeId).collection("active_calls").doc(roomId).delete();

      // Remove from incoming_calls for callee (if still there)
      await db.collection("users").doc(calleeId).collection("incoming_calls").doc(roomId).delete();

      // Archive to call history with final data
      // Note: currentStatus is either "pending" or "active" here (terminal states handled above)
      const finalDurationSeconds = (currentStatus as CallStatus) === "active" ? durationSeconds : 0;
      await archiveCall({
        room_id: roomId,
        caller_id: callerId,
        caller_name: callData?.caller_name,
        callee_id: calleeId,
        callee_name: callData?.callee_name,
        status: finalStatus,
        is_video: callData?.is_video,
        created_at: createdAt,
        answered_at: answeredAt,
        ended_at: endedAt,
        duration_seconds: finalDurationSeconds,
      });

      logger.info("✅ Call ended successfully", {
        userId,
        roomId,
        finalStatus,
        durationSeconds: finalDurationSeconds,
      });

      return {
        success: true,
        message: "Call ended",
        data: {
          room_id: roomId,
          status: finalStatus,
          duration_seconds: durationSeconds,
        },
      };
    } catch (error) {
      logger.error("❌ Error ending call:", {
        userId,
        roomId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
}

/**
 * Helper function to generate chat room ID from two user IDs
 * Uses sorted IDs to ensure consistency regardless of who initiates
 */
function generateChatRoomId(userId1: string, userId2: string): string {
  const sortedIds = [userId1, userId2].sort();
  return `${sortedIds[0]}_${sortedIds[1]}`;
}

/**
 * Helper function to update room's last message if the new timestamp is greater
 */
async function updateRoomLastMessage(
  chatRoomId: string,
  messageData: {
    type: string;
    sender_id: string;
    text: string;
    timestamp: Timestamp;
  }
): Promise<void> {
  try {
    const roomRef = db.collection("chat_rooms").doc(chatRoomId);

    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);

      if (!roomSnap.exists) {
        logger.warn("⚠️ Room does not exist, skipping last message update", {chatRoomId});
        return;
      }

      const roomData = roomSnap.data();
      const existingLastMessageTimestamp = roomData?.last_message?.timestamp;

      // Update if no last message exists or if new message is newer
      if (!existingLastMessageTimestamp ||
          messageData.timestamp.toMillis() > existingLastMessageTimestamp.toMillis()) {
        tx.update(roomRef, {
          last_message: {
            type: messageData.type,
            sender_id: messageData.sender_id,
            text: messageData.text,
            timestamp: messageData.timestamp,
          },
          lastMessage: messageData.text,
          lastMessageTime: messageData.timestamp,
          updated_at: messageData.timestamp,
        });
        logger.info("✅ Room last message updated", {chatRoomId});
      } else {
        logger.info("ℹ️ Skipping last message update - existing message is newer", {chatRoomId});
      }
    });
  } catch (error) {
    logger.error("❌ Error updating room last message:", {
      chatRoomId,
      error: error instanceof Error ? error.message : String(error),
    });
    // Don't rethrow - last message update failure shouldn't fail the main operation
  }
}

/**
 * Helper function to create a call log message in the chat room
 */
async function createCallLogMessage(params: {
  caller_id: string;
  callee_id: string;
  status: CallStatus;
  is_video: boolean;
  duration_seconds: number;
  initiator_id: string;
  created_at: Timestamp;
}): Promise<void> {
  try {
    const {caller_id, callee_id, status, is_video, duration_seconds, initiator_id, created_at} = params;

    // Generate chat room ID from caller and callee IDs
    const chatRoomId = generateChatRoomId(caller_id, callee_id);

    // Check if room exists before adding message
    const roomRef = db.collection("chat_rooms").doc(chatRoomId);
    const roomSnap = await roomRef.get();

    if (!roomSnap.exists) {
      logger.warn("⚠️ Room does not exist, skipping call log message", {chatRoomId});
      return;
    }

    // Determine call log text based on status
    let callLogText = "Call ended";
    if (status === "missed") {
      callLogText = "Missed call";
    } else if (status === "rejected") {
      callLogText = "Call declined";
    } else if (status === "cancelled") {
      callLogText = "Call cancelled";
    } else if (status === "ended") {
      callLogText = "Call ended";
    }

    // Create the call log message using created_at timestamp
    const messageData = {
      type: "call_log",
      sender_id: initiator_id,
      text: callLogText,
      timestamp: created_at,
      metadata: {
        status,
        isVideo: is_video,
        duration: duration_seconds,
        initiatorId: initiator_id,
      },
    };

    // Store in the chat room's messages collection
    await db.collection("chat_rooms")
      .doc(chatRoomId)
      .collection("messages")
      .add(messageData);

    logger.info("✅ Call log message created", {chatRoomId, status, initiator_id});

    // Update room's last message if this is the newest message
    await updateRoomLastMessage(chatRoomId, {
      type: messageData.type,
      sender_id: messageData.sender_id,
      text: messageData.text,
      timestamp: messageData.timestamp,
    });
  } catch (error) {
    logger.error("❌ Error creating call log message:", {
      caller_id: params.caller_id,
      callee_id: params.callee_id,
      error: error instanceof Error ? error.message : String(error),
    });
    // Don't rethrow - call log failure shouldn't fail the main operation
  }
}

/**
 * Helper function to archive call to call history
 * Takes final call data snapshot to avoid race conditions from re-reading
 */
async function archiveCall(callData: any): Promise<void> {
  try {
    const roomId = callData.room_id;
    const callerId = callData.caller_id;
    const calleeId = callData.callee_id;

    if (!roomId || !callerId || !calleeId) {
      logger.error("❌ archiveCall: Missing required fields", {roomId, callerId, calleeId});
      return;
    }

    // Create call history entry for both participants
    const historyData = {
      room_id: roomId,
      caller_id: callerId,
      caller_name: callData.caller_name,
      callee_id: calleeId,
      callee_name: callData.callee_name || "Unknown",
      status: callData.status,
      is_video: callData.is_video,
      created_at: callData.created_at,
      answered_at: callData.answered_at || null,
      ended_at: callData.ended_at || Timestamp.now(),
      duration_seconds: callData.duration_seconds || 0,
    };

    // Use batch to ensure atomicity
    const batch = db.batch();

    // Add to caller's call history
    batch.set(
      db.collection("users").doc(callerId).collection(CALL_HISTORY_COLLECTION).doc(roomId),
      {
        ...historyData,
        direction: "outgoing",
      }
    );

    // Add to callee's call history
    batch.set(
      db.collection("users").doc(calleeId).collection(CALL_HISTORY_COLLECTION).doc(roomId),
      {
        ...historyData,
        direction: "incoming",
      }
    );

    await batch.commit();
    logger.info("✅ Call archived to history", {roomId, status: callData.status});

    // Create call log message in chat room
    await createCallLogMessage({
      caller_id: callerId,
      callee_id: calleeId,
      status: callData.status,
      is_video: callData.is_video,
      duration_seconds: callData.duration_seconds || 0,
      initiator_id: callerId,
      created_at: callData.created_at,
    });
  } catch (error) {
    const roomId = callData?.room_id;
    logger.error("❌ Error archiving call:", {roomId, error});
    // Don't rethrow - archiving failure shouldn't fail the end call operation
  }
}

/**
 * Scheduled function to handle call timeouts
 * Runs every minute to clean up pending calls that exceed the timeout threshold
 * This is a backend maintenance job - not callable by clients
 */
export const handleCallTimeouts = onSchedule("every 1 minutes", async () => {
  try {
    logger.info("⏰ Starting call timeout handler");

    const now = Timestamp.now();

    // Query for pending calls that have expired (use expires_at to avoid clock drift)
    const PENDING_STATUS: CallStatus = "pending";
    const pendingCalls = await db.collection(ACTIVE_CALLS_COLLECTION)
      .where("status", "==", PENDING_STATUS)
      .where("expires_at", "<", now)
      .limit(100)
      .get();

    let timedOutCount = 0;

    for (const callDoc of pendingCalls.docs) {
      const callData = callDoc.data();
      const roomId = callData.room_id;
      const callerId = callData.caller_id;
      const calleeId = callData.callee_id;

      try {
        // Use transaction to ensure status is still pending before marking as missed
        const callRef = db.collection(ACTIVE_CALLS_COLLECTION).doc(roomId);
        const PENDING_STATUS: CallStatus = "pending";
        const MISSED_STATUS: CallStatus = "missed";
        const timeoutAt = Timestamp.now();

        await db.runTransaction(async (tx) => {
          const snap = await tx.get(callRef);
          if (!snap.exists) return; // Call already deleted

          if (snap.data()?.status !== PENDING_STATUS) {
            return; // Call no longer pending (accepted or rejected)
          }

          // Extend expires_at by 15 minutes from now to keep document accessible
          const newExpiresAt = Timestamp.fromMillis(timeoutAt.toMillis() + 15 * 60 * 1000);

          tx.update(callRef, {
            status: MISSED_STATUS,
            timeout_at: timeoutAt,
            expires_at: newExpiresAt,
          });
        });

        // Remove from incoming_calls for callee
        await db.collection("users").doc(calleeId).collection("incoming_calls").doc(roomId).delete();

        // Remove from active_calls for caller
        // await db.collection("users").doc(callerId).collection("active_calls").doc(roomId).delete();

        // Archive to call history with final data
        await archiveCall({
          room_id: roomId,
          caller_id: callerId,
          caller_name: callData.caller_name,
          callee_id: calleeId,
          callee_name: callData.callee_name,
          status: MISSED_STATUS,
          is_video: callData.is_video,
          created_at: callData.created_at,
          answered_at: null,
          ended_at: timeoutAt,
          duration_seconds: 0,
        });

        timedOutCount++;
        logger.info("✅ Call timed out", {roomId, callerId, calleeId});
      } catch (error) {
        logger.error("❌ Error timing out call:", {roomId, error});
      }
    }

    logger.info("✅ Call timeout handler completed", {timedOutCount});
  } catch (error) {
    logger.error("❌ Error in call timeout handler:", {error});
    throw error;
  }
});

export default {
  handleCreateCall,
  handleAcceptCall,
  handleRejectCall,
  handleEndCall,
  handleCallTimeouts,
};
