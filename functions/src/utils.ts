import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";

// Initialize Firebase Admin SDK first
if (!admin.apps.length) {
  admin.initializeApp();
}

// Initialize Firestore instance lazily
// Uses default Firestore database
let _db: admin.firestore.Firestore | null = null;

export function getDb(): admin.firestore.Firestore {
  if (!_db) {
    _db = admin.firestore();
  }
  return _db;
}

// For backward compatibility, also export as db
export const db = new Proxy({} as admin.firestore.Firestore, {
  get: (_, prop) => {
    const database = getDb();
    return (database as any)[prop];
  },
});

/**
 * Retrieves user data for a specific user
 */
export async function getUserData(userId: string): Promise<{name?: string; [key: string]: any} | null> {
  try {
    const userSnap = await db.collection("users").doc(userId).get();
    if (!userSnap.exists) {
      logger.warn("getUserData: User document not found", {userId});
      return null;
    }
    const userData = userSnap.data();
    logger.debug("getUserData: User data retrieved", {userId, hasData: !!userData});
    return userData || null;
  } catch (error) {
    logger.error(`getUserData: Error getting user data for ${userId}:`, error);
    return null;
  }
}

/**
 * Retrieves all FCM tokens for a specific user
 * Looks in users/{userId} document for fcms array
 */
export async function getFCMTokens(userId: string): Promise<string[]> {
  try {
    const userData = await getUserData(userId);

    if (!userData) {
      logger.warn("getFCMTokens: User document not found", {userId});
      return [];
    }

    if (userData?.fcms && Array.isArray(userData.fcms)) {
      const tokens = (userData.fcms as string[]).filter(Boolean);
      logger.debug("getFCMTokens: Found tokens in users doc", {userId, tokenCount: tokens.length});
      return tokens;
    }

    logger.warn("getFCMTokens: No fcmTokens array found in user document", {userId});
    return [];
  } catch (error) {
    logger.error(`getFCMTokens: Error getting FCM tokens for user ${userId}:`, error);
    return [];
  }
}

// FCM error codes that indicate token is invalid and should be removed
const INVALID_TOKEN_ERROR_CODES = [
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
  "messaging/invalid-argument", // Sometimes indicates bad token
];

/**
 * Removes invalid/expired FCM tokens from Firestore
 * Should be called after sending FCM messages to clean up stale tokens
 *
 * @param userId - The user ID whose tokens to clean
 * @param tokens - The original tokens array that was used for sending
 * @param responses - The responses from sendEachForMulticast
 */
export async function cleanupInvalidFCMTokens(
  userId: string,
  tokens: string[],
  responses: Array<{success: boolean; error?: {code?: string; message?: string}}>
): Promise<number> {
  try {
    // Find tokens that failed with invalid token errors
    const invalidTokens: string[] = [];

    responses.forEach((res, idx) => {
      if (!res.success && res.error?.code) {
        const errorCode = res.error.code;
        if (INVALID_TOKEN_ERROR_CODES.includes(errorCode)) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length === 0) {
      return 0;
    }

    logger.info("🧹 Cleaning up invalid FCM tokens", {
      userId,
      invalidCount: invalidTokens.length,
    });

    // Use arrayRemove to atomically remove the invalid tokens
    // This is safer than read-modify-write as it handles concurrent modifications
    await db.collection("users").doc(userId).update({
      fcms: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    });

    logger.info("✅ Removed invalid FCM tokens", {
      userId,
      removedCount: invalidTokens.length,
      removedTokens: invalidTokens.map((t) => t.substring(0, 20) + "..."),
    });

    return invalidTokens.length;
  } catch (error) {
    logger.error("❌ Error cleaning up invalid tokens:", {userId, error});
    return 0;
  }
}

/**
 * Send FCM notification to a user with automatic token cleanup
 *
 * @param userId - The recipient user ID
 * @param notification - The notification title and body
 * @param data - Additional data payload
 * @return Object with success count and failure count
 */
export async function sendFCMToUser(
  userId: string,
  notification: {title: string; body: string},
  data?: Record<string, string>
): Promise<{successCount: number; failureCount: number; tokens: string[]}> {
  const tokens = await getFCMTokens(userId);

  if (tokens.length === 0) {
    logger.warn("sendFCMToUser: No FCM tokens for user", {userId});
    return {successCount: 0, failureCount: 0, tokens: []};
  }

  try {
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification,
      data,
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      await cleanupInvalidFCMTokens(userId, tokens, response.responses);
    }

    return {
      successCount: response.successCount,
      failureCount: response.failureCount,
      tokens,
    };
  } catch (error) {
    logger.error("sendFCMToUser: Error sending FCM", {userId, error});
    return {successCount: 0, failureCount: tokens.length, tokens};
  }
}

