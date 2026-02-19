/**
 * VoIP Push Notification Service for CallKit Integration
 *
 * This module sends VoIP push notifications to iOS devices to wake the app
 * for incoming calls, even when the app is killed or the phone is locked.
 *
 * This is an INTERNAL module - not exported as a Cloud Function.
 * It is called directly from createCall in callStateManagement.ts
 */

import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {sendVoIPNotification} from "./apnsClient";
import {db, getFCMTokens, cleanupInvalidFCMTokens} from "./utils";

/**
 * Request data for sending VoIP push
 */
export interface SendVoIPPushRequest {
  calleeId: string;
  callerId: string;
  callerName: string;
  callerAvatar?: string;
  callId: string;
  hasVideo: boolean;
  roomName?: string;
}

/**
 * Internal function to send VoIP push notification
 * Called from createCall after writing to incoming_calls
 *
 * @param data - Call data including callee, caller info, and call details
 * @return Success status and any error message
 */
export async function sendVoIPPushInternal(
  data: SendVoIPPushRequest
): Promise<{success: boolean; error?: string}> {
  logger.info("📞 Sending VoIP push notification", {
    calleeId: data.calleeId,
    callerId: data.callerId,
    callId: data.callId,
  });

  try {
    // Get callee's VoIP token from Firestore
    const calleeDoc = await db.collection("users").doc(data.calleeId).get();

    if (!calleeDoc.exists) {
      logger.warn(`User ${data.calleeId} not found`);
      return {success: false, error: "User not found"};
    }

    const calleeData = calleeDoc.data();
    const voipToken = calleeData?.voipToken;

    if (!voipToken) {
      logger.info(`No VoIP token for user ${data.calleeId}, trying FCM fallback`);
      // Fall back to regular FCM push if no VoIP token
      return await sendFallbackFCMPush(data);
    }

    // Prepare VoIP payload
    const payload = {
      callId: data.callId,
      callerId: data.callerId,
      callerName: data.callerName,
      callerAvatar: data.callerAvatar,
      hasVideo: data.hasVideo ?? false,
      roomName: data.roomName,
      timestamp: Date.now(),
    };

    // Send VoIP push notification via APNS
    const result = await sendVoIPNotification(voipToken, payload);

    if (result.success) {
      logger.info(`✅ VoIP push sent successfully to ${data.calleeId}`);
      return {success: true};
    } else {
      logger.error(`❌ VoIP push failed: ${result.error}`);

      // If token is invalid, remove it and try FCM fallback
      if (result.error?.includes("BadDeviceToken") ||
          result.error?.includes("Unregistered") ||
          result.statusCode === 410) {
        logger.info(`Removing invalid VoIP token for ${data.calleeId}`);
        await db.collection("users").doc(data.calleeId).update({
          voipToken: admin.firestore.FieldValue.delete(),
        });
        return await sendFallbackFCMPush(data);
      }

      return {success: false, error: result.error};
    }
  } catch (error) {
    logger.error("Error sending VoIP push:", error);
    return {success: false, error: String(error)};
  }
}

/**
 * Fallback to FCM push notification for Android or if VoIP fails
 */
async function sendFallbackFCMPush(data: SendVoIPPushRequest): Promise<{success: boolean; error?: string}> {
  try {
    // Get user's FCM tokens using shared utility
    const fcmTokens = await getFCMTokens(data.calleeId);

    if (fcmTokens.length === 0) {
      logger.warn(`No FCM tokens for user ${data.calleeId}`);
      return {success: false, error: "No FCM token available"};
    }

    // Build the FCM message
    const message: admin.messaging.MulticastMessage = {
      tokens: fcmTokens,
      data: {
        type: "incoming_call",
        callId: data.callId,
        callerId: data.callerId,
        callerName: data.callerName,
        callerAvatar: data.callerAvatar || "",
        hasVideo: String(data.hasVideo),
        roomName: data.roomName || "",
        timestamp: String(Date.now()),
        // Flutter-specific: helps flutter_callkit_incoming handle the notification
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        ttl: 60000, // 60 seconds
        notification: {
          channelId: "calls",
          priority: "max",
          sound: "default",
          title: "Incoming Call",
          body: `${data.callerName} is calling...`,
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-expiration": String(Math.floor(Date.now() / 1000) + 60),
        },
        payload: {
          aps: {
            "alert": {
              title: "Incoming Call",
              body: `${data.callerName} is calling...`,
            },
            "sound": "default",
            "badge": 1,
            "content-available": 1,
          },
        },
      },
    };

    // Send to all tokens
    const response = await admin.messaging().sendEachForMulticast(message);

    logger.info(`FCM fallback push sent to ${data.calleeId}`, {
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      await cleanupInvalidFCMTokens(data.calleeId, fcmTokens, response.responses);
    }

    if (response.successCount > 0) {
      return {success: true};
    } else {
      const errors = response.responses
        .filter((r) => !r.success)
        .map((r) => r.error?.message)
        .join(", ");
      return {success: false, error: `FCM failed: ${errors}`};
    }
  } catch (error) {
    logger.error("FCM fallback failed:", error);
    return {success: false, error: String(error)};
  }
}
