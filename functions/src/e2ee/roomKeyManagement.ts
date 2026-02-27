/**
 * Room Key Management — E2EE v3 (KMS-protected per-room symmetric keys).
 *
 * Two Cloud Function handlers:
 *   - sealRoomKey:  Generate, KMS-encrypt, store, and return a room key
 *   - getRoomKey:   Verify participant, KMS-decrypt, and return a room key
 *
 * KMS key: projects/securityexp-app/locations/global/keyRings/e2ee-chat
 *          /cryptoKeys/room-key-encryption-key
 */

import * as crypto from "crypto";
import {KeyManagementServiceClient} from "@google-cloud/kms";
import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions/v2";
import {HttpsError} from "firebase-functions/v2/https";

// Auth type matching what the facade passes through from request.auth
interface AuthData {
  uid: string;
  token?: Record<string, any>;
}

const kms = new KeyManagementServiceClient();
const db = getFirestore();

const KMS_KEY_NAME =
  "projects/securityexp-app/locations/global/keyRings/e2ee-chat" +
  "/cryptoKeys/room-key-encryption-key";

// ============================================================================
// sealRoomKey
// ============================================================================

/**
 * Generate, KMS-encrypt, and store a room key.
 * Returns the plaintext key (Base64) to the caller (room creator).
 *
 * Idempotent: if the room already has a key, decrypts and returns it.
 *
 * Preconditions:
 * - Caller is authenticated
 * - Caller is a participant of the room
 */
export async function handleSealRoomKey(
  auth: AuthData,
  payload: Record<string, unknown>
): Promise<{success: boolean; roomKey: string}> {
  const uid = auth.uid;
  const {roomId} = payload as {roomId?: string};

  if (!roomId || typeof roomId !== "string") {
    throw new HttpsError("invalid-argument", "roomId is required");
  }

  const roomRef = db.collection("chat_rooms").doc(roomId);

  // Use a transaction to prevent two concurrent sealRoomKey calls from
  // each creating a different key (check-then-write race condition).
  return db.runTransaction(async (txn) => {
    const roomDoc = await txn.get(roomRef);

    if (!roomDoc.exists) {
      throw new HttpsError("not-found", "Room not found");
    }

    const participants = roomDoc.data()?.participants as string[] | undefined;
    if (!participants?.includes(uid)) {
      throw new HttpsError("permission-denied", "Not a room participant");
    }

    // Idempotency — if key already exists, decrypt and return it
    const existingCiphertext = roomDoc.data()?.encrypted_room_key as string | undefined;
    if (existingCiphertext) {
      logger.info("Room already has a key — returning existing", {roomId, uid});
      return decryptAndReturn(existingCiphertext);
    }

    // Generate random 32-byte room key
    const roomKey = crypto.randomBytes(32);

    // KMS encrypt
    const [encResult] = await kms.encrypt({
      name: KMS_KEY_NAME,
      plaintext: roomKey,
    });

    if (!encResult.ciphertext) {
      throw new HttpsError("internal", "KMS encryption failed");
    }

    const ciphertextB64 = Buffer.from(encResult.ciphertext).toString("base64");

    // Store within the transaction (atomically safe)
    txn.update(roomRef, {
      encrypted_room_key: ciphertextB64,
      e2ee_enabled: true,
    });

    logger.info("Room key sealed", {roomId, uid});

    // Return plaintext key to caller
    return {
      success: true,
      roomKey: roomKey.toString("base64"),
    };
  });
}

// ============================================================================
// getRoomKey
// ============================================================================

/**
 * Retrieve and decrypt the room key for an authenticated participant.
 *
 * Preconditions:
 * - Caller is authenticated
 * - Caller is a participant of the room
 * - Room has an encrypted_room_key
 */
export async function handleGetRoomKey(
  auth: AuthData,
  payload: Record<string, unknown>
): Promise<{success: boolean; roomKey: string}> {
  const uid = auth.uid;
  const {roomId} = payload as {roomId?: string};

  if (!roomId || typeof roomId !== "string") {
    throw new HttpsError("invalid-argument", "roomId is required");
  }

  // 1. Verify caller is a room participant
  const roomRef = db.collection("chat_rooms").doc(roomId);
  const roomDoc = await roomRef.get();

  if (!roomDoc.exists) {
    throw new HttpsError("not-found", "Room not found");
  }

  const participants = roomDoc.data()?.participants as string[] | undefined;
  if (!participants?.includes(uid)) {
    throw new HttpsError("permission-denied", "Not a room participant");
  }

  // 2. Get KMS ciphertext
  const ciphertextB64 = roomDoc.data()?.encrypted_room_key as string | undefined;
  if (!ciphertextB64) {
    throw new HttpsError("not-found", "Room key not yet created");
  }

  logger.info(`Room key retrieved for room`, {roomId, uid});

  // 3. KMS decrypt and return
  return decryptAndReturn(ciphertextB64);
}

// ============================================================================
// Shared helper
// ============================================================================

async function decryptAndReturn(
  ciphertextB64: string
): Promise<{success: boolean; roomKey: string}> {
  const ciphertext = Buffer.from(ciphertextB64, "base64");

  const [decResult] = await kms.decrypt({
    name: KMS_KEY_NAME,
    ciphertext: ciphertext,
  });

  if (!decResult.plaintext) {
    throw new HttpsError("internal", "KMS decryption failed");
  }

  return {
    success: true,
    roomKey: Buffer.from(decResult.plaintext).toString("base64"),
  };
}
