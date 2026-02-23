import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/core/crypto/aes_gcm_cipher.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/features/chat/services/room_key_service.dart';

/// Encrypts and decrypts chat messages using per-room AES-256 keys.
///
/// Room keys are managed by [RoomKeyService] (fetched from Cloud Functions,
/// cached in memory). This service only performs the symmetric AES-256-GCM
/// encrypt/decrypt operations.
///
/// Each message gets a fresh random 12-byte IV from the platform CSPRNG.
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

  // =========================================================================
  // Encrypt
  // =========================================================================

  /// Encrypt a message for a room.
  ///
  /// 1. Retrieves the room key (from cache or Cloud Function)
  /// 2. Serializes [content] to JSON bytes
  /// 3. Generates a random 12-byte IV
  /// 4. AES-256-GCM encrypts
  ///
  /// Returns an [EncryptedMessage] ready to be stored in Firestore.
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

  // =========================================================================
  // Decrypt
  // =========================================================================

  /// Decrypt a received encrypted message.
  ///
  /// 1. Retrieves the room key (from cache or Cloud Function)
  /// 2. Decodes ciphertext + IV from Base64
  /// 3. AES-256-GCM decrypts
  /// 4. Deserializes JSON to [DecryptedContent]
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

  /// Clear cached keys on sign-out.
  void clearAll() {
    _roomKeyService.clearCache();
  }
}
