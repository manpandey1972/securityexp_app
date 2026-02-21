/**
 * E2EE Pre-Key Management Cloud Functions.
 *
 * Handles:
 * - Device registration with E2EE key material
 * - Pre-key bundle attestation via Google Cloud KMS
 * - OPK supply monitoring and replenishment alerts
 * - Signed pre-key rotation management
 */

import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";
import {db} from "../utils";

// KMS configuration — uses Google Cloud KMS for key attestation.
// In production, uncomment and configure with actual KMS client:
// import {KeyManagementServiceClient} from "@google-cloud/kms";
// const kmsClient = new KeyManagementServiceClient();
// const KMS_KEY_RING = `projects/${process.env.GCP_PROJECT}/locations/global/keyRings/e2ee-chat`;
// const ATTESTATION_KEY = `${KMS_KEY_RING}/cryptoKeys/prekey-attestation-key/cryptoKeyVersions/1`;

/** Maximum number of devices per user. */
const MAX_DEVICES_PER_USER = 5;

/** Minimum OPK count before triggering replenishment alert. */
const OPK_REPLENISH_THRESHOLD = 20;

/** Expected OPK batch size. */
const OPK_BATCH_SIZE = 100;

/**
 * Register a new device's identity key and prekey bundle.
 *
 * Called from the unified `api` callable with action="registerDevice".
 *
 * Validates:
 * - User authentication
 * - Device limit (max 5 per user)
 * - Required key material fields
 * - Bundle format consistency
 *
 * Stores the public PreKeyBundle in Firestore at:
 *   users/{userId}/devices/{deviceId}
 */
export async function handleRegisterDevice(
  auth: {uid: string},
  payload: Record<string, any>,
): Promise<{success: boolean; message: string}> {
  const userId = auth.uid;
  const {
    deviceId,
    identityKey,
    signingKey,
    signedPreKey,
    oneTimePreKeys,
    registrationId,
    deviceName,
  } = payload;

  // Validate required fields
  if (!deviceId || !identityKey || !signingKey || !signedPreKey || !registrationId) {
    throw new HttpsError(
      "invalid-argument",
      "Missing required fields: deviceId, identityKey, signingKey, signedPreKey, registrationId",
    );
  }

  // Validate signed pre-key structure
  if (!signedPreKey.key_id || !signedPreKey.public_key || !signedPreKey.signature) {
    throw new HttpsError(
      "invalid-argument",
      "signedPreKey must have key_id, public_key, and signature",
    );
  }

  // Check device limit
  const devicesRef = db.collection("users").doc(userId).collection("devices");
  const existingDevices = await devicesRef.get();

  if (existingDevices.size >= MAX_DEVICES_PER_USER) {
    throw new HttpsError(
      "resource-exhausted",
      `Maximum ${MAX_DEVICES_PER_USER} devices reached. Remove a device before adding a new one.`,
    );
  }

  // Check if device already exists
  const existingDevice = await devicesRef.doc(deviceId).get();
  if (existingDevice.exists) {
    throw new HttpsError(
      "already-exists",
      `Device ${deviceId} is already registered.`,
    );
  }

  // Store the PreKeyBundle
  const bundleData = {
    user_id: userId,
    device_id: deviceId,
    identity_key: identityKey,
    signing_key: signingKey,
    signed_pre_key: signedPreKey,
    one_time_pre_keys: oneTimePreKeys || [],
    registration_id: registrationId,
    device_name: deviceName || "Unknown device",
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    last_active: admin.firestore.FieldValue.serverTimestamp(),
  };

  await devicesRef.doc(deviceId).set(bundleData);

  // Log to key transparency log
  await db.collection("key_transparency_log").add({
    user_id: userId,
    device_id: deviceId,
    action: "device_registered",
    identity_key: identityKey,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info("✅ Device registered for E2EE", {
    userId,
    deviceId,
    opkCount: (oneTimePreKeys || []).length,
  });

  return {success: true, message: "Device registered successfully"};
}

/**
 * Deregister (revoke) a device, removing its E2EE keys from Firestore.
 *
 * Called from the unified `api` callable with action="deregisterDevice".
 */
export async function handleDeregisterDevice(
  auth: {uid: string},
  payload: Record<string, any>,
): Promise<{success: boolean; message: string}> {
  const userId = auth.uid;
  const {deviceId} = payload;

  if (!deviceId) {
    throw new HttpsError("invalid-argument", "Missing required field: deviceId");
  }

  const deviceRef = db.collection("users").doc(userId).collection("devices").doc(deviceId);
  const deviceDoc = await deviceRef.get();

  if (!deviceDoc.exists) {
    throw new HttpsError("not-found", `Device ${deviceId} not found.`);
  }

  await deviceRef.delete();

  // Log to transparency log
  await db.collection("key_transparency_log").add({
    user_id: userId,
    device_id: deviceId,
    action: "device_deregistered",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info("✅ Device deregistered", {userId, deviceId});

  return {success: true, message: "Device deregistered successfully"};
}

/**
 * Attest a prekey bundle's authenticity with KMS signature.
 *
 * Called from the unified `api` callable with action="attestPrekeyBundle".
 *
 * In production, this signs the bundle hash with a KMS asymmetric key
 * to provide server-attested proof the bundle was published through
 * an authorized channel.
 */
export async function handleAttestPrekeyBundle(
  auth: {uid: string},
  payload: Record<string, any>,
): Promise<{success: boolean; attestation: string}> {
  const userId = auth.uid;
  const {deviceId, bundleHash} = payload;

  if (!deviceId || !bundleHash) {
    throw new HttpsError(
      "invalid-argument",
      "Missing required fields: deviceId, bundleHash",
    );
  }

  // Verify the device belongs to this user
  const deviceRef = db.collection("users").doc(userId).collection("devices").doc(deviceId);
  const deviceDoc = await deviceRef.get();

  if (!deviceDoc.exists) {
    throw new HttpsError("not-found", `Device ${deviceId} not found.`);
  }

  // In production, sign with KMS:
  // const [signResult] = await kmsClient.asymmetricSign({
  //   name: ATTESTATION_KEY,
  //   digest: {sha256: Buffer.from(bundleHash, "base64")},
  // });
  // const signature = signResult.signature;

  // For development: create a placeholder attestation
  const attestation = Buffer.from(
    JSON.stringify({
      userId,
      deviceId,
      bundleHash,
      attestedAt: new Date().toISOString(),
      // In production: signature from KMS
    }),
  ).toString("base64");

  // Store attestation on device record
  await deviceRef.update({attestation});

  logger.info("✅ PreKey bundle attested", {userId, deviceId});

  return {success: true, attestation};
}

/**
 * Check and alert on low OPK supply for a device.
 *
 * Called after message creation to check if the recipient's OPK
 * count has fallen below the replenishment threshold.
 * This is invoked internally, not directly by clients.
 */
export async function checkOPKSupply(
  userId: string,
  deviceId: string,
): Promise<void> {
  const deviceRef = db.collection("users").doc(userId).collection("devices").doc(deviceId);
  const deviceDoc = await deviceRef.get();

  if (!deviceDoc.exists) return;

  const data = deviceDoc.data();
  if (!data) return;

  const opkCount = (data.one_time_pre_keys || []).length;

  if (opkCount < OPK_REPLENISH_THRESHOLD) {
    logger.warn("⚠️ Low OPK supply", {
      userId,
      deviceId,
      opkCount,
      threshold: OPK_REPLENISH_THRESHOLD,
    });

    // Set a flag on the user document to notify the client
    // The client will check this flag on next app launch and replenish
    await db.collection("users").doc(userId).set(
      {
        e2ee_opk_replenish_needed: true,
        e2ee_opk_replenish_device: deviceId,
      },
      {merge: true},
    );
  }
}

/**
 * Replenish one-time pre-keys for a device.
 *
 * Called from the unified `api` callable with action="replenishOPKs".
 * The client generates new OPKs and sends the public parts.
 */
export async function handleReplenishOPKs(
  auth: {uid: string},
  payload: Record<string, any>,
): Promise<{success: boolean; message: string}> {
  const userId = auth.uid;
  const {deviceId, oneTimePreKeys} = payload;

  if (!deviceId || !oneTimePreKeys || !Array.isArray(oneTimePreKeys)) {
    throw new HttpsError(
      "invalid-argument",
      "Missing required fields: deviceId, oneTimePreKeys (array)",
    );
  }

  if (oneTimePreKeys.length > OPK_BATCH_SIZE) {
    throw new HttpsError(
      "invalid-argument",
      `Maximum ${OPK_BATCH_SIZE} OPKs per batch.`,
    );
  }

  const deviceRef = db.collection("users").doc(userId).collection("devices").doc(deviceId);
  const deviceDoc = await deviceRef.get();

  if (!deviceDoc.exists) {
    throw new HttpsError("not-found", `Device ${deviceId} not found.`);
  }

  // Append new OPKs
  await deviceRef.update({
    one_time_pre_keys: admin.firestore.FieldValue.arrayUnion(...oneTimePreKeys),
    last_active: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Clear replenishment flag
  await db.collection("users").doc(userId).update({
    e2ee_opk_replenish_needed: admin.firestore.FieldValue.delete(),
    e2ee_opk_replenish_device: admin.firestore.FieldValue.delete(),
  });

  logger.info("✅ OPKs replenished", {
    userId,
    deviceId,
    count: oneTimePreKeys.length,
  });

  return {success: true, message: `${oneTimePreKeys.length} OPKs added`};
}

/**
 * Rotate signed pre-key for a device.
 *
 * Called from the unified `api` callable with action="rotateSignedPreKey".
 */
export async function handleRotateSignedPreKey(
  auth: {uid: string},
  payload: Record<string, any>,
): Promise<{success: boolean; message: string}> {
  const userId = auth.uid;
  const {deviceId, signedPreKey} = payload;

  if (!deviceId || !signedPreKey) {
    throw new HttpsError(
      "invalid-argument",
      "Missing required fields: deviceId, signedPreKey",
    );
  }

  if (!signedPreKey.key_id || !signedPreKey.public_key || !signedPreKey.signature) {
    throw new HttpsError(
      "invalid-argument",
      "signedPreKey must have key_id, public_key, and signature",
    );
  }

  const deviceRef = db.collection("users").doc(userId).collection("devices").doc(deviceId);
  const deviceDoc = await deviceRef.get();

  if (!deviceDoc.exists) {
    throw new HttpsError("not-found", `Device ${deviceId} not found.`);
  }

  await deviceRef.update({
    signed_pre_key: signedPreKey,
    last_active: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Log rotation to transparency log
  await db.collection("key_transparency_log").add({
    user_id: userId,
    device_id: deviceId,
    action: "spk_rotated",
    new_spk_id: signedPreKey.key_id,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info("✅ Signed pre-key rotated", {
    userId,
    deviceId,
    newSpkId: signedPreKey.key_id,
  });

  return {success: true, message: "Signed pre-key rotated"};
}
