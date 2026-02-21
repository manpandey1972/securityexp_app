/**
 * E2EE Key Backup Cloud Functions.
 *
 * Provides server-side key backup with defense-in-depth wrapping:
 * 1. Client encrypts keys with passphrase-derived key (PBKDF2)
 * 2. Server wraps the blob with Google Cloud KMS
 * 3. Double-encrypted backup stored in Firestore
 *
 * The server NEVER sees plaintext keys.
 */

import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";
import {db} from "../utils";

// KMS configuration for production:
// import {KeyManagementServiceClient} from "@google-cloud/kms";
// const kmsClient = new KeyManagementServiceClient();
// const KMS_KEY_RING = `projects/${process.env.GCP_PROJECT}/locations/global/keyRings/e2ee-chat`;
// const BACKUP_KEY = `${KMS_KEY_RING}/cryptoKeys/backup-wrapping-key`;

/** Maximum backup size in bytes (1MB). */
const MAX_BACKUP_SIZE = 1024 * 1024;

/**
 * Store an encrypted key backup.
 *
 * Flow:
 * 1. Client encrypts keys with passphrase-derived key (PBKDF2)
 * 2. Client sends already-encrypted blob to this function
 * 3. Server wraps the blob with KMS (defense in depth)
 * 4. Server stores double-encrypted backup in Firestore
 *
 * Called from the unified `api` callable with action="storeKeyBackup".
 */
export async function handleStoreKeyBackup(
  auth: {uid: string},
  payload: Record<string, any>,
): Promise<{success: boolean; message: string}> {
  const userId = auth.uid;
  const {encryptedData, salt, iv, version} = payload;

  if (!encryptedData || !salt || !iv) {
    throw new HttpsError(
      "invalid-argument",
      "Missing required fields: encryptedData, salt, iv",
    );
  }

  // Validate size
  const dataSize = Buffer.from(encryptedData, "base64").length;
  if (dataSize > MAX_BACKUP_SIZE) {
    throw new HttpsError(
      "invalid-argument",
      `Backup too large: ${dataSize} bytes (max ${MAX_BACKUP_SIZE})`,
    );
  }

  // In production: wrap with KMS for defense in depth
  // const [wrapResult] = await kmsClient.encrypt({
  //   name: BACKUP_KEY,
  //   plaintext: Buffer.from(encryptedData, "base64"),
  // });
  // const kmsWrappedData = Buffer.from(wrapResult.ciphertext as Uint8Array).toString("base64");

  // For development: store client-encrypted data directly
  // In production, replace encryptedData with kmsWrappedData
  const backupData = {
    encrypted_data: encryptedData,
    salt,
    iv,
    version: version || 1,
    // kms_wrapped: true,  // Set to true when using KMS wrapping
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection("key_backups").doc(userId).set(backupData);

  logger.info("✅ Key backup stored", {
    userId,
    size: dataSize,
    version: version || 1,
  });

  return {success: true, message: "Key backup stored"};
}

/**
 * Retrieve encrypted key backup.
 *
 * Flow:
 * 1. Server unwraps KMS layer (in production)
 * 2. Returns client-encrypted blob (still encrypted with passphrase)
 * 3. Client decrypts with user's passphrase locally
 *
 * Called from the unified `api` callable with action="retrieveKeyBackup".
 */
export async function handleRetrieveKeyBackup(
  auth: {uid: string},
): Promise<{
    success: boolean;
    encryptedData: string;
    salt: string;
    iv: string;
    version: number;
  } | null> {
  const userId = auth.uid;

  const backupRef = db.collection("key_backups").doc(userId);
  const backupDoc = await backupRef.get();

  if (!backupDoc.exists) {
    return null;
  }

  const data = backupDoc.data();
  if (!data) return null;

  // In production: unwrap KMS layer
  // const [decryptResult] = await kmsClient.decrypt({
  //   name: BACKUP_KEY,
  //   ciphertext: Buffer.from(data.encrypted_data, "base64"),
  // });
  // const clientEncryptedData = Buffer.from(decryptResult.plaintext as Uint8Array).toString("base64");

  // For development: return client-encrypted data directly
  // In production, replace data.encrypted_data with clientEncryptedData
  logger.info("✅ Key backup retrieved", {userId});

  return {
    success: true,
    encryptedData: data.encrypted_data,
    salt: data.salt,
    iv: data.iv,
    version: data.version || 1,
  };
}

/**
 * Delete the key backup.
 *
 * Called from the unified `api` callable with action="deleteKeyBackup".
 */
export async function handleDeleteKeyBackup(
  auth: {uid: string},
): Promise<{success: boolean; message: string}> {
  const userId = auth.uid;

  await db.collection("key_backups").doc(userId).delete();

  logger.info("✅ Key backup deleted", {userId});

  return {success: true, message: "Key backup deleted"};
}

/**
 * Check if a key backup exists.
 *
 * Called from the unified `api` callable with action="hasKeyBackup".
 */
export async function handleHasKeyBackup(
  auth: {uid: string},
): Promise<boolean> {
  const userId = auth.uid;
  const backupDoc = await db.collection("key_backups").doc(userId).get();
  return backupDoc.exists;
}
