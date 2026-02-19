/**
 * Presence Helper for Push Notifications
 *
 * Cloud Functions only READ from Realtime Database - they never write presence data.
 * The Flutter app handles all presence updates.
 *
 * This helper checks user presence before sending push notifications to suppress
 * notifications when users are actively viewing a chat room.
 */

import * as admin from "firebase-admin";

interface PresenceData {
  isOnline: boolean;
  currentChatRoomId: string | null;
  lastUpdated: number;
}

/**
 * Checks if a push notification should be sent to a user.
 * Returns false if notifications are disabled, message is call_log, or user is viewing the chat room.
 *
 * Logic:
 * - Notifications disabled → Don't send
 * - Message is call_log → Don't send (skip FCM)
 * - No presence data → Send (user might be offline)
 * - Data is stale (>5 min) → Send (safety fallback)
 * - User offline → Send
 * - User viewing this chat → Don't send (suppress)
 * - User viewing different chat → Send
 *
 * @param recipientUserId - The user ID to check
 * @param chatRoomId - Optional chat room ID to check if user is viewing it
 * @param messageType - Optional message type (e.g., 'call_log')
 * @param notificationsEnabled - Whether notifications are enabled for this user (defaults to true)
 * @return true if notification should be sent, false to suppress
 */
export async function shouldSendPushNotification(
  recipientUserId: string,
  chatRoomId?: string,
  messageType?: string,
  notificationsEnabled = true
): Promise<boolean> {
  // Check if notifications are disabled
  if (!notificationsEnabled) {
    console.log(`Skipping FCM - notifications disabled for user ${recipientUserId}`);
    return false;
  }

  // Skip FCM notification for call_log messages
  if (messageType === "call_log") {
    console.log("Skipping FCM for call_log message");
    return false;
  }

  try {
    const presenceRef = admin.database().ref(`presence/${recipientUserId}`);
    const snapshot = await presenceRef.once("value");

    if (!snapshot.exists()) {
      return true; // No presence data = offline, send notification
    }

    const presence = snapshot.val() as PresenceData;


    // If user is offline, send notification
    if (!presence.isOnline) {
      return true;
    }

    // If user is viewing this specific chat room, suppress notification
    if (chatRoomId && presence.currentChatRoomId === chatRoomId) {
      console.log(`User ${recipientUserId} is viewing chat ${chatRoomId}, suppressing push`);
      return false;
    }

    // User is online but not in this chat room, send notification
    return true;
  } catch (error) {
    console.error(`Error checking presence for ${recipientUserId}:`, error);
    return true; // On error, default to sending
  }
}

/**
 * Gets the current presence data for a user from RTDB
 * Useful for debugging or admin purposes
 *
 * @param userId - The user ID to check presence for
 * @return PresenceData if found, null otherwise
 */
export async function getUserPresence(userId: string): Promise<PresenceData | null> {
  try {
    const presenceRef = admin.database().ref(`presence/${userId}`);
    const snapshot = await presenceRef.once("value");

    if (!snapshot.exists()) {
      return null;
    }

    return snapshot.val() as PresenceData;
  } catch (error) {
    console.error(`Error getting presence for ${userId}:`, error);
    return null;
  }
}

/**
 * Batch check presence for multiple users
 * Useful when sending notifications to multiple recipients
 *
 * @param userIds - Array of user IDs to check
 * @param chatRoomId - Optional chat room ID to check against
 * @return Map of userId to whether notification should be sent
 */
export async function batchCheckPresence(
  userIds: string[],
  chatRoomId?: string
): Promise<Map<string, boolean>> {
  const results = new Map<string, boolean>();

  // Check all users in parallel
  const checks = await Promise.all(
    userIds.map(async (userId) => {
      const shouldSend = await shouldSendPushNotification(userId, chatRoomId);
      return {userId, shouldSend};
    })
  );

  // Build result map
  for (const {userId, shouldSend} of checks) {
    results.set(userId, shouldSend);
  }

  return results;
}
