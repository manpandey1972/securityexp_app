# End-to-End Encryption (E2EE) for Chat

**Version:** 1.0  
**Status:** Design Proposal  
**Created:** February 21, 2026  
**Author:** Engineering Architecture Team  

---

## 📑 Table of Contents

1. [Overview](#1-overview)
2. [Requirements](#2-requirements)
3. [Threat Model](#3-threat-model)
4. [Cryptographic Protocol Design](#4-cryptographic-protocol-design)
5. [Key Management Architecture](#5-key-management-architecture)
6. [Data Models](#6-data-models)
7. [Architecture](#7-architecture)
8. [Service Layer](#8-service-layer)
9. [Cloud Functions](#9-cloud-functions)
10. [Media & Document Encryption](#10-media--document-encryption)
11. [Device & Session Management](#11-device--session-management)
12. [Web Client & Cross-Platform Support](#12-web-client--cross-platform-support)
13. [Firestore Security Rules](#13-firestore-security-rules)
14. [Performance & Scalability](#14-performance--scalability)
15. [Implementation Phases](#15-implementation-phases)
16. [Security Audit & Compliance](#16-security-audit--compliance)

---

## 1. Overview

### Purpose

Implement end-to-end encryption (E2EE) for the chat feature so that **only the sender and recipient** can read message content—including text, images, video, audio, and documents. The server (Firebase/GCP), network intermediaries, and even application administrators will have **zero access** to plaintext message content.

The design follows the **Signal Protocol** (Double Ratchet Algorithm), the same cryptographic framework used by WhatsApp, Signal, and Google Messages, adapted for our Firebase + Flutter architecture with NIST-compliant primitives and Google Cloud Secret Manager / Cloud KMS for server-side key material management.

### Goals

| Goal | Description |
|------|-------------|
| **Confidentiality** | Only chat participants can decrypt messages, media, and documents |
| **Forward Secrecy** | Compromise of long-term keys does not reveal past messages |
| **Future Secrecy** | Compromise of a session key does not reveal future messages (self-healing) |
| **NIST Compliance** | Use NIST-approved algorithms (AES-256-GCM, ECDH P-256/X25519, HKDF-SHA256) |
| **Performance** | <50ms encryption/decryption overhead per message on mid-range devices |
| **Scalability** | Key exchange scales O(1) per message after initial handshake |
| **Transparency** | Users can verify encryption via safety number / QR code comparison |
| **Zero Trust Server** | Server never has access to plaintext or private keys |

### Scope

| In Scope | Out of Scope |
|----------|--------------|
| 1:1 chat message encryption | Group chat E2EE (Phase 2) |
| Media encryption (image, video, audio) | Voice/video call E2EE (handled by LiveKit SRTP) |
| Document encryption | Message search on encrypted content |
| Key exchange protocol (Signal-based) | Custom crypto library implementation |
| Device/session management | Post-quantum cryptography (future consideration) |
| Safety number verification | Key escrow / law enforcement backdoor |
| Migration from plaintext to encrypted | Encrypted push notification content |
| Google Cloud KMS integration | HSM-based key storage |
| Key backup & recovery | Cross-platform browser extension support |

---

## 2. Requirements

### Functional Requirements

#### FR-1: Message Encryption
- All text messages MUST be encrypted client-side before transmission
- Encrypted messages stored in Firestore as ciphertext (Base64-encoded)
- Only the sender and recipient can decrypt messages
- System messages (join, leave, call logs) are NOT encrypted

#### FR-2: Media & Document Encryption
- All media (images, video, audio) MUST be encrypted before upload to Firebase Storage
- Documents (PDF, DOC, etc.) MUST be encrypted before upload
- Each media file uses a unique symmetric key (per-file key)
- Media keys are transmitted inside encrypted messages
- Thumbnails/previews are also encrypted

#### FR-3: Key Exchange
- Initial key exchange uses X3DH (Extended Triple Diffie-Hellman) protocol
- Ongoing message encryption uses Double Ratchet Algorithm
- Prekey bundles published to Firestore for asynchronous key exchange
- Signed prekeys rotated every 7 days
- One-time prekeys replenished when supply drops below 20

#### FR-4: Key Verification
- Users can compare safety numbers (fingerprints) out-of-band
- QR code scanning for in-person verification
- Visual indicator showing encryption status on chat screen
- Warning banner when a contact's identity key changes

#### FR-5: Multi-Device Support
- Each device has its own identity key pair
- Messages sent to all active devices of a recipient
- Device linking via QR code + identity verification
- Device deauthorization revokes session keys

#### FR-6: Key Backup & Recovery
- Optional encrypted key backup to Google Cloud Storage
- Backup encrypted with user-chosen passphrase (PBKDF2-derived key)
- Recovery flow for new device setup
- No server-side access to backup encryption key

### Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Encryption latency (text) | <10ms per message |
| Encryption latency (media) | <500ms for 10MB file |
| Key exchange latency | <200ms initial handshake |
| Storage overhead | <15% increase over plaintext |
| Battery impact | <3% additional drain |
| Prekey bundle size | <2KB per device |
| Concurrent sessions | Up to 5 devices per user |
| Key rotation | Ratchet advances every message |
| Prekey replenishment | Auto when < 20 remaining |
| Compliance | NIST SP 800-56A, SP 800-38D, FIPS 140-2 |

---

## 3. Threat Model

### Adversaries

| Adversary | Capability | Mitigation |
|-----------|-----------|------------|
| **Passive network attacker** | Intercept network traffic | TLS 1.3 (transport) + E2EE (content) |
| **Compromised server** | Read Firestore/Storage data | All content encrypted client-side; server sees only ciphertext |
| **Malicious admin** | Access Firebase console, read DB | No plaintext stored; private keys never leave client |
| **Stolen device (locked)** | Physical access, cannot unlock | Keys stored in platform keychain (iOS Keychain / Android Keystore) |
| **Stolen device (unlocked)** | Full device access | Key material in secure enclave; optional app-level lock via `local_auth` |
| **Compromised session key** | Decrypt some messages | Forward secrecy via ratchet; past messages remain secure |
| **MITM on key exchange** | Substitute public keys | Safety number verification; signed prekeys with identity key |

### Security Properties

```
┌─────────────────────────────────────────────────────────┐
│                  SECURITY GUARANTEES                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Confidentiality ──── Only participants read content    │
│                                                         │
│  Integrity ────────── Tampering detected via AEAD tag   │
│                                                         │
│  Authentication ───── Identity keys verify sender       │
│                                                         │
│  Forward Secrecy ──── Past messages safe if key leaks   │
│                                                         │
│  Future Secrecy ───── Ratchet heals after compromise    │
│                                                         │
│  Deniability ──────── No cryptographic proof of sender  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Cryptographic Protocol Design

### 4.1 Algorithm Selection (NIST Compliant)

| Function | Algorithm | NIST Reference | Rationale |
|----------|-----------|----------------|-----------|
| Identity Key Pair | ECDH Curve25519 (X25519) | SP 800-186 (approved 2023) | Best-in-class for DH key agreement; used by Signal/WhatsApp |
| Signing (Identity) | Ed25519 (EdDSA) | FIPS 186-5 | Fast signature verification; identity key authentication |
| Symmetric Encryption | AES-256-GCM | SP 800-38D, FIPS 197 | AEAD providing confidentiality + integrity; hardware-accelerated |
| Key Derivation | HKDF-SHA-256 | SP 800-56C Rev 2 | Standard KDF for deriving encryption keys from DH shared secrets |
| Message Auth | HMAC-SHA-256 | FIPS 198-1 | Authentication of ratchet chain keys |
| Key Backup KDF | PBKDF2-SHA-256 | SP 800-132 | Passphrase-based key derivation for backup encryption |
| Random Generation | Platform CSPRNG | SP 800-90A | iOS `SecRandomCopyBytes` / Android `SecureRandom` |

### 4.2 Key Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                       KEY HIERARCHY                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  LONG-TERM (per device, persisted in secure storage)            │
│  ├── Identity Key Pair (IK)                                     │
│  │   ├── IK_private  →  iOS Keychain / Android Keystore         │
│  │   └── IK_public   →  Published to Firestore                  │
│  │                                                              │
│  MEDIUM-TERM (rotated weekly)                                   │
│  ├── Signed Pre-Key (SPK)                                      │
│  │   ├── SPK_private →  Secure local storage                   │
│  │   ├── SPK_public  →  Published to Firestore                  │
│  │   └── SPK_sig     →  Ed25519 signature by IK                │
│  │                                                              │
│  SHORT-TERM (one-time use, deleted after consumption)           │
│  ├── One-Time Pre-Keys (OPK_1 ... OPK_N)                      │
│  │   ├── OPK_private →  Secure local storage                   │
│  │   └── OPK_public  →  Published to Firestore                  │
│  │                                                              │
│  EPHEMERAL (per session / per message)                          │
│  ├── Ephemeral Key Pair (EK) → Generated for X3DH              │
│  ├── Root Key (RK) → Derived from X3DH, advances with DH ratch │
│  ├── Chain Key (CK) → Derived from RK, advances per message    │
│  └── Message Key (MK) → Derived from CK, used once then deleted│
│                                                                  │
│  MEDIA-SPECIFIC (per file)                                      │
│  └── Media Encryption Key (MEK) → Random AES-256 key per file  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 X3DH Key Agreement (Initial Handshake)

The Extended Triple Diffie-Hellman (X3DH) protocol establishes a shared secret between two parties who may not be online simultaneously. This is critical for our Firebase-based architecture where users exchange messages asynchronously.

**Prekey Bundle (published per device to Firestore):**
```
PreKeyBundle {
  identityKey:     IK_pub        // Long-term identity
  signedPreKey:    SPK_pub       // Medium-term, signed  
  signedPreKeySig: Sign(IK, SPK) // Ed25519 signature
  oneTimePreKey:   OPK_pub       // Optional, one-time use
  registrationId:  uint32        // Device identifier
}
```

**X3DH Flow (Alice initiating chat with Bob):**

```
   Alice (Sender)                          Firestore                         Bob (Recipient)
       │                                      │                                    │
       │  1. Fetch Bob's PreKey Bundle        │                                    │
       │ ──────────────────────────────────►   │                                    │
       │  ◄────────────────────────────────── │                                    │
       │  {IK_B, SPK_B, SPK_sig_B, OPK_B}   │                                    │
       │                                      │                                    │
       │  2. Verify SPK_sig_B with IK_B      │                                    │
       │  3. Generate Ephemeral Key EK_A      │                                    │
       │                                      │                                    │
       │  4. Compute shared secret:           │                                    │
       │     DH1 = DH(IK_A,  SPK_B)         │                                    │
       │     DH2 = DH(EK_A,  IK_B)          │                                    │
       │     DH3 = DH(EK_A,  SPK_B)         │                                    │
       │     DH4 = DH(EK_A,  OPK_B)         │   (if OPK available)              │
       │                                      │                                    │
       │     SK = HKDF(DH1‖DH2‖DH3‖DH4)    │                                    │
       │                                      │                                    │
       │  5. Derive Root Key + Chain Keys     │                                    │
       │     from SK via HKDF                 │                                    │
       │                                      │                                    │
       │  6. Encrypt first message with MK    │                                    │
       │                                      │                                    │
       │  7. Send to Firestore:               │                                    │
       │     {IK_A, EK_A, OPK_id_used,       │                                    │
       │      ciphertext, header}             │ ──────────────────────────────────► │
       │                                      │                                    │
       │                                      │  8. Bob receives initial message    │
       │                                      │  9. Bob computes same SK using      │
       │                                      │     his private keys                │
       │                                      │ 10. Bob decrypts message            │
       │                                      │ 11. Bob deletes used OPK            │
       │                                      │                                    │
```

### 4.4 Double Ratchet Algorithm

After X3DH establishes the initial shared secret, the Double Ratchet provides **forward secrecy** and **future secrecy** through continuous key evolution.

**Ratchet Components:**

```
┌──────────────────────────────────────────────────────────┐
│                   DOUBLE RATCHET                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────┐                                    │
│  │  DH Ratchet     │  Advances when turns change         │
│  │  (Asymmetric)   │  New DH key pair per turn           │
│  │                 │  Provides future secrecy             │
│  └────────┬────────┘                                    │
│           │ derives                                      │
│           ▼                                              │
│  ┌─────────────────┐                                    │
│  │  Root Chain      │  Advances with each DH ratchet     │
│  │  RK_0 → RK_1 →..│  HKDF(RK, DH_output)             │
│  └────────┬────────┘                                    │
│           │ derives                                      │
│           ▼                                              │
│  ┌─────────────────┐                                    │
│  │ Sending/Recv     │  Advances with each message        │
│  │ Chain Keys       │  CK_n+1 = HMAC(CK_n, 0x02)       │
│  │ CK_0→CK_1→CK_2 │                                    │
│  └────────┬────────┘                                    │
│           │ derives                                      │
│           ▼                                              │
│  ┌─────────────────┐                                    │
│  │  Message Keys    │  One per message, used then deleted │
│  │  MK = HMAC(CK,  │  MK = HMAC(CK_n, 0x01)           │
│  │       0x01)      │  Never reused                      │
│  └─────────────────┘                                    │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Message Encryption:**

```
MK = HMAC-SHA256(CK_n, 0x01)            // Derive message key
CK_n+1 = HMAC-SHA256(CK_n, 0x02)        // Advance chain key
(enc_key, auth_key, iv) = HKDF(MK)       // Split into components

header = {
  dh_public: current_ratchet_public_key,
  prev_chain_length: N,
  message_number: n
}

ciphertext = AES-256-GCM(
  key: enc_key,
  iv: iv,
  plaintext: message_content,
  aad: header_bytes                       // Authenticate header
)

delete MK  // Message key deleted after use (forward secrecy)
```

### 4.5 Safety Number Verification

Safety numbers allow users to verify they are communicating with the intended person (no MITM attack on key exchange).

```
Safety Number = Truncated_Hash(
  SHA-256(IK_Alice_public ‖ Alice_userId) ‖
  SHA-256(IK_Bob_public   ‖ Bob_userId)
)

Display: 12 groups of 5 digits = 60-digit number
  34205 82317 19835 04912 44891 31732
  98412 04381 53298 41023 98274 10394

QR Code: Encodes (version ‖ IK_Alice ‖ IK_Bob)
```

---

## 5. Key Management Architecture

### 5.1 Client-Side Key Storage

```
┌─────────────────────────────────────────────────────────┐
│               CLIENT KEY STORAGE                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  iOS:                                                   │
│  ├── Identity Key    → Keychain (kSecAttrAccessible     │
│  │                      WhenUnlockedThisDeviceOnly)      │
│  ├── Session State   → Keychain (encrypted)             │
│  └── Ratchet State   → Keychain (encrypted)             │
│                                                         │
│  Android:                                               │
│  ├── Identity Key    → AndroidKeyStore (HW-backed)      │
│  │                      AES-256 wrapped                  │
│  ├── Session State   → EncryptedSharedPreferences       │
│  └── Ratchet State   → EncryptedSharedPreferences       │
│                                                         │
│  Flutter Abstraction:                                   │
│  └── flutter_secure_storage (wraps platform keystores)  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 5.2 Server-Side Key Infrastructure (Google Cloud)

```
┌─────────────────────────────────────────────────────────────────┐
│           GOOGLE CLOUD KEY MANAGEMENT ARCHITECTURE               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────┐                               │
│  │   Google Secret Manager      │                               │
│  │                              │                               │
│  │  Stores:                     │                               │
│  │  ├── FCM server key          │ (existing)                    │
│  │  ├── LiveKit API key/secret  │ (existing)                    │
│  │  ├── Prekey signing cert     │ (new) Server attestation      │
│  │  └── Key backup master key   │ (new) Wraps user backup keys  │
│  │                              │                               │
│  │  Access: Cloud Functions     │                               │
│  │  service account only        │                               │
│  └─────────────┬────────────────┘                               │
│                │                                                 │
│  ┌─────────────▼────────────────┐                               │
│  │   Google Cloud KMS           │                               │
│  │                              │                               │
│  │  Key Ring: "e2ee-chat"       │                               │
│  │  ├── prekey-attestation-key  │ Signs server-attested prekeys │
│  │  │   (Asymmetric Sign,       │                               │
│  │  │    EC P-256-SHA256)       │                               │
│  │  │                           │                               │
│  │  ├── backup-wrapping-key     │ Wraps user backup keys         │
│  │  │   (Symmetric Encrypt,     │                               │
│  │  │    AES-256-GCM)           │                               │
│  │  │                           │                               │
│  │  └── audit-log-signing-key   │ Signs key transparency logs    │
│  │      (Asymmetric Sign,       │                               │
│  │       EC P-256-SHA256)       │                               │
│  │                              │                               │
│  │  Rotation: Automatic,        │                               │
│  │  90-day period               │                               │
│  │                              │                               │
│  │  IAM: Least-privilege,       │                               │
│  │  Cloud Functions SA only     │                               │
│  └──────────────────────────────┘                               │
│                                                                  │
│  ┌──────────────────────────────┐                               │
│  │   Cloud Audit Logging        │                               │
│  │                              │                               │
│  │  ├── All KMS operations      │                               │
│  │  │   logged to Cloud Logging │                               │
│  │  ├── Access anomaly alerts   │                               │
│  │  └── Compliance reporting    │                               │
│  └──────────────────────────────┘                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.3 Key Lifecycle

| Key Type | Generation | Storage | Rotation | Deletion |
|----------|-----------|---------|----------|----------|
| Identity Key (IK) | Device first launch | Platform keychain | Never (per device) | Device deauthorization |
| Signed Pre-Key (SPK) | Registration + weekly | Platform keychain | Every 7 days | After rotation + 30-day grace |
| One-Time Pre-Key (OPK) | Batch of 100 | Platform keychain | On consumption | After use by recipient |
| Ephemeral Key (EK) | Per X3DH session | Memory only | Single use | Immediately after DH |
| Root Key (RK) | From X3DH output | Encrypted local DB | Each DH ratchet step | Session end |
| Chain Key (CK) | From root key | Encrypted local DB | Each message | After deriving next CK |
| Message Key (MK) | From chain key | Memory only | Single use | After encrypt/decrypt |
| Media Key (MEK) | Per media file | Memory only → in message | Single use | After upload complete |
| Backup Key | From user passphrase | Google Cloud KMS (wrapped) | User-initiated | User deletes backup |

### 5.4 Google Cloud KMS Integration Detail

```typescript
// Cloud Function: Key backup wrapping service
import { KeyManagementServiceClient } from '@google-cloud/kms';

const kmsClient = new KeyManagementServiceClient();
const KEY_RING = 'projects/PROJECT_ID/locations/global/keyRings/e2ee-chat';

// Wrap user's backup key with KMS (server never sees plaintext identity key)
async function wrapBackupKey(userEncryptedBackup: Buffer): Promise<Buffer> {
  const keyName = `${KEY_RING}/cryptoKeys/backup-wrapping-key`;
  
  const [result] = await kmsClient.encrypt({
    name: keyName,
    plaintext: userEncryptedBackup,  // Already encrypted with user passphrase
    additionalAuthenticatedData: Buffer.from('e2ee-backup-v1'),
  });
  
  return Buffer.from(result.ciphertext as string, 'base64');
}

// Attest prekey bundle authenticity
async function signPrekeyBundle(bundleHash: Buffer): Promise<Buffer> {
  const keyName = `${KEY_RING}/cryptoKeys/prekey-attestation-key/cryptoKeyVersions/1`;
  
  const [result] = await kmsClient.asymmetricSign({
    name: keyName,
    data: bundleHash,
  });
  
  return Buffer.from(result.signature as string, 'base64');
}
```

```typescript
// Cloud Function: Secret Manager integration for service credentials
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

const secretClient = new SecretManagerServiceClient();

async function getSecret(secretName: string): Promise<string> {
  const name = `projects/PROJECT_ID/secrets/${secretName}/versions/latest`;
  const [version] = await secretClient.accessSecretVersion({ name });
  return version.payload?.data?.toString() || '';
}
```

---

## 6. Data Models

### 6.1 Firestore Collections

```
Firestore Root
├── users/{userId}
│   └── devices/{deviceId}              ← NEW: Per-device key material
│       ├── identityKey: string         // Public identity key (Base64)
│       ├── signedPreKey: map           // Current signed prekey
│       │   ├── keyId: number
│       │   ├── publicKey: string       // Base64
│       │   └── signature: string       // Ed25519 sig by IK (Base64)
│       ├── oneTimePreKeys: array       // Available OPKs
│       │   └── [{ keyId, publicKey }]
│       ├── registrationId: number      // Unique device ID
│       ├── deviceName: string          // "iPhone 15", "Pixel 8"
│       ├── lastActive: timestamp
│       └── createdAt: timestamp
│
├── chat_rooms/{roomId}
│   ├── (existing fields)
│   ├── encryption_version: number      ← NEW: protocol version (all rooms E2EE)
│   └── messages/{messageId}
│       ├── sender_id: string
│       ├── type: string
│       ├── timestamp: timestamp
│       ├── (REMOVED: text, media_url in plaintext)
│       ├── ciphertext: string          ← NEW: Base64 encrypted payload
│       ├── header: map                 ← NEW: Ratchet header (unencrypted)
│       │   ├── dh: string             // Current ratchet public key
│       │   ├── pn: number             // Previous chain length
│       │   └── n: number              // Message number in chain
│       ├── initial_message: map        ← NEW: Only on first message
│       │   ├── identity_key: string   // Sender's IK_pub
│       │   ├── ephemeral_key: string  // EK_pub used in X3DH
│       │   └── opk_id: number         // Which OPK was consumed
│       └── target_devices: array       ← NEW: Per-device ciphertexts
│           └── [{ deviceId, ciphertext, header }]
│
├── key_backup/{userId}                  ← NEW: Encrypted key backups
│   ├── encrypted_backup: blob          // AES-256-GCM encrypted
│   ├── kms_wrapped_key: blob           // KMS-wrapped backup key
│   ├── salt: string                    // PBKDF2 salt (Base64)
│   ├── iterations: number              // PBKDF2 iterations (600,000)
│   ├── version: number
│   └── updated_at: timestamp
│
└── key_transparency_log/{logId}         ← NEW: Audit trail
    ├── user_id: string
    ├── device_id: string
    ├── action: string                   // "register", "rotate", "revoke"
    ├── identity_key_hash: string        // SHA-256 of public IK
    ├── server_signature: string         // KMS-signed attestation
    └── timestamp: timestamp
```

### 6.2 Dart Models

```dart
/// Identity key pair for a device
class IdentityKeyPair {
  final Uint8List publicKey;    // 32 bytes (X25519)
  final Uint8List privateKey;   // 32 bytes (X25519)
  final Uint8List signingKey;   // 32 bytes (Ed25519 public)
  final Uint8List signingPrivateKey; // 64 bytes (Ed25519 private)
  
  String get publicKeyBase64 => base64Encode(publicKey);
}

/// Signed pre-key with Ed25519 signature
class SignedPreKey {
  final int keyId;
  final Uint8List publicKey;
  final Uint8List privateKey;
  final Uint8List signature;   // Ed25519(IK_priv, SPK_pub)
  final DateTime createdAt;
  
  bool get isExpired => DateTime.now().difference(createdAt).inDays > 7;
}

/// One-time pre-key (consumed on first message)
class OneTimePreKey {
  final int keyId;
  final Uint8List publicKey;
  final Uint8List privateKey;
}

/// Pre-key bundle published to Firestore for async key exchange
class PreKeyBundle {
  final String userId;
  final String deviceId;
  final int registrationId;
  final Uint8List identityKey;
  final SignedPreKey signedPreKey;
  final OneTimePreKey? oneTimePreKey; // May be exhausted

  Map<String, dynamic> toFirestore() => {
    'identity_key': base64Encode(identityKey),
    'signed_pre_key': {
      'key_id': signedPreKey.keyId,
      'public_key': base64Encode(signedPreKey.publicKey),
      'signature': base64Encode(signedPreKey.signature),
    },
    'one_time_pre_keys': oneTimePreKey != null
        ? [{'key_id': oneTimePreKey!.keyId, 'public_key': base64Encode(oneTimePreKey!.publicKey)}]
        : [],
    'registration_id': registrationId,
    'device_name': deviceName,
    'last_active': FieldValue.serverTimestamp(),
  };
}

/// Encrypted message envelope stored in Firestore
class EncryptedMessage {
  final String id;
  final String senderId;
  final MessageType type;
  final DateTime timestamp;
  final String ciphertext;          // Base64 AES-256-GCM ciphertext
  final RatchetHeader header;
  final InitialMessageHeader? initialHeader; // Only for first message
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toFirestore() => {
    'sender_id': senderId,
    'type': type.name,
    'timestamp': FieldValue.serverTimestamp(),
    'ciphertext': ciphertext,
    'header': header.toMap(),
    if (initialHeader != null) 'initial_message': initialHeader!.toMap(),
  };
}

/// Ratchet header sent with every message (unencrypted, authenticated via AEAD AAD)
class RatchetHeader {
  final Uint8List dhPublicKey;    // Current ratchet public key
  final int previousChainLength; // Messages in previous sending chain
  final int messageNumber;       // Message number in current chain

  Map<String, dynamic> toMap() => {
    'dh': base64Encode(dhPublicKey),
    'pn': previousChainLength,
    'n': messageNumber,
  };
}

/// Header for the initial X3DH message
class InitialMessageHeader {
  final Uint8List identityKey;   // Sender's IK_pub
  final Uint8List ephemeralKey;  // EK_pub used in X3DH
  final int? oneTimePreKeyId;    // Which OPK was consumed

  Map<String, dynamic> toMap() => {
    'identity_key': base64Encode(identityKey),
    'ephemeral_key': base64Encode(ephemeralKey),
    if (oneTimePreKeyId != null) 'opk_id': oneTimePreKeyId,
  };
}

/// Decrypted message content (never stored, only in memory)
class DecryptedContent {
  final String? text;
  final String? mediaUrl;       // Encrypted media URL in storage
  final Uint8List? mediaKey;    // AES key to decrypt the media file
  final Uint8List? mediaHash;   // SHA-256 of plaintext for integrity
  final String? mediaType;      // MIME type
  final int? mediaSize;         // Original file size
  final String? thumbnailUrl;   // Encrypted thumbnail URL
  final Uint8List? thumbnailKey;
  
  Map<String, dynamic> toJson() => {
    if (text != null) 'text': text,
    if (mediaUrl != null) 'media_url': mediaUrl,
    if (mediaKey != null) 'media_key': base64Encode(mediaKey!),
    if (mediaHash != null) 'media_hash': base64Encode(mediaHash!),
    if (mediaType != null) 'media_type': mediaType,
    if (mediaSize != null) 'media_size': mediaSize,
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    if (thumbnailKey != null) 'thumbnail_key': base64Encode(thumbnailKey!),
  };
}

/// Session state persisted locally (encrypted via platform keystore)
class SessionState {
  final Uint8List rootKey;
  final ChainState sendingChain;
  final ChainState receivingChain;
  final Uint8List localRatchetKeyPair;  // Current DH ratchet key
  final Uint8List remoteRatchetKey;     // Peer's current DH key
  final int previousCounter;
  final List<SkippedMessageKey> skippedKeys; // For out-of-order messages
}

/// Chain state for sending or receiving
class ChainState {
  final Uint8List chainKey;
  final int counter;
}
```

### 6.3 Cloud Function Models

```typescript
// Firestore document: users/{userId}/devices/{deviceId}
interface DeviceRecord {
  identityKey: string;         // Base64 public key
  signedPreKey: {
    keyId: number;
    publicKey: string;         // Base64
    signature: string;         // Base64 Ed25519 sig
  };
  oneTimePreKeys: Array<{
    keyId: number;
    publicKey: string;         // Base64
  }>;
  registrationId: number;
  deviceName: string;
  lastActive: Timestamp;
  createdAt: Timestamp;
}

// Encrypted message document
interface EncryptedMessageDoc {
  sender_id: string;
  type: string;
  timestamp: Timestamp;
  ciphertext: string;          // Base64
  header: {
    dh: string;               // Base64 ratchet public key
    pn: number;
    n: number;
  };
  initial_message?: {
    identity_key: string;
    ephemeral_key: string;
    opk_id?: number;
  };
}

// Key backup document
interface KeyBackupDoc {
  encrypted_backup: Buffer;    // Client-encrypted + KMS-wrapped
  kms_wrapped_key: Buffer;
  salt: string;
  iterations: number;
  version: number;
  updated_at: Timestamp;
}

// Key transparency log entry
interface KeyTransparencyLog {
  user_id: string;
  device_id: string;
  action: 'register' | 'rotate_spk' | 'revoke_device' | 'identity_change';
  identity_key_hash: string;   // SHA-256(IK_pub)
  server_signature: string;    // KMS asymmetric signature
  timestamp: Timestamp;
}
```

---

## 7. Architecture

### 7.1 High-Level Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│                          CLIENT (Flutter)                             │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────────┐    │
│  │ Chat UI      │  │ Key Verif.   │  │ Device Manager           │    │
│  │ (existing)   │  │ Screen       │  │ Screen                   │    │
│  └──────┬───────┘  └──────┬───────┘  └───────────┬──────────────┘    │
│         │                 │                       │                    │
│  ┌──────▼─────────────────▼───────────────────────▼──────────────┐   │
│  │                  E2EE Service Layer                            │   │
│  │                                                               │   │
│  │  ┌─────────────┐ ┌──────────────┐ ┌────────────────────┐    │   │
│  │  │ Signal      │ │ Key Store    │ │ Media Encryption   │    │   │
│  │  │ Protocol    │ │ Service      │ │ Service            │    │   │
│  │  │ Engine      │ │              │ │                    │    │   │
│  │  │             │ │ ┌──────────┐ │ │ ┌────────────────┐│    │   │
│  │  │ • X3DH      │ │ │ iOS      │ │ │ │ AES-256-GCM   ││    │   │
│  │  │ • Ratchet   │ │ │ Keychain │ │ │ │ per-file      ││    │   │
│  │  │ • Encrypt   │ │ ├──────────┤ │ │ │ encryption    ││    │   │
│  │  │ • Decrypt   │ │ │ Android  │ │ │ └────────────────┘│    │   │
│  │  │             │ │ │ Keystore │ │ │                    │    │   │
│  │  └─────┬───────┘ │ └──────────┘ │ └─────────┬──────────┘    │   │
│  │        │         └──────┬───────┘           │               │   │
│  └────────┼────────────────┼───────────────────┼───────────────┘   │
│           │                │                   │                    │
├───────────┼────────────────┼───────────────────┼────────────────────┤
│           ▼                ▼                   ▼                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐     │
│  │ Firestore    │  │ Firestore    │  │ Firebase Storage     │     │
│  │ messages/    │  │ devices/     │  │ encrypted_media/     │     │
│  │ (ciphertext) │  │ (pub keys)  │  │ (encrypted blobs)    │     │
│  └──────┬───────┘  └──────┬───────┘  └───────────┬──────────┘     │
│         │                 │                       │                 │
└─────────┼─────────────────┼───────────────────────┼─────────────────┘
          │                 │                       │
          ▼                 ▼                       ▼
┌───────────────────────────────────────────────────────────────────────┐
│                     GOOGLE CLOUD PLATFORM                             │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐ │
│  │ Cloud Functions   │  │ Cloud KMS        │  │ Secret Manager     │ │
│  │                   │  │                  │  │                    │ │
│  │ • Prekey mgmt     │  │ • Backup key     │  │ • Service creds    │ │
│  │ • OPK replenish   │  │   wrapping       │  │ • Attestation      │ │
│  │   monitoring      │  │ • Prekey         │  │   cert             │ │
│  │ • Key backup      │  │   attestation    │  │                    │ │
│  │   wrapping        │  │ • Audit log      │  │                    │ │
│  │ • Transparency    │  │   signing        │  │                    │ │
│  │   logging         │  │ • Auto-rotation  │  │                    │ │
│  │ • Notification    │  │                  │  │                    │ │
│  │   (no plaintext)  │  │                  │  │                    │ │
│  └──────────────────┘  └──────────────────┘  └────────────────────┘ │
│                                                                       │
│  ┌──────────────────┐                                                │
│  │ Cloud Audit Logs  │  All KMS + Secret Manager access audited      │
│  └──────────────────┘                                                │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

### 7.2 Message Flow (Send)

```
┌──────────────────────────────────────────────────────────────┐
│                    SEND MESSAGE FLOW                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User types message                                       │
│     │                                                        │
│  2. PII + Profanity check (existing, on plaintext)          │
│     │                                                        │
│  3. Check session exists for recipient                       │
│     ├── YES → Skip to step 5                                │
│     └── NO  → Step 4: X3DH handshake                        │
│                                                              │
│  4. X3DH Key Exchange:                                       │
│     a. Fetch recipient's PreKeyBundle from Firestore         │
│     b. Verify signed prekey signature                        │
│     c. Generate ephemeral key pair                           │
│     d. Compute shared secret (4x DH)                        │
│     e. Derive initial Root Key + Chain Keys                  │
│     f. Store session state locally (encrypted)               │
│     │                                                        │
│  5. Double Ratchet Encrypt:                                  │
│     a. Derive Message Key from sending Chain Key             │
│     b. Advance Chain Key                                     │
│     c. Construct AEAD plaintext:                             │
│        {text, media_key?, media_url?, ...}                   │
│     d. Encrypt with AES-256-GCM:                            │
│        ciphertext = AES-GCM(MK, plaintext, AAD=header)      │
│     e. Delete Message Key from memory                        │
│     │                                                        │
│  6. Write to Firestore:                                      │
│     {sender_id, type, ciphertext, header, timestamp}         │
│     │                                                        │
│  7. Cloud Function triggers:                                 │
│     • Send push notification (sender name only, no content)  │
│     • Update unread counts                                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 7.3 Message Flow (Receive)

```
┌──────────────────────────────────────────────────────────────┐
│                  RECEIVE MESSAGE FLOW                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Firestore snapshot listener receives new document        │
│     │                                                        │
│  2. Parse EncryptedMessage from Firestore document           │
│     │                                                        │
│  3. Check if initial_message header present                  │
│     ├── YES → X3DH response:                                │
│     │   a. Use own IK + SPK + OPK private keys              │
│     │   b. Compute same shared secret as sender              │
│     │   c. Initialize session with Root Key + Chain Keys     │
│     │   d. Delete consumed OPK locally + in Firestore       │
│     │   e. Trigger OPK replenishment if below threshold      │
│     └── NO  → Use existing session                          │
│     │                                                        │
│  4. Double Ratchet Decrypt:                                  │
│     a. Check header.dh against current remote ratchet key    │
│     b. If new DH key → perform DH ratchet step              │
│     c. Derive Message Key from receiving Chain Key           │
│     d. Decrypt: plaintext = AES-GCM-Open(MK, ct, AAD=hdr)  │
│     e. Delete Message Key from memory                        │
│     │                                                        │
│  5. Parse DecryptedContent from plaintext                    │
│     │                                                        │
│  6. If media → download encrypted file → decrypt with        │
│     media_key from DecryptedContent                          │
│     │                                                        │
│  7. Display message in UI                                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 8. Service Layer

### 8.1 New Flutter Services

```
lib/
├── core/
│   └── crypto/                              ← NEW MODULE
│       ├── signal_protocol_engine.dart      // X3DH + Double Ratchet
│       ├── aes_gcm_cipher.dart              // AES-256-GCM encrypt/decrypt
│       ├── key_derivation.dart              // HKDF-SHA256, HMAC-SHA256
│       ├── x25519.dart                      // X25519 DH key agreement
│       ├── ed25519.dart                     // Ed25519 signing/verification
│       ├── secure_random.dart               // Platform CSPRNG wrapper
│       └── safety_number.dart               // Safety number generation
│
├── data/
│   ├── models/
│   │   ├── identity_key_pair.dart           ← NEW
│   │   ├── pre_key_bundle.dart              ← NEW
│   │   ├── encrypted_message.dart           ← NEW
│   │   ├── ratchet_header.dart              ← NEW
│   │   ├── session_state.dart               ← NEW
│   │   └── decrypted_content.dart           ← NEW
│   │
│   └── repositories/
│       └── crypto/                          ← NEW
│           ├── key_store_repository.dart    // Local key persistence
│           ├── prekey_repository.dart       // Firestore prekey CRUD
│           ├── session_repository.dart      // Local session persistence
│           └── key_backup_repository.dart   // Cloud key backup
│
├── features/
│   └── chat/
│       ├── services/
│       │   ├── encryption_service.dart      ← NEW: Orchestrates E2EE
│       │   ├── media_encryption_service.dart ← NEW: File encrypt/decrypt
│       │   └── key_verification_service.dart ← NEW: Safety numbers
│       │
│       └── pages/
│           ├── safety_number_page.dart      ← NEW
│           └── device_management_page.dart  ← NEW
│
└── providers/
    └── crypto_providers.dart                ← NEW: DI for crypto services
```

### 8.2 EncryptionService (Core Orchestrator)

```dart
/// Orchestrates E2EE for chat messages.
/// 
/// Manages session lifecycle, encrypts outgoing messages,
/// and decrypts incoming messages using the Signal Protocol.
class EncryptionService {
  final SignalProtocolEngine _protocol;
  final KeyStoreRepository _keyStore;
  final PreKeyRepository _preKeyRepo;
  final SessionRepository _sessionRepo;
  
  /// Encrypt a message for a recipient.
  /// Handles session initialization (X3DH) if no session exists.
  Future<EncryptedMessage> encryptMessage({
    required String recipientId,
    required DecryptedContent content,
    required MessageType type,
  }) async {
    // 1. Get or create session
    var session = await _sessionRepo.getSession(recipientId);
    if (session == null) {
      session = await _initializeSession(recipientId);
    }
    
    // 2. Serialize content to JSON bytes
    final plaintext = utf8.encode(jsonEncode(content.toJson()));
    
    // 3. Ratchet encrypt
    final (ciphertext, header) = await _protocol.ratchetEncrypt(
      session: session,
      plaintext: Uint8List.fromList(plaintext),
    );
    
    // 4. Save updated session state
    await _sessionRepo.saveSession(recipientId, session);
    
    return EncryptedMessage(
      ciphertext: base64Encode(ciphertext),
      header: header,
      type: type,
    );
  }
  
  /// Decrypt an incoming encrypted message.
  Future<DecryptedContent> decryptMessage({
    required String senderId,
    required EncryptedMessage message,
  }) async {
    // 1. Get or initialize session from initial message header
    var session = await _sessionRepo.getSession(senderId);
    if (session == null && message.initialHeader != null) {
      session = await _processInitialMessage(senderId, message.initialHeader!);
    }
    
    if (session == null) {
      throw E2EEException('No session found for sender $senderId');
    }
    
    // 2. Ratchet decrypt
    final plaintext = await _protocol.ratchetDecrypt(
      session: session,
      ciphertext: base64Decode(message.ciphertext),
      header: message.header,
    );
    
    // 3. Save updated session state
    await _sessionRepo.saveSession(senderId, session);
    
    // 4. Parse content
    final json = jsonDecode(utf8.decode(plaintext));
    return DecryptedContent.fromJson(json);
  }
  
  /// Initialize X3DH session with recipient
  Future<SessionState> _initializeSession(String recipientId) async {
    // Fetch all recipient devices and create session for each
    final bundle = await _preKeyRepo.fetchPreKeyBundle(recipientId);
    
    // Verify signed prekey
    final isValid = _protocol.verifySignedPreKey(
      identityKey: bundle.identityKey,
      signedPreKey: bundle.signedPreKey,
    );
    if (!isValid) throw E2EEException('Invalid signed prekey signature');
    
    // Perform X3DH
    final myIdentity = await _keyStore.getIdentityKeyPair();
    return _protocol.x3dhInitiate(
      myIdentity: myIdentity,
      theirBundle: bundle,
    );
  }
}
```

### 8.3 MediaEncryptionService

```dart
/// Handles encryption/decryption of media files (images, video, audio, docs).
/// Each file gets a unique AES-256-GCM key.
class MediaEncryptionService {
  final AesGcmCipher _cipher;
  final SecureRandom _random;
  
  /// Encrypt a media file before upload.
  /// Returns the encrypted bytes and the key needed to decrypt.
  Future<MediaEncryptionResult> encryptMedia(Uint8List plainFile) async {
    // 1. Generate random 256-bit key and 96-bit IV
    final key = _random.generateBytes(32);  // AES-256
    final iv = _random.generateBytes(12);   // GCM standard IV
    
    // 2. Compute plaintext hash for integrity verification
    final plaintextHash = sha256.convert(plainFile).bytes;
    
    // 3. Encrypt with AES-256-GCM
    final cipherFile = await _cipher.encrypt(
      key: key,
      iv: iv,
      plaintext: plainFile,
      aad: Uint8List.fromList(plaintextHash), // Bind hash to ciphertext
    );
    
    return MediaEncryptionResult(
      encryptedFile: cipherFile,
      mediaKey: Uint8List.fromList([...key, ...iv]), // 44 bytes: key + IV
      plaintextHash: Uint8List.fromList(plaintextHash),
    );
  }
  
  /// Decrypt a downloaded encrypted media file.
  Future<Uint8List> decryptMedia({
    required Uint8List encryptedFile,
    required Uint8List mediaKey,      // 44 bytes from message
    required Uint8List expectedHash,  // SHA-256 of original
  }) async {
    final key = mediaKey.sublist(0, 32);
    final iv = mediaKey.sublist(32, 44);
    
    final plainFile = await _cipher.decrypt(
      key: key,
      iv: iv,
      ciphertext: encryptedFile,
      aad: expectedHash,
    );
    
    // Verify integrity
    final actualHash = sha256.convert(plainFile).bytes;
    if (!listEquals(actualHash, expectedHash)) {
      throw E2EEException('Media integrity check failed');
    }
    
    return plainFile;
  }
}
```

### 8.4 KeyStoreService (Platform Keychain Integration)

```dart
/// Manages cryptographic key storage using platform-native secure storage.
/// 
/// iOS: Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
/// Android: AndroidKeyStore (hardware-backed when available)
class KeyStoreRepository {
  final FlutterSecureStorage _secureStorage;
  
  static const _identityKeyTag = 'e2ee.identity_key';
  static const _signedPreKeyTag = 'e2ee.signed_pre_key';
  static const _sessionPrefix = 'e2ee.session.';
  static const _oneTimePreKeyPrefix = 'e2ee.opk.';
  
  KeyStoreRepository()
      : _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
            keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
            storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.unlocked_this_device,
            synchronizable: false, // Never sync to iCloud
          ),
        );
  
  /// Generate and persist a new identity key pair.
  /// Called once per device during E2EE registration.
  Future<IdentityKeyPair> generateIdentityKeyPair() async {
    final keyPair = await X25519.generateKeyPair();
    final signingPair = await Ed25519.generateKeyPair();
    
    await _secureStorage.write(
      key: _identityKeyTag,
      value: base64Encode([
        ...keyPair.privateKey,
        ...keyPair.publicKey,
        ...signingPair.privateKey,
        ...signingPair.publicKey,
      ]),
    );
    
    return IdentityKeyPair(
      publicKey: keyPair.publicKey,
      privateKey: keyPair.privateKey,
      signingKey: signingPair.publicKey,
      signingPrivateKey: signingPair.privateKey,
    );
  }
  
  /// Retrieve stored identity key pair
  Future<IdentityKeyPair?> getIdentityKeyPair() async {
    final encoded = await _secureStorage.read(key: _identityKeyTag);
    if (encoded == null) return null;
    final bytes = base64Decode(encoded);
    return IdentityKeyPair(
      privateKey: Uint8List.fromList(bytes.sublist(0, 32)),
      publicKey: Uint8List.fromList(bytes.sublist(32, 64)),
      signingPrivateKey: Uint8List.fromList(bytes.sublist(64, 128)),
      signingKey: Uint8List.fromList(bytes.sublist(128, 160)),
    );
  }
  
  /// Save session state for a peer, encrypted at rest by platform keystore
  Future<void> saveSession(String peerId, SessionState session) async {
    final data = session.serialize(); // Protobuf or JSON serialization
    await _secureStorage.write(
      key: '$_sessionPrefix$peerId',
      value: base64Encode(data),
    );
  }
}
```

### 8.5 Integration with Existing Chat Services

```dart
/// Modified ChatMessageRepository.sendMessage to support E2EE
/// 
/// BEFORE (plaintext):
///   await _messagesRef.add({'text': text, 'media_url': url, ...});
///
/// AFTER (encrypted):
///   final encrypted = await _encryptionService.encryptMessage(...);
///   await _messagesRef.add(encrypted.toFirestore());

class ChatMessageRepository implements IChatMessageRepository {
  final EncryptionService _encryptionService; // NEW dependency
  
  @override
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required MessageType type,
    String? text,
    String? mediaUrl,
    Uint8List? mediaKey,    // NEW: for encrypted media
    Uint8List? mediaHash,   // NEW: integrity hash
    // ...existing params
  }) async {
    final recipientId = _getRecipientId(roomId, senderId);
    
    // Build plaintext content (never stored server-side)
    final content = DecryptedContent(
      text: text,
      mediaUrl: mediaUrl,
      mediaKey: mediaKey,
      mediaHash: mediaHash,
      mediaType: type.name,
    );
    
    // Encrypt using Signal Protocol
    final encrypted = await _encryptionService.encryptMessage(
      recipientId: recipientId,
      content: content,
      type: type,
    );
    
    // Store only ciphertext in Firestore
    await _messagesRef(roomId).add(encrypted.toFirestore());
    
    // Update room last message (show "Encrypted message" placeholder)
    await _roomsRef.doc(roomId).update({
      'last_message': '🔒 Encrypted message',
      'last_message_time': FieldValue.serverTimestamp(),
    });
  }
}
```

---

## 9. Cloud Functions

### 9.1 Prekey Management Functions

```typescript
// functions/src/e2ee/prekeyManagement.ts

import * as functions from 'firebase-functions/v2';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { KeyManagementServiceClient } from '@google-cloud/kms';

const db = getFirestore();
const kmsClient = new KeyManagementServiceClient();

const KMS_KEY_RING = `projects/${process.env.GCP_PROJECT}/locations/global/keyRings/e2ee-chat`;
const ATTESTATION_KEY = `${KMS_KEY_RING}/cryptoKeys/prekey-attestation-key/cryptoKeyVersions/1`;

/**
 * Monitor one-time prekey supply and alert/trigger replenishment.
 * Runs when a message is created (OPK may have been consumed).
 */
export const monitorPrekeySupply = functions.firestore
  .onDocumentCreated('chat_rooms/{roomId}/messages/{messageId}', async (event) => {
    const data = event.data?.data();
    if (!data?.initial_message?.opk_id) return; // No OPK consumed
    
    // Determine which user's OPK was consumed
    const roomId = event.params.roomId;
    const senderId = data.sender_id;
    const [user1, user2] = roomId.split('_');
    const recipientId = senderId === user1 ? user2 : user1;
    
    // Check remaining OPK count across all devices
    const devicesSnap = await db
      .collection(`users/${recipientId}/devices`)
      .get();
    
    for (const deviceDoc of devicesSnap.docs) {
      const device = deviceDoc.data();
      const remainingOPKs = device.oneTimePreKeys?.length ?? 0;
      
      if (remainingOPKs < 20) {
        // Send FCM to recipient's device requesting OPK replenishment
        // (Client generates new OPKs, not the server — server never has private keys)
        await sendOPKReplenishmentNotification(recipientId, deviceDoc.id, remainingOPKs);
      }
    }
  });

/**
 * Attest a prekey bundle's authenticity with KMS signature.
 * Called when a client registers or rotates keys.
 */
export const attestPrekeyBundle = functions.https
  .onCall(async (request) => {
    const { deviceId, bundleHash } = request.data;
    const userId = request.auth?.uid;
    if (!userId) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    
    // Verify the device belongs to the requesting user
    const deviceRef = db.doc(`users/${userId}/devices/${deviceId}`);
    const deviceSnap = await deviceRef.get();
    if (!deviceSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Device not registered');
    }
    
    // Sign bundle hash with KMS
    const hashBuffer = Buffer.from(bundleHash, 'base64');
    const digest = { sha256: hashBuffer };
    
    const [signResult] = await kmsClient.asymmetricSign({
      name: ATTESTATION_KEY,
      digest,
    });
    
    const signature = Buffer.from(signResult.signature as Uint8Array).toString('base64');
    
    // Log to key transparency
    await db.collection('key_transparency_log').add({
      user_id: userId,
      device_id: deviceId,
      action: 'attest_bundle',
      identity_key_hash: bundleHash,
      server_signature: signature,
      timestamp: FieldValue.serverTimestamp(),
    });
    
    return { signature };
  });

/**
 * Register a new device's identity key and prekey bundle.
 */
export const registerDevice = functions.https
  .onCall(async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    
    const { deviceId, identityKey, signedPreKey, oneTimePreKeys, registrationId, deviceName } = request.data;
    
    // Enforce max 5 devices per user
    const existingDevices = await db
      .collection(`users/${userId}/devices`)
      .count()
      .get();
    
    if (existingDevices.data().count >= 5) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Maximum 5 devices per account'
      );
    }
    
    // Store device record
    await db.doc(`users/${userId}/devices/${deviceId}`).set({
      identityKey,
      signedPreKey,
      oneTimePreKeys,
      registrationId,
      deviceName,
      lastActive: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    });
    
    // Log identity key registration for transparency
    const crypto = await import('crypto');
    const ikHash = crypto.createHash('sha256')
      .update(Buffer.from(identityKey, 'base64'))
      .digest('base64');
    
    await db.collection('key_transparency_log').add({
      user_id: userId,
      device_id: deviceId,
      action: 'register',
      identity_key_hash: ikHash,
      server_signature: '', // Signed asynchronously
      timestamp: FieldValue.serverTimestamp(),
    });
    
    return { success: true };
  });
```

### 9.2 Key Backup Functions

```typescript
// functions/src/e2ee/keyBackup.ts

import * as functions from 'firebase-functions/v2';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { KeyManagementServiceClient } from '@google-cloud/kms';

const db = getFirestore();
const kmsClient = new KeyManagementServiceClient();

const KMS_KEY_RING = `projects/${process.env.GCP_PROJECT}/locations/global/keyRings/e2ee-chat`;
const BACKUP_Key = `${KMS_KEY_RING}/cryptoKeys/backup-wrapping-key`;

/**
 * Store an encrypted key backup.
 * 
 * Flow:
 * 1. Client encrypts keys with passphrase-derived key (PBKDF2)
 * 2. Client sends already-encrypted blob to this function
 * 3. Server wraps the blob again with KMS (defense in depth)
 * 4. Server stores double-encrypted backup in Firestore
 * 
 * Server NEVER sees plaintext keys.
 */
export const storeKeyBackup = functions.https
  .onCall(async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    
    const { encryptedBackup, salt, iterations, version } = request.data;
    
    // Additional KMS wrapping (defense in depth)
    const clientEncryptedBuffer = Buffer.from(encryptedBackup, 'base64');
    
    const [wrapResult] = await kmsClient.encrypt({
      name: BACKUP_Key,
      plaintext: clientEncryptedBuffer,
      additionalAuthenticatedData: Buffer.from(`e2ee-backup-v${version}-${userId}`),
    });
    
    const kmsWrappedBackup = Buffer.from(wrapResult.ciphertext as Uint8Array).toString('base64');
    
    await db.doc(`key_backup/${userId}`).set({
      kms_wrapped_backup: kmsWrappedBackup,
      salt,
      iterations,
      version,
      updated_at: FieldValue.serverTimestamp(),
    });
    
    return { success: true };
  });

/**
 * Retrieve encrypted key backup.
 * 
 * Flow:
 * 1. Server unwraps KMS layer
 * 2. Returns client-encrypted blob (still encrypted with passphrase)
 * 3. Client decrypts with user's passphrase locally
 */
export const retrieveKeyBackup = functions.https
  .onCall(async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    
    const backupDoc = await db.doc(`key_backup/${userId}`).get();
    if (!backupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'No backup found');
    }
    
    const data = backupDoc.data()!;
    
    // Unwrap KMS layer
    const kmsWrappedBuffer = Buffer.from(data.kms_wrapped_backup, 'base64');
    
    const [unwrapResult] = await kmsClient.decrypt({
      name: BACKUP_Key,
      ciphertext: kmsWrappedBuffer,
      additionalAuthenticatedData: Buffer.from(`e2ee-backup-v${data.version}-${userId}`),
    });
    
    const clientEncryptedBackup = Buffer.from(unwrapResult.plaintext as Uint8Array).toString('base64');
    
    return {
      encryptedBackup: clientEncryptedBackup,
      salt: data.salt,
      iterations: data.iterations,
      version: data.version,
    };
  });
```

### 9.3 Modified Notification Function

```typescript
// Modification to existing onMessageCreated in functions/src/index.ts
// Push notifications MUST NOT contain plaintext message content

// BEFORE:
//   notification: {
//     title: senderName,
//     body: messageText,  // ← PLAINTEXT LEAKED to server
//   }

// AFTER:
async function handleNotification(
  messageData: EncryptedMessageDoc,
  roomId: string,
) {
  // Derive recipient
  const [user1, user2] = roomId.split('_');
  const recipientId = messageData.sender_id === user1 ? user2 : user1;
  
  // Get sender display name 
  const senderDoc = await db.doc(`users/${messageData.sender_id}`).get();
  const senderName = senderDoc.data()?.displayName ?? 'Someone';
  
  // Message type indicator (no content)
  const typeIndicators: Record<string, string> = {
    text: 'sent you a message',
    image: 'sent you a photo',
    video: 'sent you a video',
    audio: 'sent you a voice message',
    doc: 'sent you a document',
  };
  
  const body = typeIndicators[messageData.type] ?? 'sent you a message';
  
  // Send notification WITHOUT message content
  await sendFCMNotification(recipientId, {
    notification: {
      title: senderName,
      body: body,  // Generic indicator, no plaintext
    },
    data: {
      type: 'chat_message',
      roomId: roomId,
      senderId: messageData.sender_id,
      // NO ciphertext or content in push payload
    },
  });
}
```

---

## 10. Media & Document Encryption

### 10.1 Encrypted Media Upload Flow

```
┌───────────────────────────────────────────────────────────────┐
│               ENCRYPTED MEDIA UPLOAD FLOW                     │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  1. User selects media file (image/video/audio/doc)           │
│     │                                                         │
│  2. Generate random AES-256 key (MEK) + 96-bit IV            │
│     MEK = SecureRandom(32 bytes)                              │
│     IV  = SecureRandom(12 bytes)                              │
│     │                                                         │
│  3. Compute SHA-256 hash of plaintext file                    │
│     hash = SHA256(plaintext_bytes)                            │
│     │                                                         │
│  4. Generate encrypted thumbnail (if image/video)             │
│     thumbnail_key = SecureRandom(32 bytes) + IV               │
│     encrypted_thumb = AES-GCM(thumbnail_key, thumbnail)       │
│     │                                                         │
│  5. Encrypt file with AES-256-GCM                             │
│     ciphertext = AES-GCM(MEK, IV, plaintext, AAD=hash)       │
│     │                                                         │
│  6. Upload encrypted file to Firebase Storage                 │
│     Path: encrypted_media/{roomId}/{random_uuid}.enc          │
│     │                                                         │
│  7. Upload encrypted thumbnail (if applicable)                │
│     Path: encrypted_media/{roomId}/thumbs/{uuid}.enc          │
│     │                                                         │
│  8. Construct DecryptedContent with media metadata:           │
│     {                                                         │
│       mediaUrl: "encrypted_media/roomId/uuid.enc",            │
│       mediaKey: MEK ‖ IV (44 bytes, Base64),                  │
│       mediaHash: SHA256(plaintext),                           │
│       mediaType: "image/jpeg",                                │
│       mediaSize: 2048576,                                     │
│       thumbnailUrl: "encrypted_media/roomId/thumbs/uuid.enc", │
│       thumbnailKey: thumb_key ‖ IV (44 bytes, Base64)         │
│     }                                                         │
│     │                                                         │
│  9. Encrypt entire DecryptedContent as message via            │
│     Signal Protocol (Double Ratchet)                          │
│     │                                                         │
│ 10. Store encrypted message in Firestore                      │
│     (media URL + key are INSIDE the encrypted payload)        │
│                                                               │
│  RESULT: Server has encrypted blob + encrypted metadata       │
│          Cannot determine: file content, type, or name        │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### 10.2 Streaming Decryption for Large Files

For files >10MB, we use chunked encryption/decryption to avoid memory pressure:

```dart
/// Chunked AES-256-GCM encryption for large files.
/// Splits file into 64KB chunks, each independently authenticated.
class ChunkedMediaCipher {
  static const int chunkSize = 64 * 1024; // 64KB chunks
  
  /// Encrypt a large file in chunks.
  /// Format: [4-byte chunk count][chunk1][chunk2]...[chunkN]
  /// Each chunk: [4-byte length][ciphertext][16-byte GCM tag]
  Future<Uint8List> encryptChunked({
    required Uint8List key,
    required Stream<List<int>> fileStream,
  }) async {
    final chunks = <Uint8List>[];
    int chunkIndex = 0;
    
    await for (final block in fileStream) {
      // Derive per-chunk IV from base IV + chunk index (prevents IV reuse)
      final chunkIv = _deriveChunkIv(key, chunkIndex);
      
      final encrypted = await AesGcm.encrypt(
        key: key.sublist(0, 32),
        iv: chunkIv,
        plaintext: Uint8List.fromList(block),
        aad: _buildChunkAad(chunkIndex), // Bind chunk order
      );
      
      chunks.add(encrypted);
      chunkIndex++;
    }
    
    return _assembleChunks(chunks);
  }
}
```

### 10.3 Modified Storage Path

```
Firebase Storage (BEFORE):
  chat_attachments/{roomId}/{fileName}     ← Plaintext files, real names

Firebase Storage (AFTER):
  encrypted_media/{roomId}/{uuid}.enc      ← Encrypted blobs, random names
  encrypted_media/{roomId}/thumbs/{uuid}.enc ← Encrypted thumbnails
```

---

## 11. Device & Session Management

### 11.1 Device Registration Flow

```
┌──────────────────────────────────────────────────────────────┐
│                DEVICE REGISTRATION FLOW                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  NEW DEVICE / FIRST LAUNCH:                                  │
│                                                              │
│  1. Generate Identity Key Pair (X25519 + Ed25519)            │
│     └── Store private keys in platform keystore              │
│                                                              │
│  2. Generate Signed Pre-Key                                  │
│     └── Sign SPK_pub with Ed25519 identity key               │
│                                                              │
│  3. Generate 100 One-Time Pre-Keys                           │
│     └── Store private keys locally                           │
│                                                              │
│  4. Generate unique registrationId (uint32)                  │
│                                                              │
│  5. Call Cloud Function: registerDevice({                    │
│       deviceId, identityKey, signedPreKey,                   │
│       oneTimePreKeys, registrationId, deviceName             │
│     })                                                       │
│                                                              │
│  6. Cloud Function:                                          │
│     a. Verify max 5 devices                                  │
│     b. Store PreKeyBundle in Firestore                       │
│     c. Log in key transparency log                           │
│     d. Sign attestation via KMS                              │
│                                                              │
│  7. Client receives confirmation                             │
│     └── E2EE ready for this device                           │
│                                                              │
│  EXISTING USER, NEW DEVICE (RESTORE):                        │
│                                                              │
│  1. Generate new device Identity Key Pair                    │
│  2. Register device (steps above)                            │
│  3. Optionally restore key backup:                           │
│     a. Call retrieveKeyBackup Cloud Function                 │
│     b. Prompt user for backup passphrase                     │
│     c. Derive key via PBKDF2(passphrase, salt, 600000)      │
│     d. Decrypt backup → restore session states               │
│  4. Without restore: new sessions established on next message│
│     └── Contacts see "identity key changed" warning          │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 11.2 Device Management UI

```dart
/// Device management screen showing all registered devices for the user.
/// Allows revoking devices and viewing identity key fingerprints.
class DeviceManagementPage extends StatelessWidget {
  // Shows:
  // - List of registered devices (name, last active, identity key fingerprint)
  // - Current device highlighted
  // - "Revoke" button per non-current device
  // - "Verify" button to show full identity key
  // - Device count (e.g., "2 of 5 devices")
}
```

### 11.3 Identity Key Change Detection

```dart
/// When a contact's identity key changes, show a warning banner.
/// This protects against MITM attacks on key exchange.
class IdentityKeyChangeDetector {
  /// Compare stored identity key vs fetched bundle.
  /// If different, show warning and require re-verification.
  Future<IdentityKeyStatus> checkIdentityKey(String userId) async {
    final storedKey = await _keyStore.getStoredIdentityKey(userId);
    final currentBundle = await _preKeyRepo.fetchPreKeyBundle(userId);
    
    if (storedKey == null) {
      // First interaction — store and trust on first use (TOFU)
      await _keyStore.storeIdentityKey(userId, currentBundle.identityKey);
      return IdentityKeyStatus.trusted;
    }
    
    if (listEquals(storedKey, currentBundle.identityKey)) {
      return IdentityKeyStatus.verified;
    }
    
    // KEY CHANGED — potential MITM or device change
    return IdentityKeyStatus.changed;
  }
}
```

---

## 12. Web Client & Cross-Platform Support

### 12.1 Overview

The E2EE protocol is platform-agnostic — it operates on key pairs and mathematical operations, not specific runtimes. A mobile user (iOS/Android) and a web user (Chrome/Firefox/Safari) can exchange encrypted messages seamlessly, provided both platforms implement the same elliptic curve operations and symmetric ciphers.

This section specifies how the web client participates in the E2EE system and defines the platform crypto abstraction that ensures cross-platform interoperability.

### 12.2 Web Crypto Capability Matrix

| Primitive | Native Web Crypto API | WASM Polyfill (libsodium.js) | Approach |
|-----------|----------------------|-----------------------------|---------|
| **X25519 (ECDH)** | Chrome 113+ / Edge 113+ only; no Firefox/Safari | Full support | **WASM** (universal) |
| **Ed25519 (Signing)** | Chrome 113+ / Edge 113+ only | Full support | **WASM** (universal) |
| **AES-256-GCM** | All modern browsers | Available but unnecessary | **Web Crypto API** (hardware-accelerated) |
| **HKDF-SHA-256** | All modern browsers | Available but unnecessary | **Web Crypto API** |
| **HMAC-SHA-256** | All modern browsers | Available but unnecessary | **Web Crypto API** |
| **PBKDF2-SHA-256** | All modern browsers | Available but unnecessary | **Web Crypto API** |
| **CSPRNG** | `crypto.getRandomValues()` — all browsers | Not needed | **Web Crypto API** |

**Strategy:** Use `libsodium.js` WASM (~200KB gzipped) for X25519/Ed25519 (ensuring identical curves to mobile), and native Web Crypto API for everything else (AES-GCM, HKDF, HMAC) — maximizing hardware acceleration. This is the same approach used by Signal Desktop and WhatsApp Web.

### 12.3 Platform Crypto Abstraction Layer

A `CryptoProvider` interface ensures the protocol engine is platform-agnostic:

```dart
/// Platform-agnostic crypto interface.
/// Mobile and web each provide their own implementation.
abstract class CryptoProvider {
  /// X25519 key pair generation
  Future<KeyPair> generateX25519KeyPair();
  
  /// X25519 Diffie-Hellman key agreement
  Future<Uint8List> x25519Dh(Uint8List privateKey, Uint8List publicKey);
  
  /// Ed25519 signing
  Future<Uint8List> ed25519Sign(Uint8List privateKey, Uint8List message);
  
  /// Ed25519 signature verification
  Future<bool> ed25519Verify(Uint8List publicKey, Uint8List message, Uint8List signature);
  
  /// AES-256-GCM encrypt
  Future<Uint8List> aesGcmEncrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List plaintext,
    Uint8List? aad,
  });
  
  /// AES-256-GCM decrypt
  Future<Uint8List> aesGcmDecrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List ciphertext,
    Uint8List? aad,
  });
  
  /// HKDF-SHA-256 key derivation
  Future<Uint8List> hkdfDerive({
    required Uint8List inputKeyMaterial,
    required Uint8List salt,
    required Uint8List info,
    required int outputLength,
  });
  
  /// HMAC-SHA-256
  Future<Uint8List> hmacSha256(Uint8List key, Uint8List data);
  
  /// Cryptographically secure random bytes
  Uint8List secureRandomBytes(int length);
}
```

```dart
/// Mobile implementation — uses `cryptography` Dart package
/// which delegates to platform-native crypto (CommonCrypto on iOS,
/// BoringSSL on Android) via FFI.
class NativeCryptoProvider implements CryptoProvider {
  final _x25519 = X25519();
  final _ed25519 = Ed25519();
  final _aesGcm = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256());
  
  @override
  Future<KeyPair> generateX25519KeyPair() async {
    final pair = await _x25519.newKeyPair();
    return KeyPair(
      publicKey: await pair.extractPublicKey().then((k) => Uint8List.fromList(k.bytes)),
      privateKey: await pair.extractPrivateKeyBytes().then((b) => Uint8List.fromList(b)),
    );
  }
  
  @override
  Future<Uint8List> x25519Dh(Uint8List privateKey, Uint8List publicKey) async {
    final secret = await _x25519.sharedSecretKey(
      keyPair: SimpleKeyPairData(privateKey, publicKey: SimplePublicKey(publicKey, type: KeyPairType.x25519)),
      remotePublicKey: SimplePublicKey(publicKey, type: KeyPairType.x25519),
    );
    return Uint8List.fromList(await secret.extractBytes());
  }
  
  // ... AES-GCM, HKDF, HMAC delegate to `cryptography` package
}
```

```dart
/// Web implementation — uses libsodium.js WASM for X25519/Ed25519,
/// Web Crypto API for AES-GCM/HKDF/HMAC (hardware-accelerated).
class WebCryptoProvider implements CryptoProvider {
  late final SodiumJS _sodium;  // libsodium.js WASM instance
  
  /// Initialize WASM module on first use
  Future<void> init() async {
    _sodium = await SodiumJS.init();
  }
  
  @override
  Future<KeyPair> generateX25519KeyPair() async {
    // libsodium.js WASM — identical curve to mobile
    final pair = _sodium.crypto_box_keypair();
    return KeyPair(publicKey: pair.publicKey, privateKey: pair.privateKey);
  }
  
  @override
  Future<Uint8List> x25519Dh(Uint8List privateKey, Uint8List publicKey) async {
    // libsodium.js WASM — produces same shared secret as mobile
    return _sodium.crypto_scalarmult(privateKey, publicKey);
  }
  
  @override
  Future<Uint8List> aesGcmEncrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List plaintext,
    Uint8List? aad,
  }) async {
    // Web Crypto API — hardware accelerated
    final cryptoKey = await window.crypto.subtle.importKey(
      'raw', key, {'name': 'AES-GCM'}, false, ['encrypt'],
    );
    final result = await window.crypto.subtle.encrypt(
      {'name': 'AES-GCM', 'iv': iv, 'additionalData': aad},
      cryptoKey, plaintext,
    );
    return Uint8List.view(result);
  }
  
  @override
  Uint8List secureRandomBytes(int length) {
    final bytes = Uint8List(length);
    window.crypto.getRandomValues(bytes);  // Browser CSPRNG
    return bytes;
  }
  
  // ... Ed25519 via _sodium, HKDF/HMAC via Web Crypto API
}
```

```dart
/// Provider registration — auto-selects implementation at startup
CryptoProvider createCryptoProvider() {
  if (kIsWeb) {
    return WebCryptoProvider();
  } else {
    return NativeCryptoProvider();
  }
}
```

### 12.4 Web Key Storage

The web platform lacks hardware-backed keystores (iOS Keychain / Android Keystore). Key material must be stored carefully:

```
┌──────────────────────────────────────────────────────────────┐
│              WEB KEY STORAGE ARCHITECTURE                     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────┐                     │
│  │  Web Crypto API: CryptoKey Objects │                     │
│  │                                    │                     │
│  │  • Keys generated as              │                     │
│  │    "non-extractable" CryptoKeys   │                     │
│  │  • Private key bytes NEVER        │                     │
│  │    accessible to JavaScript       │                     │
│  │  • Operations (sign, derive)      │                     │
│  │    happen inside browser engine   │                     │
│  │                                    │                     │
│  │  Used for: AES-GCM, HKDF, HMAC   │                     │
│  └────────────────────────────────────┘                     │
│                                                              │
│  ┌────────────────────────────────────┐                     │
│  │  IndexedDB (Encrypted)             │                     │
│  │                                    │                     │
│  │  • Session ratchet state           │                     │
│  │  • Pre-key private keys            │                     │
│  │  • X25519 key material (from WASM) │                     │
│  │                                    │                     │
│  │  Encrypted with a wrapping key     │                     │
│  │  derived from:                     │                     │
│  │  • Non-extractable CryptoKey       │                     │
│  │    (generated once, persisted in   │                     │
│  │     IndexedDB as CryptoKey object) │                     │
│  │                                    │                     │
│  │  DB Name: "e2ee_keystore"          │                     │
│  │  Object Stores:                    │                     │
│  │  ├── identity_keys                 │                     │
│  │  ├── pre_keys                      │                     │
│  │  ├── sessions                      │                     │
│  │  └── wrapping_key (CryptoKey obj)  │                     │
│  └────────────────────────────────────┘                     │
│                                                              │
│  SECURITY NOTES:                                            │
│  • IndexedDB is origin-scoped (same-origin policy)          │
│  • CryptoKey objects cannot be read by extensions            │
│  • XSS is the primary threat → enforce strict CSP           │
│  • Data cleared on "Clear browsing data" → backup needed    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

```dart
/// Web-specific key store using IndexedDB + CryptoKey wrapping.
class WebKeyStoreRepository implements KeyStoreRepository {
  late final IdbFactory _idbFactory;
  late final CryptoKey _wrappingKey;  // Non-extractable AES-256-GCM key
  
  static const _dbName = 'e2ee_keystore';
  static const _dbVersion = 1;
  
  /// Initialize: open IndexedDB and get/create wrapping key.
  Future<void> init() async {
    final db = await _idbFactory.open(_dbName, version: _dbVersion,
      onUpgradeNeeded: (event) {
        final db = event.target.result;
        db.createObjectStore('identity_keys');
        db.createObjectStore('pre_keys');
        db.createObjectStore('sessions');
        db.createObjectStore('wrapping_key');
      },
    );
    
    _wrappingKey = await _getOrCreateWrappingKey(db);
  }
  
  /// Create a non-extractable AES-256-GCM wrapping key.
  /// Stored as CryptoKey object in IndexedDB — browser never
  /// exposes the raw bytes to JavaScript.
  Future<CryptoKey> _getOrCreateWrappingKey(Database db) async {
    final tx = db.transaction('wrapping_key', 'readonly');
    final existing = await tx.objectStore('wrapping_key').getObject('main');
    if (existing != null) return existing as CryptoKey;
    
    // Generate new non-extractable wrapping key
    final key = await window.crypto.subtle.generateKey(
      {'name': 'AES-GCM', 'length': 256},
      false,  // NON-EXTRACTABLE — key bytes never leave browser engine
      ['encrypt', 'decrypt', 'wrapKey', 'unwrapKey'],
    );
    
    final writeTx = db.transaction('wrapping_key', 'readwrite');
    await writeTx.objectStore('wrapping_key').put(key, 'main');
    return key;
  }
  
  /// Store key material encrypted with the wrapping key.
  Future<void> _storeEncrypted(String store, String id, Uint8List data) async {
    final iv = window.crypto.getRandomValues(Uint8List(12));
    final encrypted = await window.crypto.subtle.encrypt(
      {'name': 'AES-GCM', 'iv': iv},
      _wrappingKey, data,
    );
    
    final db = await _openDb();
    final tx = db.transaction(store, 'readwrite');
    await tx.objectStore(store).put({
      'iv': iv,
      'data': Uint8List.view(encrypted),
    }, id);
  }
  
  /// Retrieve and decrypt key material.
  Future<Uint8List?> _readEncrypted(String store, String id) async {
    final db = await _openDb();
    final tx = db.transaction(store, 'readonly');
    final record = await tx.objectStore(store).getObject(id);
    if (record == null) return null;
    
    final map = record as Map;
    final decrypted = await window.crypto.subtle.decrypt(
      {'name': 'AES-GCM', 'iv': map['iv']},
      _wrappingKey, map['data'],
    );
    return Uint8List.view(decrypted);
  }
}
```

### 12.5 Cross-Platform Message Exchange

The following diagram shows how a mobile user and web user exchange encrypted messages. The protocol mechanics are identical — only the underlying crypto implementation differs.

```
 Alice (iPhone)                        Firestore                         Bob (Chrome)
 NativeCryptoProvider                                              WebCryptoProvider
      │                                   │                                   │
      │  Alice wants to message Bob       │                                   │
      │                                   │                                   │
      │  1. Fetch Bob's PreKeyBundle      │                                   │
      │  ────────────────────────────►    │                                   │
      │  ◄────────────────────────────    │                                   │
      │  {IK_bob, SPK_bob, OPK_bob}      │   (generated by libsodium WASM)   │
      │                                   │                                   │
      │  2. X3DH via NativeCryptoProvider │                                   │
      │     x25519Dh() → CommonCrypto     │                                   │
      │     Shared Secret = SK            │                                   │
      │                                   │                                   │
      │  3. AES-256-GCM encrypt (HW accel)│                                   │
      │     ciphertext = E(MK, plaintext) │                                   │
      │                                   │                                   │
      │  4. Store encrypted message        │                                   │
      │  ────────────────────────────►    │                                   │
      │     {ciphertext, header,           │                                   │
      │      initial_message}              │                                   │
      │                                   │  5. Snapshot listener fires        │
      │                                   │  ────────────────────────────►    │
      │                                   │                                   │
      │                                   │  6. X3DH via WebCryptoProvider    │
      │                                   │     x25519Dh() → libsodium WASM  │
      │                                   │     Shared Secret = SK (SAME!)    │
      │                                   │                                   │
      │                                   │  7. AES-256-GCM decrypt           │
      │                                   │     Web Crypto API (HW accel)     │
      │                                   │     plaintext = D(MK, ciphertext) │
      │                                   │                                   │
      │                                   │  8. Display plaintext ✓           │
```

**Why the shared secrets match:** Both `NativeCryptoProvider.x25519Dh()` and `WebCryptoProvider.x25519Dh()` operate on the same Curve25519 — the DH output is a deterministic mathematical function of the two keys. The platform is irrelevant; only the keys matter.

### 12.6 Web Device Linking (QR Pairing)

Web clients participate as **linked secondary devices**, similar to WhatsApp Web. The mobile app remains the trust anchor.

```
┌──────────────────────────────────────────────────────────────┐
│               WEB DEVICE LINKING FLOW                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User opens web app → sees QR code                       │
│     QR contains:                                             │
│     {                                                        │
│       version: 1,                                            │
│       webDeviceId: "chrome_a1b2c3",                         │
│       webIdentityKey: IK_web_pub (Base64),                  │
│       timestamp: 1740150000,                                │
│       challenge: random_32_bytes (Base64)                    │
│     }                                                        │
│     │                                                        │
│  2. User scans QR with mobile app                           │
│     │                                                        │
│  3. Mobile app verifies:                                     │
│     a. QR timestamp < 2 minutes old                         │
│     b. webDeviceId not already registered                   │
│     c. User has < 5 devices                                 │
│     │                                                        │
│  4. Mobile app registers web device in Firestore:           │
│     users/{userId}/devices/{webDeviceId} = {                │
│       identityKey: IK_web_pub,                              │
│       signedPreKey: (from QR handshake),                    │
│       deviceName: "Chrome on MacOS",                        │
│       linkedFrom: mobile_deviceId,                          │
│       createdAt: timestamp                                  │
│     }                                                        │
│     │                                                        │
│  5. Mobile app signs web device's identity key:             │
│     attestation = Ed25519Sign(IK_mobile_priv, IK_web_pub)   │
│     Stored in device record for cross-device trust          │
│     │                                                        │
│  6. Mobile app sends confirmation via Firestore:            │
│     linking_requests/{challenge} = { status: "approved" }   │
│     │                                                        │
│  7. Web client sees approval → generates SPK + OPKs         │
│     Publishes PreKeyBundle to Firestore                     │
│     │                                                        │
│  8. Web device is now a full E2EE participant               │
│     • Gets its own ratchet sessions with each contact       │
│     • Messages sent to mobile encrypt for all devices       │
│     • Web generates independent session keys                │
│                                                              │
│  REVOCATION:                                                 │
│  • Mobile app → Device Management → "Unlink web device"    │
│  • Deletes users/{userId}/devices/{webDeviceId}             │
│  • All contacts see "device removed" in transparency log   │
│  • Existing sessions with that device are invalidated       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 12.7 Web-Specific Threat Mitigations

| Threat | Impact | Mitigation |
|--------|--------|------------|
| **XSS (Cross-Site Scripting)** | Attacker JS could read IndexedDB key material | Strict CSP (`script-src 'self'`); no inline scripts; Trusted Types; subresource integrity (SRI) on all scripts |
| **Malicious browser extension** | Extension can access page DOM and IndexedDB | Non-extractable CryptoKey objects for AES keys; X25519 keys in WASM memory (not JS heap); warn users about extension risks |
| **Compromised server (code delivery)** | Server serves modified JS with backdoored crypto | SRI hashes on script tags; optional browser extension to verify bundle hash; code transparency log |
| **"Clear browsing data"** | User loses all key material | Prompt for key backup setup on web registration; show warning that clearing data will log out E2EE |
| **Tab suspension / crash** | In-memory ratchet state lost mid-session | Persist ratchet state to IndexedDB after every encrypt/decrypt; recovery on reload |
| **Shared / public computer** | Next user could access keys | Session timeout (30 min idle); explicit "Log out" clears IndexedDB; no "Remember me" for E2EE sessions |
| **No hardware keystore** | Keys in software only | Defense in depth: wrapping key (non-extractable CryptoKey) + encrypted IndexedDB + CSP + SRI |

### 12.8 Web-Specific Content Security Policy

```html
<!-- Required CSP headers for E2EE web client -->
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self' 'wasm-unsafe-eval';
  worker-src 'self' blob:;
  connect-src 'self' https://*.firebaseio.com https://*.googleapis.com wss://*.firebaseio.com;
  style-src 'self' 'unsafe-inline';
  img-src 'self' blob: data: https://*.googleapis.com;
  object-src 'none';
  base-uri 'self';
  require-trusted-types-for 'script';
">
```

- `'wasm-unsafe-eval'` — required for libsodium.js WASM execution
- `object-src 'none'` — blocks Flash/plugin-based attacks
- `require-trusted-types-for 'script'` — prevents DOM XSS

### 12.9 Web Performance Considerations

| Operation | Mobile (native) | Web (WASM + Web Crypto) | Notes |
|-----------|-----------------|-------------------------|-------|
| X25519 DH | <1ms | ~2ms | libsodium WASM, near-native speed |
| Ed25519 sign | <1ms | ~2ms | libsodium WASM |
| AES-256-GCM (1KB text) | <1ms | <1ms | Web Crypto API, hardware-accelerated |
| AES-256-GCM (10MB media) | ~50ms | ~80ms | Web Crypto API, slightly slower than native |
| HKDF derive | <1ms | <1ms | Web Crypto API |
| WASM module init | N/A | ~100ms (first load) | Cached after first load; lazy-loaded |
| IndexedDB key read | N/A | ~3ms | Async; slightly slower than Keychain |
| Total cold-start overhead | 0ms | ~150ms | WASM init + IndexedDB open (one-time) |

### 12.10 File Structure (Web Additions)

```
lib/
├── core/
│   └── crypto/
│       ├── crypto_provider.dart           // Abstract interface
│       ├── native_crypto_provider.dart     // iOS/Android implementation
│       └── web_crypto_provider.dart        // Web implementation (conditional import)
│
├── data/
│   └── repositories/
│       └── crypto/
│           ├── key_store_repository.dart   // Abstract interface
│           ├── native_key_store.dart       // flutter_secure_storage (mobile)
│           └── web_key_store.dart          // IndexedDB + CryptoKey (web)
│
web/
├── index.html                             // Updated CSP headers
├── sodium.js                              // libsodium.js WASM loader
└── sodium.wasm                            // libsodium WASM binary (~200KB gzip)
```

### 12.11 PreKeyBundle Platform Independence

PreKey bundles stored in Firestore contain **no platform indicator**. Any device (mobile or web) can consume any other device's bundle:

```typescript
// Firestore: users/{userId}/devices/{deviceId}
// These fields are IDENTICAL regardless of generating platform
{
  identityKey: "base64...",      // 32-byte X25519 public key (same curve everywhere)
  signedPreKey: {
    keyId: 42,
    publicKey: "base64...",      // 32-byte X25519 public key
    signature: "base64..."       // 64-byte Ed25519 signature
  },
  oneTimePreKeys: [              // All X25519 public keys
    { keyId: 1, publicKey: "base64..." },
    { keyId: 2, publicKey: "base64..." }
  ],
  registrationId: 12345,
  deviceName: "Chrome on MacOS", // Human-readable, not used for crypto
  lastActive: Timestamp,
  createdAt: Timestamp
  // NO: platform, curve_type, crypto_version — these are implicit
}
```

Because all platforms use X25519 (via native FFI or libsodium WASM), the public keys are byte-for-byte compatible. A mobile device performing `x25519Dh(mobile_private, web_public)` produces the exact same shared secret as a web device performing `x25519Dh(web_private, mobile_public)` — this is the commutativity property of Diffie-Hellman.

---

## 13. Firestore Security Rules

```javascript
// Updated firestore.rules for E2EE collections

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // === EXISTING RULES (unchanged) ===
    // ... chat_rooms, users, etc.
    
    // === NEW: Device / PreKey Bundle Rules ===
    match /users/{userId}/devices/{deviceId} {
      // Anyone authenticated can read public keys (needed for key exchange)
      allow read: if isAuthenticated();
      
      // Only the device owner can write their own keys
      allow create, update: if isAuthenticated() 
        && getUserId() == userId
        && request.resource.data.keys().hasAll([
          'identityKey', 'signedPreKey', 'registrationId'
        ]);
      
      // Only the device owner can delete (revoke) their device
      allow delete: if isAuthenticated() && getUserId() == userId;
    }
    
    // === NEW: Key Backup Rules ===
    match /key_backup/{userId} {
      // Only the backup owner can read/write their backup
      allow read, write: if isAuthenticated() && getUserId() == userId;
    }
    
    // === NEW: Key Transparency Log (append-only) ===
    match /key_transparency_log/{logId} {
      // Anyone can read (transparency)
      allow read: if isAuthenticated();
      
      // Only Cloud Functions can write (via service account)
      allow write: if false; // Enforced via Admin SDK
    }
    
    // === UPDATED: Chat Messages (encrypted) ===
    match /chat_rooms/{roomId}/messages/{messageId} {
      allow read: if isAuthenticated() 
        && isRoomParticipant(roomId);
      
      allow create: if isAuthenticated()
        && request.resource.data.sender_id == getUserId()
        && isRoomParticipant(roomId)
        // Encrypted messages must have ciphertext + header
        && request.resource.data.keys().hasAll(['ciphertext', 'header', 'sender_id', 'type', 'timestamp']);
      
      allow delete: if isAuthenticated() 
        && isRoomParticipant(roomId);
      
      // Only sender can update (edit encrypted message)
      allow update: if isAuthenticated()
        && resource.data.sender_id == getUserId();
    }
  }
}
```

---

## 14. Performance & Scalability

### 14.1 Performance Benchmarks

| Operation | Target | Approach |
|-----------|--------|----------|
| X3DH handshake | <200ms | X25519 DH is fast; prekey fetch is 1 Firestore read |
| Text encrypt | <10ms | AES-256-GCM hardware-accelerated on modern devices |
| Text decrypt | <10ms | AES-256-GCM hardware-accelerated on modern devices |
| Media encrypt (1MB) | <50ms | AES-GCM with hardware acceleration |
| Media encrypt (10MB) | <500ms | Chunked, streamed, background isolate |
| Media encrypt (25MB) | <1.2s | Chunked, streamed, background isolate |
| Key generation (100 OPKs) | <300ms | Batched X25519 generation |
| Session state load | <5ms | Single secure storage read |
| Safety number compute | <1ms | SHA-256 + truncation |

### 14.2 Scalability Considerations

```
┌──────────────────────────────────────────────────────────────┐
│               SCALABILITY ANALYSIS                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  KEY EXCHANGE:                                               │
│  • X3DH is O(1) per chat session (one-time setup)           │
│  • No server roundtrips needed for subsequent messages       │
│  • Prekey bundles cached locally after first fetch           │
│                                                              │
│  MESSAGE ENCRYPTION:                                         │
│  • Double Ratchet: O(1) per message (HMAC + AES-GCM)       │
│  • No server interaction for key derivation                  │
│  • Ratchet state is ~500 bytes per session                  │
│                                                              │
│  STORAGE:                                                    │
│  • Ciphertext overhead: ~16 bytes (GCM tag) + ~44 bytes     │
│    (header) = ~60 bytes per message                          │
│  • Media: identical Size (GCM tag negligible for files)      │
│  • Prekey bundle: ~2KB per device (100 OPKs)                │
│                                                              │
│  FIRESTORE READS:                                            │
│  • No additional reads for message encrypt/decrypt           │
│  • 1 read for initial X3DH (PreKeyBundle fetch)             │
│  • Prekey rotation: 1 write per week per device              │
│                                                              │
│  COMPUTE (CLIENT):                                           │
│  • AES-GCM: Hardware-accelerated (AES-NI / ARMv8 CE)       │
│  • Background isolate for media encryption (no UI jank)      │
│  • Lazy session initialization (only when chatting)          │
│                                                              │
│  COMPUTE (SERVER):                                           │
│  • KMS calls: Only for backup wrap/unwrap + attestation      │
│  • No per-message server computation                         │
│  • Cloud Functions: Minimal changes to existing triggers     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 14.3 Optimizations

| Optimization | Description |
|-------------|-------------|
| **Background Isolate** | Media encryption runs in `Isolate.run()` to avoid UI thread blocking |
| **Lazy Session Init** | Sessions created on first message, not on contact list load |
| **Prekey Caching** | Remote prekey bundles cached locally for 24 hours |
| **Batch OPK Upload** | 100 OPKs generated and uploaded in single batch write |
| **Chunked Media** | Large files encrypted in 64KB chunks, streamed to storage |
| **Session State Cache** | Hot sessions kept in memory LRU cache (capacity: 20) |
| **Hardware Acceleration** | `pointycastle` + platform channels for AES-NI / ARM CE |
| **Parallel Device Encrypt** | Multi-device: encrypt for all devices in parallel |

---

## 15. Implementation Phases

### Phase 1: Core Cryptographic Foundation (3 weeks)

| Task | Description | Priority |
|------|-------------|----------|
| Add dependencies | `pointycastle`, `flutter_secure_storage`, `x25519`, `cryptography` | P0 |
| Implement `SignalProtocolEngine` | X3DH + Double Ratchet in Dart | P0 |
| Implement `AesGcmCipher` | AES-256-GCM encrypt/decrypt wrapper | P0 |
| Implement `KeyStoreRepository` | Platform keychain integration | P0 |
| Implement `SessionRepository` | Local encrypted session persistence | P0 |
| Unit tests for all crypto operations | Test vectors from Signal spec + NIST | P0 |

### Phase 2: Key Management & Registration (2 weeks)

| Task | Description | Priority |
|------|-------------|----------|
| Device registration flow | Identity key generation + prekey bundle upload | P0 |
| `PreKeyRepository` | Firestore CRUD for prekey bundles | P0 |
| `registerDevice` Cloud Function | Server-side device registration | P0 |
| `attestPrekeyBundle` Cloud Function | KMS-signed bundle attestation | P1 |
| GCP KMS key ring setup | Terraform/scripts for KMS + Secret Manager | P0 |
| Signed prekey rotation | Weekly SPK rotation with old key grace period | P0 |
| OPK replenishment | Auto-replenish when count drops below 20 | P0 |

### Phase 3: Message Encryption Integration (3 weeks)

| Task | Description | Priority |
|------|-------------|----------|
| `EncryptionService` | Core orchestrator: encrypt/decrypt messages | P0 |
| Modify `ChatMessageRepository` | Integrate E2EE into send/receive flow | P0 |
| Modify `ChatStreamService` | Decrypt messages in real-time stream | P0 |
| Update `ChatConversationViewModel` | Handle encrypted state, error recovery | P0 |
| Update Firestore security rules | Enforce encrypted message format | P0 |
| Modify push notifications | Remove plaintext content from FCM payload | P0 |
| Encryption status UI indicator | Lock icon on chat header | P1 |

### Phase 4: Media & Document Encryption (2 weeks)

| Task | Description | Priority |
|------|-------------|----------|
| `MediaEncryptionService` | Per-file AES-256-GCM encryption | P0 |
| Modify `ChatMediaHandler` | Encrypt before upload, decrypt after download | P0 |
| Modify `UploadManager` | Handle encrypted upload streams | P0 |
| Chunked encryption | 64KB chunk-based encryption for large files | P1 |
| Thumbnail encryption | Encrypt preview thumbnails | P1 |
| Update `MediaCacheService` | Cache decrypted media locally | P1 |

### Phase 5: Key Backup & Recovery (2 weeks)

| Task | Description | Priority |
|------|-------------|----------|
| `KeyBackupRepository` | Encrypted backup to Cloud Storage | P1 |
| `storeKeyBackup` Cloud Function | KMS-wrapped backup storage | P1 |
| `retrieveKeyBackup` Cloud Function | KMS-unwrap + return flow | P1 |
| Backup UI | Passphrase setup, backup/restore screens | P1 |
| Recovery flow | New device key restoration | P1 |

### Phase 6: Verification & Device Management (2 weeks)

| Task | Description | Priority |
|------|-------------|----------|
| Safety number generation | SHA-256 based fingerprints | P1 |
| Safety number comparison UI | Side-by-side + QR code screen | P1 |
| Identity key change detection | Warning banner + re-verification flow | P0 |
| Device management UI | List, verify, revoke devices | P1 |
| Key transparency log | Auditable key change history | P2 |

### Phase 7: Web Client & Cross-Platform (3 weeks)

| Task | Description | Priority |
|------|-------------|----------|
| `CryptoProvider` interface | Abstract crypto layer with `NativeCryptoProvider` + `WebCryptoProvider` | P0 |
| libsodium.js WASM integration | Bundle and lazy-load libsodium for X25519/Ed25519 on web | P0 |
| `WebKeyStoreRepository` | IndexedDB + non-extractable CryptoKey wrapping | P0 |
| QR-based web device linking | Scan-to-link flow from mobile app | P0 |
| Web CSP configuration | Strict Content-Security-Policy for XSS mitigation | P0 |
| Web session timeout | Auto-logout after 30 min idle; clear keys on explicit logout | P1 |
| Cross-platform integration tests | Mobile-to-web and web-to-mobile encrypt/decrypt validation | P0 |
| Web performance benchmarks | Validate WASM + Web Crypto API latency targets | P1 |
| Performance monitoring | Track encrypt/decrypt latency via Analytics | P1 |
| Security audit | External crypto review | P0 |

**Total estimated timeline: ~17 weeks**

---

## 16. Security Audit & Compliance

### 16.1 NIST Compliance Matrix

| NIST Standard | Requirement | Implementation |
|--------------|-------------|----------------|
| **SP 800-56A Rev 3** | Key Agreement (DH) | X25519 for ECDH key agreement |
| **SP 800-56C Rev 2** | Key Derivation | HKDF-SHA-256 for all key derivation |
| **SP 800-38D** | Symmetric AEAD | AES-256-GCM for message + media encryption |
| **FIPS 197** | AES specification | AES-256 block cipher |
| **FIPS 186-5** | Digital Signatures | Ed25519 (EdDSA) for identity key signing |
| **FIPS 198-1** | HMAC | HMAC-SHA-256 for chain key advancement |
| **SP 800-132** | PBKDF | PBKDF2-SHA-256 (600K iterations) for backup key |
| **SP 800-90A** | Random Generation | Platform CSPRNG (SecRandomCopyBytes / SecureRandom) |
| **SP 800-57** | Key Management | Key lifecycle management per recommendations |
| **SP 800-186** | Elliptic Curves | Curve25519 approved for key agreement |

### 16.2 Audit Checklist

- [ ] External cryptographic protocol review by security firm
- [ ] Penetration testing on key exchange endpoints
- [ ] Formal verification of ratchet state machine
- [ ] Key material memory handling audit (zeroization)
- [ ] Side-channel analysis on mobile implementations
- [ ] Compliance review against NIST SP 800-175B
- [ ] Cloud KMS IAM policy review
- [ ] Key transparency log integrity verification
- [ ] Backup encryption strength assessment
- [ ] Threat modeling workshop with security team

### 16.3 Ongoing Security Measures

| Measure | Frequency | Owner |
|---------|-----------|-------|
| Dependency vulnerability scanning | Weekly (Dependabot) | DevOps |
| KMS key rotation | Automatic, 90 days | GCP |
| Cloud Audit Log review | Monthly | Security Team |
| Crypto library updates | As released | Engineering |
| Protocol version review | Quarterly | Architecture |
| Penetration testing | Annually | External vendor |
| Incident response drill | Semi-annually | Security Team |

---

## Appendix A: Dependencies to Add

### Flutter (pubspec.yaml)

```yaml
dependencies:
  cryptography: ^2.7.0          # X25519, Ed25519, AES-GCM, HKDF, HMAC
  flutter_secure_storage: ^9.0.0 # Platform keychain (iOS/Android)
  pointycastle: ^3.9.1          # Fallback crypto primitives
  protobuf: ^3.1.0              # Efficient session state serialization
  convert: ^3.1.1               # Base64 encoding utilities
```

### Web Assets

```
web/
├── sodium.js                    # libsodium.js loader (~20KB)
└── sodium.wasm                  # libsodium WASM binary (~200KB gzipped)
```

- Source: https://github.com/nickg1/libsodium.js (official libsodium JS/WASM bindings)
- Loaded lazily on first crypto operation; cached by browser thereafter
- Integrity verified via SRI hash on `<script>` tag

### Cloud Functions (package.json)

```json
{
  "dependencies": {
    "@google-cloud/kms": "^4.5.0",
    "@google-cloud/secret-manager": "^5.6.0"
  }
}
```

### GCP Infrastructure

```bash
# Create KMS keyring + keys
gcloud kms keyrings create e2ee-chat --location global

gcloud kms keys create prekey-attestation-key \
  --keyring e2ee-chat --location global \
  --purpose asymmetric-signing \
  --default-algorithm ec-sign-p256-sha256

gcloud kms keys create backup-wrapping-key \
  --keyring e2ee-chat --location global \
  --purpose encryption \
  --default-algorithm google-symmetric-encryption \
  --rotation-period 7776000s  # 90 days

gcloud kms keys create audit-log-signing-key \
  --keyring e2ee-chat --location global \
  --purpose asymmetric-signing \
  --default-algorithm ec-sign-p256-sha256

# IAM: Grant Cloud Functions service account access
gcloud kms keys add-iam-policy-binding prekey-attestation-key \
  --keyring e2ee-chat --location global \
  --member serviceAccount:PROJECT_ID@appspot.gserviceaccount.com \
  --role roles/cloudkms.signerVerifier

gcloud kms keys add-iam-policy-binding backup-wrapping-key \
  --keyring e2ee-chat --location global \
  --member serviceAccount:PROJECT_ID@appspot.gserviceaccount.com \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter
```

---

## Appendix B: Test Vectors

Validate implementation against Signal Protocol test vectors and NIST CAVP test vectors:

| Test Category | Source |
|--------------|--------|
| X25519 DH | RFC 7748 Section 6.1 |
| Ed25519 Signing | RFC 8032 Section 7.1 |
| AES-256-GCM | NIST SP 800-38D Appendix B |
| HKDF-SHA-256 | RFC 5869 Appendix A |
| HMAC-SHA-256 | RFC 4231 Test Vectors |
| X3DH Protocol | Signal Specification v3 |
| Double Ratchet | Signal Specification v1 |
| PBKDF2-SHA-256 | RFC 6070 Test Vectors |

---

## Appendix C: Glossary

| Term | Definition |
|------|-----------|
| **X3DH** | Extended Triple Diffie-Hellman: Asynchronous key agreement protocol |
| **Double Ratchet** | Key management algorithm providing forward/future secrecy |
| **DH Ratchet** | Asymmetric ratchet step using new DH key pairs |
| **Symmetric Ratchet** | Advancing chain keys with HMAC for each message |
| **Forward Secrecy** | Past messages remain secure even if current keys are compromised |
| **Future Secrecy** | Protocol self-heals after temporary key compromise |
| **AEAD** | Authenticated Encryption with Associated Data (AES-GCM) |
| **Prekey Bundle** | Published public keys enabling asynchronous key exchange |
| **OPK** | One-Time Pre-Key: Single-use key for enhanced forward secrecy |
| **SPK** | Signed Pre-Key: Medium-term key signed by identity key |
| **IK** | Identity Key: Long-term key identifying a device |
| **Safety Number** | Fingerprint derived from identity keys for verification |
| **TOFU** | Trust On First Use: Accept identity key on first contact |
| **KMS** | Key Management Service (Google Cloud) |
| **CSPRNG** | Cryptographically Secure Pseudo-Random Number Generator |
| **GCM** | Galois/Counter Mode: AEAD mode for AES |
