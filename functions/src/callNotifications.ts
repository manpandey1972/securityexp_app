import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {db, getFCMTokens} from "./utils";

const messaging = admin.messaging();

/**
 * Cloud Function: Send call notification when a new call is created
 * Triggered: When a document is created in call_history collection
 *
 * call_history document structure:
 * {
 *   caller_id: string (user ID of caller)
 *   caller_name: string (display name of caller)
 *   callee_id: string (user ID of callee)
 *   callee_name: string (display name of callee)
 *   is_video: boolean (whether it's a video call)
 *   status: string ('pending', 'answered', 'ended', 'rejected', 'missed')
 *   direction: string ('incoming' for receiver, 'outgoing' for caller)
 *   created_at: Timestamp
 *   room_id: string (WebRTC room identifier)
 *   caller_video_enabled: boolean
 *   callee_video_enabled: boolean
 *   durationSeconds: number
 * }
 */

interface CallData {
  caller_id: string;
  caller_name: string;
  callee_id: string;
  callee_name: string;
  is_video: boolean;
  status: string;
  direction: string;
  created_at: admin.firestore.Timestamp;
  room_id: string;
  caller_video_enabled?: boolean;
  callee_video_enabled?: boolean;
  durationSeconds?: number;
}

/**
 * Sends an incoming call notification to the callee
 * This function triggers when a new call document is created in call_history
 */
export const sendCallNotification = onDocumentCreated(
  {
    document: "call_history/{docId}",

  },
  async (event) => {
    try {
      const callData = event.data?.data() as CallData;
      const docId = event.params.docId;

      // Only send notification for new pending calls (not for historical entries)
      if (callData.status !== "pending") {
        console.log(`Skipping notification for non-pending call: ${docId} (status: ${callData.status})`);
        return;
      }

      // Get callee's FCM tokens
      const calleeTokens = await getFCMTokens(callData.callee_id);
      if (calleeTokens.length === 0) {
        console.log(`No FCM tokens found for callee: ${callData.callee_id}`);
        return;
      }

      // Prepare notification payload
      const callType = callData.is_video ? "Video" : "Audio";
      const title = `Incoming ${callType} Call`;
      const body = `${callData.caller_name} is calling...`;

      const payload: admin.messaging.MulticastMessage = {
        notification: {
          title,
          body,
        },
        data: {
          callType: callData.is_video ? "video" : "audio",
          callerId: callData.caller_id,
          callerName: callData.caller_name,
          roomId: callData.room_id,
          docId: docId,
          notificationType: "incomingCall",
          timestamp: callData.created_at?.toDate().toISOString() || new Date().toISOString(),
        },
        tokens: calleeTokens,
        // Apple-specific settings for iOS
        apns: {
          payload: {
            aps: {
              "alert": {
                title,
                body,
              },
              "sound": "default",
              "badge": 1,
              "content-available": 1, // Enable background notification handling
            },
          },
        },
        // Android-specific settings
        android: {
          priority: "high",
          notification: {
            title,
            body,
            sound: "default",
            channelId: "calls", // Custom notification channel for calls
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
      };

      // Send multicast message to all callee tokens
      const response = await messaging.sendEachForMulticast(payload);

      console.log(`Call notification sent to ${callData.callee_id}:`, {
        successCount: response.successCount,
        failureCount: response.failureCount,
        callerName: callData.caller_name,
        callType,
        roomId: callData.room_id,
      });

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        await cleanupInvalidTokens(callData.callee_id, response);
      }

      // Store notification log for analytics (optional)
      // await logNotificationEvent(docId, callData, response.successCount);
    } catch (error) {
      logger.error("Error sending call notification:", error);
      throw error; // Re-throw to allow Firebase to retry
    }
  }
);

// /**
//  * Sends notification when call is answered or missed
//  * Updates caller about call status
//  * COMMENTED OUT - Enable when status notifications are needed
//  */
// export const sendCallStatusNotification = onDocumentUpdated(
//   'call_history/{docId}',
//   async (event) => {
//     try {
//       const beforeData = event.data?.before.data() as CallData;
//       const afterData = event.data?.after.data() as CallData;
//       const docId = event.params.docId;
//
//       // Only process status changes
//       if (beforeData.status === afterData.status) {
//         return;
//       }
//
//       const statusChangeKey = `${beforeData.status} -> ${afterData.status}`;
//       console.log(`Call status changed: ${statusChangeKey} for call ${docId}`);
//
//       // Get caller's FCM tokens to notify about call status
//       const callerTokens = await getFCMTokens(afterData.caller_id);
//       if (callerTokens.length === 0) {
//         console.log(`No FCM tokens found for caller: ${afterData.caller_id}`);
//         return;
//       }
//
//       let title = '';
//       let body = '';
//       let shouldNotify = false;
//
//       // Determine notification based on status change
//       switch (afterData.status) {
//         case 'answered':
//           title = 'Call Connected';
//           body = `Call with ${afterData.callee_name} is now connected`;
//           shouldNotify = true;
//           break;
//
//         case 'rejected':
//           title = 'Call Rejected';
//           body = `${afterData.callee_name} declined your call`;
//           shouldNotify = true;
//           break;
//
//         case 'missed':
//           title = 'Call Missed';
//           body = `Missed call from ${afterData.caller_name}`;
//           shouldNotify = true;
//           break;
//
//         case 'ended':
//           // Optional: Send call ended notification with duration
//           const duration = afterData.durationSeconds || 0;
//           const durationStr = formatDuration(duration);
//           title = 'Call Ended';
//           body = `Call duration: ${durationStr}`;
//           shouldNotify = true;
//           break;
//
//         default:
//           console.log(`No notification needed for status: ${afterData.status}`);
//           return;
//       }
//
//       if (!shouldNotify) {
//         return;
//       }
//
//       const payload: admin.messaging.MulticastMessage = {
//         notification: {
//           title,
//           body,
//         },
//         data: {
//           callStatus: afterData.status,
//           callerId: afterData.caller_id,
//           calleeId: afterData.callee_id,
//           calleeName: afterData.callee_name,
//           roomId: afterData.room_id,
//           docId: docId,
//           notificationType: 'callStatus',
//           durationSeconds: (afterData.durationSeconds || 0).toString(),
//           timestamp: new Date().toISOString(),
//         },
//         tokens: callerTokens,
//         apns: {
//           payload: {
//             aps: {
//               alert: {
//                 title,
//                 body,
//               },
//               sound: 'default',
//               badge: 1,
//             },
//           },
//         },
//         android: {
//           priority: 'high',
//           notification: {
//             title,
//             body,
//             sound: 'default',
//             channelId: 'calls',
//           },
//         },
//       };
//
//       const response = await messaging.sendEachForMulticast(payload);
//
//       console.log(`Call status notification sent to ${afterData.caller_id}:`, {
//         successCount: response.successCount,
//         failureCount: response.failureCount,
//         status: afterData.status,
//         calleeName: afterData.callee_name,
//       });
//
//       // Clean up invalid tokens
//       if (response.failureCount > 0) {
//         await cleanupInvalidTokens(afterData.caller_id, response);
//       }
//
//     } catch (error) {
//       logger.error('Error sending call status notification:', error);
//       throw error;
//     }
//   }
// );


/**
 * Removes invalid/expired FCM tokens from Firestore
 * Called when sending fails for certain tokens
 */
async function cleanupInvalidTokens(
  userId: string,
  response: any
): Promise<void> {
  try {
    if (!response.responses || response.failureCount === 0) {
      return;
    }

    logger.info(`Cleaning up invalid tokens for user ${userId}`);

    // Get the list of invalid token indices from the response
    const invalidTokenIndices = response.responses
      .map((res: any, idx: number) => (res.success ? -1 : idx))
      .filter((idx: number) => idx !== -1);

    if (invalidTokenIndices.length === 0) {
      return;
    }

    // Get user's current fcms array
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data() as {fcms?: string[]};

    if (!userData?.fcms || !Array.isArray(userData.fcms)) {
      return;
    }

    // Remove invalid tokens by index (in reverse order to maintain indices)
    const updatedTokens = userData.fcms.filter((_, idx) => !invalidTokenIndices.includes(idx));

    // Update the user document with cleaned tokens
    await db.collection("users").doc(userId).update({
      fcms: updatedTokens,
      lastTokenCleanup: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Cleaned up ${invalidTokenIndices.length} invalid tokens for user ${userId}`);
  } catch (error) {
    logger.error(`Error cleaning up invalid tokens for user ${userId}:`, error);
    // Don't throw - this is a non-critical operation
  }
}


/**
 * Logs notification events for analytics and debugging
 * Optional but useful for monitoring
 */
/*
async function logNotificationEvent(
  docId: string,
  callData: CallData,
  successCount: number
): Promise<void> {
  try {
    await db.collection('notification_logs').add({
      callDocId: docId,
      callerId: callData.caller_id,
      callerName: callData.caller_name,
      calleeId: callData.callee_id,
      calleeName: callData.callee_name,
      callType: callData.is_video ? 'video' : 'audio',
      notificationType: 'incomingCall',
      successCount,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error('Error logging notification event:', error);
    // Don't throw - logging is non-critical
  }
}
*/
/**
  * Helper function to format call duration
  */
/*
 function formatDuration(seconds: number): string {
   if (seconds < 60) {
     return `${seconds}s`;
   }
   const minutes = Math.floor(seconds / 60);
   const remainingSeconds = seconds % 60;
   if (remainingSeconds === 0) {
     return `${minutes}m`;
   }
   return `${minutes}m ${remainingSeconds}s`;
 }
   */
