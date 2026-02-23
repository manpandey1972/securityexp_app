# E2EE Per-Room Symmetric Key Design — v3.0 (KMS-Protected)

> **Version**: 3.0 — KMS-wrapped room keys, no client-side key management
> **Status**: Approved
> **Last Updated**: 2025-01-XX
> **Replaces**: v2.1 (X25519 + ECIES hybrid model)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Why Replace Signal Protocol](#2-why-replace-signal-protocol)
3. [Requirements](#3-requirements)
4. [Architecture Overview](#4-architecture-overview)
5. [Key Hierarchy](#5-key-hierarchy)
6. [Cryptographic Primitives](#6-cryptographic-primitives)
7. [Data Models](#7-data-models)
8. [Firestore Schema](#8-firestore-schema)
9. [Key Lifecycle](#9-key-lifecycle)
10. [Message Encryption Flow](#10-message-encryption-flow)
11. [Message Decryption Flow](#11-message-decryption-flow)
12. [Media & Document Encryption](#12-media--document-encryption)
13. [Cloud Functions — Room Key Management](#13-cloud-functions--room-key-management)
14. [Multi-Device & New Device Support](#14-multi-device--new-device-support)
15. [Web Platform Support](#15-web-platform-support)
16. [Cloud Functions Summary](#16-cloud-functions-summary)
17. [Firestore Security Rules](#17-firestore-security-rules)
18. [Service Layer Architecture](#18-service-layer-architecture)
19. [Security Analysis](#19-security-analysis)
20. [Limitations & Tradeoffs](#20-limitations--tradeoffs)
21. [Migration from Signal Protocol](#21-migration-from-signal-protocol)
22. [Implementation Phases](#22-implementation-phases)
23. [Appendix: Reusable Components](#23-appendix-reusable-components)

---

## 1. Executive Summary

This design replaces the Signal Protocol (X3DH + Double Ratchet) with a
dramatically simpler **per-room symmetric key** model protected by
**Google Cloud KMS**.

### Core Idea

Each chat room gets **one immutable AES-256 key** generated server-side
by a Cloud Function. The plaintext key is returned to the room creator
over HTTPS; subsequently, any authenticated participant retrieves it via
another Cloud Function call. The Cloud Function verifies the caller is a
room participant before releasing the key. At rest in Firestore, the
room key is encrypted by Cloud KMS — no client, no admin, no attacker
with Firestore access alone can decrypt it.

### What Changes

| Aspect | Signal Protocol (v1) | Room Key + KMS (v3) |
|--------|---------------------|---------------------|
| Identity keys | X25519 per device | **None** |
| Session management | X3DH + Double Ratchet | **None** |
| Key backup | Passphrase-encrypted export | **None (automatic)** |
| Multi-device | Complex per-device keying | **Transparent — any authenticated device** |
| Device migration | User must enter passphrase | **Zero action — just log in** |
| Web support | Disabled (no secure storage) | **Fully supported** |
| Client crypto deps | libsodium.js, flutter_secure_storage | **dart:crypto (pointycastle) only** |
| Forward secrecy | Per-message | **None** |
| Trust model | Trust on first use (TOFU) | **Trust the server (Cloud KMS)** |
| Cloud Functions | 10 handlers | **2 handlers** |
| Complexity | ~3,400 lines Dart + ~800 lines TS | **~400 lines Dart + ~150 lines TS** |

### Key Properties

- **Zero-friction device migration**: Log in → read every historical message
- **No client-side persistent key storage**: Room keys cached in memory only
- **No passphrase, no QR code, no manual backup**
- **Works on all platforms identically** (iOS, Android, Web)
- **Server cannot read messages** without KMS decrypt permission
  (separation of duties: Firestore admin ≠ KMS admin)

---

## 2. Why Replace Signal Protocol

The Signal Protocol implementation (Phases 1–7) was completed and
deployed to production. Testing revealed fundamental usability problems
for our app's requirements:

1. **Single-device lock**: Each device has its own identity key pair.
   Users cannot seamlessly access chat history from a new device without
   a manual key backup/restore flow.

2. **No web support**: `flutter_secure_storage` has no web implementation.
   E2EE was disabled on web with `kIsWeb` guards throughout the codebase.

3. **Testing friction**: X3DH requires two distinct devices to establish
   a session. Cannot test with a single simulator.

4. **Passphrase fatigue**: Users must remember a backup passphrase to
   restore keys on a new device. Support tickets for lost passphrases
   are inevitable.

5. **Complexity disproportionate to threat model**: Our app connects
   security professionals to clients. A per-room symmetric key with
   KMS protection provides the right security/usability balance.

---

## 3. Requirements

### Functional Requirements

| ID | Requirement |
|----|------------|
| FR-1 | Each chat room has a unique symmetric encryption key |
| FR-2 | Room key is created once when the room is created and never changes |
| FR-3 | Room key is protected at rest by Cloud KMS |
| FR-4 | Only authenticated room participants can obtain the room key |
| FR-5 | All text messages are AES-256-GCM encrypted client-side |
| FR-6 | Media/documents are encrypted with per-file keys; file keys travel inside the encrypted message envelope |
| FR-7 | New devices can read all historical messages with no user action |

### Non-Functional Requirements

| ID | Requirement |
|----|------------|
| NFR-1 | Message encrypt/decrypt < 5ms on mid-range device |
| NFR-2 | Room key retrieval < 300ms (cold) / 0ms (cached) |
| NFR-3 | Cloud Function cold start < 2s |
| NFR-4 | Works identically on iOS, Android, and Web |
| NFR-5 | No client-side persistent key storage required |
| NFR-6 | Room key ciphertext indistinguishable from random to Firestore admin |

---

## 4. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Flutter Client                       │
│                                                          │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐ │
│  │  RoomKey      │   │  Encryption  │   │  Media       │ │
│  │  Service      │──▶│  Service     │──▶│  Encryption  │ │
│  │ (CF client)   │   │ (AES-GCM)   │   │  Service     │ │
│  └──────┬───────┘   └──────────────┘   └──────────────┘ │
│         │ HTTPS (Firebase Auth token)                    │
└─────────┼───────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────┐
│              Cloud Functions (Node.js 22)                │
│                                                          │
│  ┌──────────────┐         ┌──────────────┐              │
│  │ sealRoomKey  │────────▶│  Cloud KMS   │              │
│  │ getRoomKey   │◀────────│  (AES-256)   │              │
│  └──────┬───────┘         └──────────────┘              │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐                                       │
│  │  Firestore   │                                       │
│  │  (ciphertext │                                       │
│  │   storage)   │                                       │
│  └──────────────┘                                       │
└─────────────────────────────────────────────────────────┘
```

### Flow Summary

1. **Room creation**: Client creates room → calls `sealRoomKey` Cloud Function
2. **Cloud Function**: Generates random 32-byte AES key → KMS.encrypt → stores ciphertext
   on room doc → returns plaintext key to caller
3. **Message send**: Client uses room key to AES-256-GCM encrypt → writes to Firestore
4. **Message receive**: Client has room key in memory (or calls `getRoomKey` to fetch) →
   AES-256-GCM decrypt locally
5. **New device**: User logs in → opens room → app calls `getRoomKey` → Cloud Function
   verifies participant → KMS.decrypt → returns plaintext key → all history readable

---

## 5. Key Hierarchy

```
Cloud KMS KEK (Key Encryption Key)
  "room-key-encryption-key" — AES-256, symmetric encrypt/decrypt
  │
  ├── Room Key (room A) — 32 random bytes, wrapped by KEK
  │     │
  │     ├── Message Key = Room Key (used directly with per-message IV)
  │     │
  │     └── Media Key — 32 random bytes per file (inside encrypted envelope)
  │
  ├── Room Key (room B) — 32 random bytes, wrapped by KEK
  │     └── ...
  │
  └── Room Key (room N)
        └── ...
```

### Key Types

| Key | Size | Lifetime | Storage | Who Has Access |
|-----|------|----------|---------|----------------|
| KMS KEK | 256-bit | Indefinite (GCP-managed) | Cloud KMS | Cloud Function SA only |
| Room Key | 256-bit | Lifetime of room | Firestore (KMS-encrypted) | Room participants (via CF) |
| Message IV | 96-bit | Single message | Firestore (plaintext) | Anyone who reads the doc |
| Media Key | 256-bit + 96-bit IV | Single file | Inside encrypted message | Sender + recipient |

---

## 6. Cryptographic Primitives

### Client-Side (Flutter/Dart)

| Primitive | Usage | Library |
|-----------|-------|---------|
| AES-256-GCM | Message & media encryption | `pointycastle` via `CryptoProvider` |
| SHA-256 | Media integrity hash | `pointycastle` via `CryptoProvider` |
| CSPRNG | IV generation, media key generation | `dart:math` `Random.secure()` |

### Server-Side (Cloud Functions)

| Primitive | Usage | Library |
|-----------|-------|---------|
| AES-256 (KMS-managed) | Room key wrapping | `@google-cloud/kms` |
| CSPRNG | Room key generation | Node.js `crypto.randomBytes()` |

### Eliminated Primitives (vs Signal Protocol)

| Primitive | Was Used For | Status |
|-----------|-------------|--------|
| X25519 | Identity key pairs | **Deleted** |
| Ed25519 | PreKey signatures | **Deleted** |
| HKDF-SHA-256 | X3DH shared secret derivation | **Deleted** |
| HMAC-SHA-256 | Ratchet chain advancement | **Deleted** |
| PBKDF2-SHA-256 | Key backup passphrase | **Deleted** |

---

## 7. Data Models

### New Models

#### `RoomKeyInfo` (Dart — client cache)

```dart
/// Cached room key for in-memory use.
/// Never persisted to disk.
class RoomKeyInfo {
  /// The room this key belongs to.
  final String roomId;

  /// 32-byte AES-256 key (plaintext, in-memory only).
  final Uint8List key;

  /// When this key was retrieved from the Cloud Function.
  final DateTime retrievedAt;

  const RoomKeyInfo({
    required this.roomId,
    required this.key,
    required this.retrievedAt,
  });

  /// Securely zero-out key material.
  void dispose() {
    for (var i = 0; i < key.length; i++) {
      key[i] = 0;
    }
  }
}
```

### Modified Models

#### `EncryptedMessage` v2 (simplified)

```dart
class EncryptedMessage extends Equatable {
  final String id;
  final String senderId;
  final String type;
  final String ciphertext;    // AES-256-GCM ciphertext (Base64)
  final String iv;             // 12-byte IV (Base64) — replaces RatchetHeader
  final Timestamp timestamp;
  final int encryptionVersion; // 2

  // Removed: header (RatchetHeader), initialMessage (X3DH)
}
```

### Deleted Models

| Model | File | Reason |
|-------|------|--------|
| `IdentityKeyPair` | `identity_key_pair.dart` | No identity keys |
| `PreKeyBundle` | `pre_key_bundle.dart` | No X3DH |
| `RatchetHeader` | `ratchet_header.dart` | No Double Ratchet |
| `SessionState` | `session_state.dart` | No sessions |

### Unchanged Models

| Model | File | Reason |
|-------|------|--------|
| `DecryptedContent` | `decrypted_content.dart` | Same envelope for text/media |

---

## 8. Firestore Schema

### Room Document

```
chat_rooms/{roomId}
  ├── participants: [userA, userB]
  ├── last_message: "..."
  ├── last_message_time: Timestamp
  ├── created_at: Timestamp
  ├── e2ee_enabled: true                    // NEW
  └── encrypted_room_key: "Base64..."       // NEW — KMS ciphertext
```

### Message Document (v2)

```
chat_rooms/{roomId}/messages/{messageId}
  ├── sender_id: "uid_abc"
  ├── type: "text" | "image" | "video" | "audio" | "doc"
  ├── ciphertext: "Base64..."               // AES-256-GCM ciphertext
  ├── iv: "Base64..."                       // 12-byte IV (NEW — replaces header)
  ├── encryption_version: 2                 // NEW version
  └── timestamp: Timestamp
```

### Deleted Collections

| Collection | Reason |
|-----------|--------|
| `chat_rooms/{roomId}/keys/{userId}` | No per-user encrypted room keys |
| `users/{userId}/devices/{deviceId}` | No device registration |
| `key_backups/{userId}` | No key backup |
| `key_transparency_log/{logId}` | No key transparency |

---

## 9. Key Lifecycle

### Room Key — Creation

```
     Client                   Cloud Function              KMS
       │                           │                       │
       │  1. createRoom()          │                       │
       │  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─▶│                       │
       │                           │                       │
       │  2. sealRoomKey(roomId)   │                       │
       │  ════════════════════════▶│                       │
       │                           │  3. randomBytes(32)   │
       │                           │  ─ ─ ─ ─ ─ ─ ─ ─ ─▶ │
       │                           │                       │
       │                           │  4. KMS.encrypt(key)  │
       │                           │  ════════════════════▶│
       │                           │                       │
       │                           │  5. ciphertext        │
       │                           │  ◀════════════════════│
       │                           │                       │
       │                           │  6. Store ciphertext  │
       │                           │     on room doc       │
       │                           │                       │
       │  7. { roomKey: plaintext }│                       │
       │  ◀════════════════════════│                       │
       │                           │                       │
       │  8. Cache in memory       │                       │
       ▼                           ▼                       ▼
```

### Room Key — Retrieval (new device / other participant)

```
     Client                   Cloud Function              KMS
       │                           │                       │
       │  1. getRoomKey(roomId)    │                       │
       │  ════════════════════════▶│                       │
       │                           │                       │
       │                           │  2. Verify caller is  │
       │                           │     room participant  │
       │                           │                       │
       │                           │  3. Read ciphertext   │
       │                           │     from room doc     │
       │                           │                       │
       │                           │  4. KMS.decrypt(ct)   │
       │                           │  ════════════════════▶│
       │                           │                       │
       │                           │  5. plaintext key     │
       │                           │  ◀════════════════════│
       │                           │                       │
       │  6. { roomKey: plaintext }│                       │
       │  ◀════════════════════════│                       │
       │                           │                       │
       │  7. Cache in memory       │                       │
       ▼                           ▼                       ▼
```

### Key Properties

- **Immutable**: Room key never rotates or changes
- **Created once**: By the Cloud Function when the room is created
- **No expiry**: Valid for the lifetime of the room
- **No per-device keys**: Every authenticated participant gets the same key

---

## 10. Message Encryption Flow

```dart
Future<EncryptedMessage> encryptMessage({
  required String roomId,
  required String senderId,
  required String messageType,
  required DecryptedContent content,
}) async {
  // 1. Get room key (from memory cache or Cloud Function)
  final roomKey = await _roomKeyService.getRoomKey(roomId);

  // 2. Serialize plaintext
  final plaintext = utf8.encode(content.toJson());

  // 3. Generate random 12-byte IV
  final iv = _crypto.secureRandomBytes(12);

  // 4. AES-256-GCM encrypt
  final ciphertext = await _cipher.encrypt(
    key: roomKey.key,
    iv: iv,
    plaintext: Uint8List.fromList(plaintext),
  );

  // 5. Return encrypted message
  return EncryptedMessage(
    id: '',
    senderId: senderId,
    type: messageType,
    ciphertext: base64Encode(ciphertext),
    iv: base64Encode(iv),
    timestamp: Timestamp.now(),
    encryptionVersion: 2,
  );
}
```

### IV Uniqueness Guarantee

Each message gets a fresh 12-byte random IV from the platform CSPRNG.
With a 96-bit IV space, the probability of collision is negligible
for ≤ 2³² messages per room key (birthday bound). Our rooms will
have at most a few hundred to a few thousand messages, so this is
safe by a factor of > 10⁶.

---

## 11. Message Decryption Flow

```dart
Future<DecryptedContent> decryptMessage({
  required String roomId,
  required EncryptedMessage message,
}) async {
  // 1. Get room key (from memory cache or Cloud Function)
  final roomKey = await _roomKeyService.getRoomKey(roomId);

  // 2. Decode ciphertext and IV
  final ciphertext = base64Decode(message.ciphertext);
  final iv = base64Decode(message.iv);

  // 3. AES-256-GCM decrypt
  final plaintext = await _cipher.decrypt(
    key: roomKey.key,
    iv: iv,
    ciphertext: ciphertext,
  );

  // 4. Deserialize
  final json = utf8.decode(plaintext);
  return DecryptedContent.fromJson(jsonDecode(json));
}
```

### Error Handling

| Error | Cause | Recovery |
|-------|-------|----------|
| GCM auth failure | Tampered ciphertext or wrong key | Show "cannot decrypt" placeholder |
| `getRoomKey` 403 | User removed from room | Show "access denied" |
| `getRoomKey` 404 | Room key not yet created | Retry with backoff |
| Network timeout | Offline | Queue for retry when online |

---

## 12. Media & Document Encryption

**Unchanged from current implementation.** `MediaEncryptionService`
already uses per-file random AES-256-GCM keys. The only change is
how the file key travels:

| Aspect | Signal Protocol (v1) | Room Key (v3) |
|--------|---------------------|---------------|
| File encryption | Per-file random AES-256-GCM | **Same** |
| File key transport | Inside Double Ratchet ciphertext | Inside AES-256-GCM ciphertext (room key) |
| File key in `DecryptedContent.mediaKey` | Yes | **Yes (unchanged)** |
| Thumbnail encryption | Same as file | **Same** |

### Flow (unchanged)

1. `MediaEncryptionService.encryptFile(bytes)` → random key + IV → ciphertext
2. Upload ciphertext to Firebase Storage
3. Put `mediaKey`, `mediaUrl`, `mediaHash` into `DecryptedContent`
4. Encrypt `DecryptedContent` with room key (§10)
5. Recipient decrypts message → gets `mediaKey` → downloads & decrypts file

---

## 13. Cloud Functions — Room Key Management

### `sealRoomKey`

Called once when a room is created. Generates a random room key,
encrypts it with KMS, stores the ciphertext on the room doc, and
returns the plaintext key to the caller.

```typescript
import * as crypto from "crypto";
import {KeyManagementServiceClient} from "@google-cloud/kms";
import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions/v2";
import {AuthData} from "firebase-functions/lib/common/providers/https";
import {HttpsError} from "firebase-functions/v2/https";

const kms = new KeyManagementServiceClient();
const db = getFirestore();

const KMS_KEY_NAME =
  "projects/securityexp-app/locations/global/keyRings/e2ee-chat" +
  "/cryptoKeys/room-key-encryption-key";

/**
 * Generate, KMS-encrypt, and store a room key.
 * Returns the plaintext key to the caller (room creator).
 *
 * Preconditions:
 * - Caller is authenticated
 * - Caller is a participant of the room
 * - Room does not already have an encrypted_room_key
 */
export async function handleSealRoomKey(
  auth: AuthData,
  payload: Record<string, any>
): Promise<{success: boolean; roomKey: string}> {
  const uid = auth.uid;
  const {roomId} = payload;

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

  // 2. Check idempotency — don't overwrite existing key
  if (roomDoc.data()?.encrypted_room_key) {
    logger.warn(`Room ${roomId} already has a key, returning existing`);
    // Decrypt and return existing key
    return await _decryptAndReturn(roomDoc.data()!.encrypted_room_key);
  }

  // 3. Generate random 32-byte room key
  const roomKey = crypto.randomBytes(32);

  // 4. KMS encrypt
  const [result] = await kms.encrypt({
    name: KMS_KEY_NAME,
    plaintext: roomKey,
  });

  if (!result.ciphertext) {
    throw new HttpsError("internal", "KMS encryption failed");
  }

  const ciphertextB64 = Buffer.from(result.ciphertext).toString("base64");

  // 5. Store on room document
  await roomRef.update({
    encrypted_room_key: ciphertextB64,
    e2ee_enabled: true,
  });

  logger.info(`Room key sealed for room ${roomId} by ${uid}`);

  // 6. Return plaintext key to caller
  return {
    success: true,
    roomKey: roomKey.toString("base64"),
  };
}

async function _decryptAndReturn(
  ciphertextB64: string
): Promise<{success: boolean; roomKey: string}> {
  const ciphertext = Buffer.from(ciphertextB64, "base64");
  const [result] = await kms.decrypt({
    name: KMS_KEY_NAME,
    ciphertext: ciphertext,
  });

  if (!result.plaintext) {
    throw new HttpsError("internal", "KMS decryption failed");
  }

  return {
    success: true,
    roomKey: Buffer.from(result.plaintext).toString("base64"),
  };
}
```

### `getRoomKey`

Called by any authenticated participant to retrieve the room key.

```typescript
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
  payload: Record<string, any>
): Promise<{success: boolean; roomKey: string}> {
  const uid = auth.uid;
  const {roomId} = payload;

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

  // 3. KMS decrypt
  const ciphertext = Buffer.from(ciphertextB64, "base64");
  const [result] = await kms.decrypt({
    name: KMS_KEY_NAME,
    ciphertext: ciphertext,
  });

  if (!result.plaintext) {
    throw new HttpsError("internal", "KMS decryption failed");
  }

  logger.info(`Room key retrieved for room ${roomId} by ${uid}`);

  return {
    success: true,
    roomKey: Buffer.from(result.plaintext).toString("base64"),
  };
}
```

---

## 14. Multi-Device & New Device Support

### Zero-Friction Design

With KMS-wrapped room keys, multi-device and device migration are
trivially solved:

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Device A    │     │  Device B    │     │  New Phone   │
│  (original)  │     │  (tablet)    │     │  (replaced)  │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                     │                    │
       │  Firebase Auth      │  Firebase Auth     │  Firebase Auth
       │  (same UID)         │  (same UID)        │  (same UID)
       │                     │                    │
       ▼                     ▼                    ▼
┌─────────────────────────────────────────────────────────┐
│                    Cloud Function                        │
│                                                          │
│  getRoomKey(roomId)                                      │
│    1. Verify auth.uid ∈ room.participants                │
│    2. KMS.decrypt(encrypted_room_key)                    │
│    3. Return plaintext key                               │
│                                                          │
│  ✓ No device registration                                │
│  ✓ No per-device keys                                    │
│  ✓ No backup/restore                                     │
│  ✓ No passphrase                                         │
└─────────────────────────────────────────────────────────┘
```

### Scenarios

| Scenario | User Action | System Behavior |
|----------|-------------|-----------------|
| Open existing room on same device | None | Room key in memory cache |
| Open room on second device | Log in | `getRoomKey` → key from KMS |
| Replace phone, log into new device | Log in | `getRoomKey` → key from KMS, all history readable |
| Log out and log back in | Log in | Memory cache cleared → `getRoomKey` on next open |
| Uninstall and reinstall app | Log in | Same as new device |

---

## 15. Web Platform Support

### Fully Supported (vs disabled in v1)

The KMS model eliminates every web-specific blocker:

| Blocker (v1) | Resolution (v3) |
|-------------|-----------------|
| `flutter_secure_storage` unavailable | No secure storage needed — keys in memory only |
| `libsodium.js` WASM loading | No X25519/Ed25519 needed — only AES-GCM (dart:crypto) |
| `kIsWeb` guards throughout code | **All removed** |
| Web workers for crypto | Not needed — AES-GCM is fast enough in main thread |

### Web-Specific Notes

- Room key retrieved via Cloud Function (same as native)
- AES-256-GCM via `pointycastle` (pure Dart, runs on web)
- No platform channels, no FFI, no WASM
- Session storage: room keys live in Dart `Map<String, RoomKeyInfo>` (in-memory)
- Tab close → keys cleared → re-fetched on next load (invisible to user)

---

## 16. Cloud Functions Summary

### New Functions (2)

| Function | Action | Trigger |
|----------|--------|---------|
| `sealRoomKey` | `"sealRoomKey"` | Called after `getOrCreateRoom()` when room is new |
| `getRoomKey` | `"getRoomKey"` | Called when client needs room key (cache miss) |

### Deleted Functions (10)

| Function | Action | Reason |
|----------|--------|--------|
| `handleRegisterDevice` | `"registerDevice"` | No device registration |
| `handleDeregisterDevice` | `"deregisterDevice"` | No device registration |
| `handleAttestPrekeyBundle` | `"attestPrekeyBundle"` | No X3DH |
| `handleReplenishOPKs` | `"replenishOPKs"` | No one-time prekeys |
| `handleRotateSignedPreKey` | `"rotateSignedPreKey"` | No signed prekeys |
| `handleStoreKeyBackup` | `"storeKeyBackup"` | No key backup |
| `handleRetrieveKeyBackup` | `"retrieveKeyBackup"` | No key backup |
| `handleDeleteKeyBackup` | `"deleteKeyBackup"` | No key backup |
| `handleHasKeyBackup` | `"hasKeyBackup"` | No key backup |
| `checkOPKSupply` | (scheduled) | No one-time prekeys |

### KMS Key Setup

```bash
# Create the room key encryption key (if not already done)
gcloud kms keys create room-key-encryption-key \
  --location=global \
  --keyring=e2ee-chat \
  --purpose=encryption \
  --protection-level=software \
  --project=securityexp-app

# Grant Cloud Function SA decrypt+encrypt permissions
gcloud kms keys add-iam-policy-binding room-key-encryption-key \
  --location=global \
  --keyring=e2ee-chat \
  --member=serviceAccount:securityexp-app@appspot.gserviceaccount.com \
  --role=roles/cloudkms.cryptoKeyEncrypterDecrypter \
  --project=securityexp-app
```

### KMS Keys to Retire

| Key | Original Purpose | Action |
|-----|-----------------|--------|
| `prekey-attestation-key` | Sign prekey bundles | Retire (disable all versions) |
| `backup-wrapping-key` | Wrap key backup exports | Retire (disable all versions) |
| `audit-log-signing-key` | Sign audit logs | Retire (disable all versions) |

---

## 17. Firestore Security Rules

### New Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /chat_rooms/{roomId} {
      // Participants can read room metadata
      allow read: if request.auth != null
        && request.auth.uid in resource.data.participants;

      // Participants can create rooms
      allow create: if request.auth != null
        && request.auth.uid in request.resource.data.participants;

      // Participants can update last_message, last_message_time
      // But CANNOT write encrypted_room_key (server-only)
      allow update: if request.auth != null
        && request.auth.uid in resource.data.participants
        && !request.resource.data.diff(resource.data)
            .affectedKeys()
            .hasAny(['encrypted_room_key', 'e2ee_enabled', 'participants']);

      match /messages/{messageId} {
        // Participants can read all messages
        allow read: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/chat_rooms/$(roomId)).data.participants;

        // Participants can create messages (sender_id must match auth)
        allow create: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/chat_rooms/$(roomId)).data.participants
          && request.resource.data.sender_id == request.auth.uid;
      }
    }
  }
}
```

### Key Security Property

The `encrypted_room_key` and `e2ee_enabled` fields can **only** be written by
the Cloud Function (admin SDK bypasses security rules). No client can directly
read the KMS ciphertext to gain any advantage — it's encrypted by KMS and useless
without the KMS decrypt permission that only the Cloud Function SA has.

### Deleted Rules

Remove all rules for:
- `users/{userId}/devices/{deviceId}` — no device registration
- `chat_rooms/{roomId}/keys/{userId}` — no per-user key distribution
- `key_backups/{userId}` — no key backup
- `key_transparency_log/{logId}` — no key transparency

---

## 18. Service Layer Architecture

### New Services

#### `RoomKeyService` (Dart)

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

/// Manages room key retrieval from Cloud Functions.
/// Caches plaintext room keys in memory (never persisted to disk).
class RoomKeyService {
  static const String _tag = 'RoomKeyService';

  final FirebaseFunctions _functions;
  final AppLogger _log;

  /// In-memory cache: roomId → RoomKeyInfo
  final Map<String, RoomKeyInfo> _cache = {};

  RoomKeyService({
    required FirebaseFunctions functions,
    required AppLogger logger,
  })  : _functions = functions,
        _log = logger;

  /// Get the room key, from cache or Cloud Function.
  Future<RoomKeyInfo> getRoomKey(String roomId) async {
    // 1. Check memory cache
    final cached = _cache[roomId];
    if (cached != null) return cached;

    // 2. Call Cloud Function
    _log.debug('Fetching room key for $roomId', tag: _tag);
    final result = await _functions
        .httpsCallable('api')
        .call({'action': 'getRoomKey', 'payload': {'roomId': roomId}});

    final data = result.data as Map<String, dynamic>;
    final keyBytes = base64Decode(data['roomKey'] as String);

    final info = RoomKeyInfo(
      roomId: roomId,
      key: Uint8List.fromList(keyBytes),
      retrievedAt: DateTime.now(),
    );

    // 3. Cache in memory
    _cache[roomId] = info;
    return info;
  }

  /// Seal a new room key (called after room creation).
  Future<RoomKeyInfo> sealRoomKey(String roomId) async {
    _log.debug('Sealing room key for $roomId', tag: _tag);
    final result = await _functions
        .httpsCallable('api')
        .call({'action': 'sealRoomKey', 'payload': {'roomId': roomId}});

    final data = result.data as Map<String, dynamic>;
    final keyBytes = base64Decode(data['roomKey'] as String);

    final info = RoomKeyInfo(
      roomId: roomId,
      key: Uint8List.fromList(keyBytes),
      retrievedAt: DateTime.now(),
    );

    _cache[roomId] = info;
    return info;
  }

  /// Clear all cached keys (call on logout).
  void clearCache() {
    for (final info in _cache.values) {
      info.dispose();
    }
    _cache.clear();
    _log.debug('Room key cache cleared', tag: _tag);
  }

  /// Clear a specific room's key from cache.
  void evict(String roomId) {
    _cache[roomId]?.dispose();
    _cache.remove(roomId);
  }
}
```

#### `EncryptionService` v2 (Dart — rewritten)

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/core/crypto/aes_gcm_cipher.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';

/// Encrypts and decrypts chat messages using per-room AES-256 keys.
///
/// Room keys are managed by [RoomKeyService]. This service only
/// performs the symmetric AES-256-GCM encrypt/decrypt operations.
class EncryptionService {
  final RoomKeyService _roomKeyService;
  final CryptoProvider _crypto;
  final AesGcmCipher _cipher;

  EncryptionService({
    required RoomKeyService roomKeyService,
    required CryptoProvider crypto,
    AesGcmCipher? cipher,
  })  : _roomKeyService = roomKeyService,
        _crypto = crypto,
        _cipher = cipher ?? AesGcmCipher(crypto);

  /// Encrypt a message for a room.
  Future<EncryptedMessage> encryptMessage({
    required String roomId,
    required String senderId,
    required String messageType,
    required DecryptedContent content,
  }) async {
    final roomKey = await _roomKeyService.getRoomKey(roomId);
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(content.toJson())),
    );
    final iv = _crypto.secureRandomBytes(12);

    final ciphertext = await _cipher.encrypt(
      key: roomKey.key,
      iv: iv,
      plaintext: plaintext,
    );

    return EncryptedMessage(
      id: '',
      senderId: senderId,
      type: messageType,
      ciphertext: base64Encode(ciphertext),
      iv: base64Encode(iv),
      timestamp: Timestamp.now(),
      encryptionVersion: 2,
    );
  }

  /// Decrypt a message from a room.
  Future<DecryptedContent> decryptMessage({
    required String roomId,
    required EncryptedMessage message,
  }) async {
    final roomKey = await _roomKeyService.getRoomKey(roomId);
    final ciphertext = base64Decode(message.ciphertext);
    final iv = base64Decode(message.iv);

    final plaintext = await _cipher.decrypt(
      key: roomKey.key,
      iv: iv,
      ciphertext: ciphertext,
    );

    return DecryptedContent.fromJson(
      jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>,
    );
  }
}
```

### Deleted Services & Repositories

| File | Class | Reason |
|------|-------|--------|
| `lib/core/crypto/signal_protocol_engine.dart` | `SignalProtocolEngine` | No Signal Protocol |
| `lib/core/crypto/key_derivation.dart` | `KeyDerivation` | No HKDF/X3DH |
| `lib/data/repositories/crypto/prekey_repository.dart` | `PreKeyRepository` | No prekeys |
| `lib/data/repositories/crypto/session_repository.dart` | `ISessionRepository` | No sessions |
| `lib/data/repositories/crypto/key_store_repository.dart` | `IKeyStoreRepository` | No identity keys |
| `lib/data/repositories/crypto/native_key_store.dart` | `NativeKeyStore` | No secure storage |
| `lib/data/repositories/crypto/key_backup_repository.dart` | `KeyBackupRepository` | No backup |
| `lib/data/repositories/chat/decrypted_message_cache.dart` | `DecryptedMessageCache` | Not needed (direct decrypt) |
| `lib/features/chat/services/key_backup_service.dart` | `KeyBackupService` | No backup |
| `lib/features/chat/services/e2ee_initialization_service.dart` | `E2eeInitializationService` | No device init |
| `lib/features/chat/services/device_management_service.dart` | `DeviceManagementService` | No devices |
| `functions/src/e2ee/prekeyManagement.ts` | Prekey handlers | No prekeys |
| `functions/src/e2ee/keyBackup.ts` | Backup handlers | No backup |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/chat/services/encryption_service.dart` | Complete rewrite (§18 above) |
| `lib/data/models/crypto/encrypted_message.dart` | Replace `header` with `iv`, remove `initialMessage` |
| `lib/data/models/crypto/crypto_models.dart` | Update barrel exports |
| `lib/data/repositories/chat/chat_room_repository.dart` | Call `sealRoomKey` after room creation |
| `lib/data/repositories/chat/chat_message_repository.dart` | Update encrypt/decrypt calls |
| `lib/core/di/crypto_dependencies.dart` | Register new services, remove old ones |
| `functions/src/e2ee/index.ts` | Export new handlers, remove old ones |
| `functions/src/index.ts` | Update switch/case for new actions |
| `firestore.rules` | Protect `encrypted_room_key`, remove old collections |

---

## 19. Security Analysis

### Threat Model

| Threat | Mitigation | Residual Risk |
|--------|-----------|---------------|
| Firestore data breach | Room keys encrypted by KMS; attacker gets useless ciphertext | Low — requires KMS access |
| Rogue Firestore admin | Cannot decrypt room keys without KMS decrypt permission | Low — separation of duties |
| Cloud Function compromise | Attacker could decrypt room keys via KMS | Medium — standard CF security |
| Man-in-the-middle | HTTPS + Firebase Auth token; pinned certificates | Low |
| Replay attack | AES-GCM authentication tag; Firestore server timestamps | Low |
| IV reuse | Random 96-bit IV; collision probability negligible for <2³² messages | Negligible |
| Stolen device (locked) | Room keys only in memory; no persistent storage | None |
| Stolen device (unlocked, app open) | Room keys in Dart heap; attacker needs memory dump | Low |

### Security Properties

| Property | Provided? | Notes |
|----------|----------|-------|
| Confidentiality | ✅ | AES-256-GCM with KMS-protected keys |
| Integrity | ✅ | GCM authentication tag |
| Authentication | ✅ | Firebase Auth + participant check |
| Forward secrecy | ❌ | Room key compromise reveals all room history |
| Post-compromise security | ❌ | No ratcheting |
| Deniability | ❌ | GCM is authenticated |
| Zero-knowledge server | ❌ | Cloud Function sees plaintext keys transiently |

### Trust Boundary

```
┌─ Client Trust Zone ──────────────────────────────┐
│  Plaintext messages, room keys (in memory)        │
│  AES-256-GCM encrypt/decrypt                      │
└───────────────────────────────────────────────────┘
                    │ HTTPS
                    ▼
┌─ Server Trust Zone ──────────────────────────────┐
│  Cloud Function: sees plaintext room keys         │
│  Firestore: sees only KMS ciphertext              │
│  KMS: manages KEK, never exports it               │
│  Firebase Auth: authenticates users                │
└───────────────────────────────────────────────────┘
```

The server is **semi-trusted**: it can access plaintext room keys via
the Cloud Function, but this requires active exploitation. An attacker
who only gains Firestore database access (the most common breach vector)
cannot read any messages.

---

## 20. Limitations & Tradeoffs

1. **Not pure E2EE**: The Cloud Function transiently handles plaintext
   room keys. This is a deliberate tradeoff for zero-friction device
   migration. For our use case (security professionals communicating
   with clients), this provides the right balance.

2. **No forward secrecy**: Compromising a room key reveals the entire
   room history. Acceptable because room keys are KMS-protected and
   rooms have bounded size (1:1 chats with hundreds of messages).

3. **Cloud Function dependency**: Encryption/decryption requires the
   Cloud Function to be available for the initial room key fetch.
   Mitigated by in-memory caching — subsequent messages in the same
   session don't need the function.

4. **Single room key per room**: No rotation. If a user is removed from
   a room (future feature), they retain the ability to decrypt historical
   messages they were part of. New messages would require a new room.

5. **No deniability**: AES-GCM authentication tags prove message origin.
   Not relevant for our app's use case.

---

## 21. Migration from Signal Protocol

### Files to Delete

```
lib/core/crypto/signal_protocol_engine.dart
lib/core/crypto/key_derivation.dart
lib/data/models/crypto/identity_key_pair.dart
lib/data/models/crypto/pre_key_bundle.dart
lib/data/models/crypto/ratchet_header.dart
lib/data/models/crypto/session_state.dart
lib/data/repositories/crypto/prekey_repository.dart
lib/data/repositories/crypto/session_repository.dart
lib/data/repositories/crypto/key_store_repository.dart
lib/data/repositories/crypto/native_key_store.dart
lib/data/repositories/crypto/key_backup_repository.dart
lib/data/repositories/chat/decrypted_message_cache.dart
lib/features/chat/services/key_backup_service.dart
lib/features/chat/services/e2ee_initialization_service.dart
lib/features/chat/services/device_management_service.dart
functions/src/e2ee/prekeyManagement.ts
functions/src/e2ee/keyBackup.ts
```

### Files to Modify

```
lib/features/chat/services/encryption_service.dart     → Complete rewrite
lib/data/models/crypto/encrypted_message.dart          → v2 format (iv instead of header)
lib/data/models/crypto/crypto_models.dart              → Update exports
lib/data/repositories/chat/chat_room_repository.dart   → Call sealRoomKey
lib/data/repositories/chat/chat_message_repository.dart → Update encrypt/decrypt
lib/core/di/crypto_dependencies.dart                   → New DI registrations
functions/src/e2ee/index.ts                            → New exports
functions/src/index.ts                                 → New switch cases
firestore.rules                                        → Protect encrypted_room_key
```

### Files to Create

```
lib/data/models/crypto/room_key_info.dart              → RoomKeyInfo model
lib/data/repositories/crypto/room_key_repository.dart  → Cloud Function client
lib/features/chat/services/room_key_service.dart       → Room key orchestration
functions/src/e2ee/roomKeyManagement.ts                → sealRoomKey + getRoomKey
```

### Firestore Data Cleanup

```
# Delete all Signal Protocol data (run once after migration)
# These collections/subcollections are no longer used:

chat_rooms/{roomId}/keys/{userId}          → Delete all docs
users/{userId}/devices/{deviceId}          → Delete all docs
key_backups/{userId}                       → Delete all docs
key_transparency_log/{logId}               → Delete all docs
```

### Existing Message Migration

Messages encrypted with Signal Protocol (encryption_version: 1) will
**not** be migrated. They are permanently unreadable after the Signal
Protocol code is removed. This is acceptable because:
- The app is in early testing (limited real messages)
- Users have been informed about the E2EE architecture change

---

## 22. Implementation Phases

### Phase 1: Cloud Infrastructure (Day 1)

- [ ] Create KMS key `room-key-encryption-key`
- [ ] Create `functions/src/e2ee/roomKeyManagement.ts`
- [ ] Update `functions/src/e2ee/index.ts` with new exports
- [ ] Update `functions/src/index.ts` with new switch cases
- [ ] Deploy and test Cloud Functions
- [ ] Write Cloud Function tests

### Phase 2: Client Models & Services (Days 2-3)

- [ ] Create `RoomKeyInfo` model
- [ ] Rewrite `EncryptedMessage` to v2 format
- [ ] Create `RoomKeyService` (Cloud Function client + cache)
- [ ] Rewrite `EncryptionService` for room-key model
- [ ] Update `ChatRoomRepository.getOrCreateRoom()` to call `sealRoomKey`
- [ ] Update `ChatMessageRepository` encrypt/decrypt
- [ ] Update DI registrations in `crypto_dependencies.dart`
- [ ] Update barrel exports in `crypto_models.dart`

### Phase 3: Cleanup & Security Rules (Day 4)

- [ ] Delete all Signal Protocol files (17 files)
- [ ] Delete old Cloud Functions (`prekeyManagement.ts`, `keyBackup.ts`)
- [ ] Remove old switch cases from `functions/src/index.ts`
- [ ] Update `firestore.rules` to protect `encrypted_room_key`
- [ ] Remove all `kIsWeb` E2EE guards
- [ ] Clean up unused imports and dependencies

### Phase 4: Testing & Deployment (Days 5-7)

- [ ] Unit tests for `EncryptionService` v2
- [ ] Unit tests for `RoomKeyService`
- [ ] Integration tests: room creation → key seal → encrypt → decrypt
- [ ] Integration tests: multi-device key retrieval
- [ ] Integration tests: web platform
- [ ] Deploy to staging environment
- [ ] Deploy to production
- [ ] Retire old KMS keys
- [ ] Clean up Firestore data (old E2EE collections)

### Total Estimate: ~7 working days

---

## 23. Appendix: Reusable Components

These existing components are **unchanged** and reused as-is:

| Component | File | Usage |
|-----------|------|-------|
| `AesGcmCipher` | `lib/core/crypto/aes_gcm_cipher.dart` | Message & media AES-256-GCM |
| `CryptoProvider` | `lib/core/crypto/crypto_provider.dart` | AES-GCM + random bytes + SHA-256 |
| `NativeCryptoProvider` | `lib/core/crypto/native_crypto_provider.dart` | Platform implementation |
| `SecureRandom` | `lib/core/crypto/secure_random.dart` | CSPRNG wrapper |
| `DecryptedContent` | `lib/data/models/crypto/decrypted_content.dart` | Message plaintext envelope |
| `MediaEncryptionService` | `lib/features/chat/services/media_encryption_service.dart` | Per-file AES-256-GCM |
| `storage.rules` | `storage.rules` | Firebase Storage access rules |

### Removed Dependencies

| Package | Was Used For | Status |
|---------|-------------|--------|
| `flutter_secure_storage` | Identity key persistence | **Remove from pubspec.yaml** |
| `libsodium` / `sodium_libs` | X25519, Ed25519 | **Remove from pubspec.yaml** (if added) |

---

*End of document.*
