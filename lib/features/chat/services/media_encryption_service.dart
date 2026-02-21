import 'dart:convert';
import 'dart:typed_data';

import 'package:securityexperts_app/core/crypto/aes_gcm_cipher.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Result of encrypting a media file.
///
/// Contains the encrypted bytes and the key material needed
/// to decrypt the file later (stored inside the Signal Protocol
/// ciphertext as part of [DecryptedContent]).
class EncryptedMediaResult {
  /// Encrypted file bytes (ciphertext + GCM auth tag).
  final Uint8List encryptedBytes;

  /// Combined key + IV for decryption, Base64-encoded.
  /// Format: 32-byte AES key ‖ 12-byte IV → 44 bytes → Base64.
  final String mediaKey;

  /// SHA-256 hash of the original plaintext file, hex-encoded.
  final String mediaHash;

  /// Original plaintext file size in bytes.
  final int originalSize;

  const EncryptedMediaResult({
    required this.encryptedBytes,
    required this.mediaKey,
    required this.mediaHash,
    required this.originalSize,
  });
}

/// Per-file AES-256-GCM encryption for media attachments.
///
/// Each media file gets a unique random key + IV, ensuring that
/// even identical files produce different ciphertexts. The key
/// material is transmitted inside the Signal Protocol encrypted
/// message envelope ([DecryptedContent.mediaKey]), so the server
/// never sees it.
///
/// For files ≤10 MB, encryption is done in one shot.
/// For files >10 MB, chunked encryption is used (64 KB chunks)
/// to limit memory pressure on mobile devices.
class MediaEncryptionService {
  static const String _tag = 'MediaEncryptionService';
  static const int _chunkThreshold = 10 * 1024 * 1024; // 10 MB
  static const int _chunkSize = 64 * 1024; // 64 KB

  final CryptoProvider _crypto;
  final AesGcmCipher _cipher;
  final AppLogger _log;

  MediaEncryptionService({
    required CryptoProvider crypto,
    AesGcmCipher? cipher,
    AppLogger? logger,
  })  : _crypto = crypto,
        _cipher = cipher ?? AesGcmCipher(crypto),
        _log = logger ?? sl<AppLogger>();

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  /// Encrypt a media file.
  ///
  /// Generates a random AES-256 key and 12-byte IV, computes the
  /// SHA-256 hash of the plaintext, then encrypts.
  ///
  /// Returns [EncryptedMediaResult] containing the ciphertext,
  /// combined key material (Base64), and integrity hash.
  Future<EncryptedMediaResult> encryptFile(Uint8List plaintext) async {
    _log.debug(
      'Encrypting file: ${plaintext.length} bytes',
      tag: _tag,
    );

    // 1. Generate random key (32 bytes) + IV (12 bytes)
    final key = _crypto.secureRandomBytes(32);
    final iv = _crypto.secureRandomBytes(12);

    // 2. Compute SHA-256 hash of plaintext for integrity
    final hash = await _computeSha256(plaintext);

    // 3. Encrypt
    final Uint8List ciphertext;
    if (plaintext.length > _chunkThreshold) {
      ciphertext = await _encryptChunked(key: key, iv: iv, plaintext: plaintext);
    } else {
      ciphertext = await _cipher.encrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
        aad: _buildAad(hash),
      );
    }

    // 4. Combine key ‖ IV → Base64 for transport inside Signal ciphertext
    final combined = Uint8List(44);
    combined.setRange(0, 32, key);
    combined.setRange(32, 44, iv);
    final mediaKey = base64Encode(combined);

    _log.debug(
      'File encrypted: ${ciphertext.length} bytes ciphertext',
      tag: _tag,
    );

    return EncryptedMediaResult(
      encryptedBytes: ciphertext,
      mediaKey: mediaKey,
      mediaHash: hash,
      originalSize: plaintext.length,
    );
  }

  /// Decrypt a media file.
  ///
  /// [encryptedBytes] is the ciphertext downloaded from Firebase Storage.
  /// [mediaKey] is the Base64-encoded key ‖ IV from [DecryptedContent].
  /// [mediaHash] is the SHA-256 hash of the original plaintext for
  ///   integrity verification (optional but recommended).
  ///
  /// Throws if decryption or integrity check fails.
  Future<Uint8List> decryptFile({
    required Uint8List encryptedBytes,
    required String mediaKey,
    String? mediaHash,
  }) async {
    _log.debug(
      'Decrypting file: ${encryptedBytes.length} bytes',
      tag: _tag,
    );

    // 1. Decode key ‖ IV from Base64
    final combined = base64Decode(mediaKey);
    if (combined.length != 44) {
      throw ArgumentError(
        'Invalid mediaKey length: expected 44 bytes (32 key + 12 IV), '
        'got ${combined.length}',
      );
    }
    final key = Uint8List.sublistView(combined, 0, 32);
    final iv = Uint8List.sublistView(combined, 32, 44);

    // 2. Decrypt
    final Uint8List plaintext;
    if (_isChunkedCiphertext(encryptedBytes)) {
      plaintext = await _decryptChunked(
        key: key,
        iv: iv,
        ciphertext: encryptedBytes,
      );
    } else {
      plaintext = await _cipher.decrypt(
        key: key,
        iv: iv,
        ciphertext: encryptedBytes,
        aad: mediaHash != null ? _buildAad(mediaHash) : null,
      );
    }

    // 3. Verify integrity hash if provided
    if (mediaHash != null) {
      final actualHash = await _computeSha256(plaintext);
      if (actualHash != mediaHash) {
        throw MediaIntegrityException(
          'Media integrity check failed: '
          'expected $mediaHash, got $actualHash',
        );
      }
    }

    _log.debug(
      'File decrypted: ${plaintext.length} bytes plaintext',
      tag: _tag,
    );

    return plaintext;
  }

  /// Encrypt a thumbnail image.
  ///
  /// Returns (encryptedBytes, thumbnailKey) where thumbnailKey is
  /// Base64(key ‖ IV) for storage inside [DecryptedContent.thumbnailKey].
  Future<(Uint8List, String)> encryptThumbnail(Uint8List thumbnail) async {
    final key = _crypto.secureRandomBytes(32);
    final iv = _crypto.secureRandomBytes(12);

    final ciphertext = await _cipher.encrypt(
      key: key,
      iv: iv,
      plaintext: thumbnail,
    );

    final combined = Uint8List(44);
    combined.setRange(0, 32, key);
    combined.setRange(32, 44, iv);

    return (ciphertext, base64Encode(combined));
  }

  /// Decrypt a thumbnail image.
  Future<Uint8List> decryptThumbnail({
    required Uint8List encryptedBytes,
    required String thumbnailKey,
  }) async {
    final combined = base64Decode(thumbnailKey);
    if (combined.length != 44) {
      throw ArgumentError(
        'Invalid thumbnailKey length: expected 44, got ${combined.length}',
      );
    }
    final key = Uint8List.sublistView(combined, 0, 32);
    final iv = Uint8List.sublistView(combined, 32, 44);

    return _cipher.decrypt(key: key, iv: iv, ciphertext: encryptedBytes);
  }

  // =========================================================================
  // CHUNKED ENCRYPTION (>10 MB files)
  // =========================================================================

  /// Chunked AES-256-GCM encryption for large files.
  ///
  /// Format: [4-byte magic][4-byte chunk count][chunk1][chunk2]...
  /// Each chunk: [4-byte ciphertext length][ciphertext + 16-byte GCM tag]
  ///
  /// Per-chunk IV is derived: HKDF(key, "chunk" ‖ chunkIndex) → 12 bytes,
  /// preventing IV reuse across chunks.
  Future<Uint8List> _encryptChunked({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List plaintext,
  }) async {
    _log.debug(
      'Using chunked encryption for ${plaintext.length} bytes',
      tag: _tag,
    );

    final chunkCount = (plaintext.length + _chunkSize - 1) ~/ _chunkSize;
    final chunks = <Uint8List>[];

    for (var i = 0; i < chunkCount; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize < plaintext.length)
          ? start + _chunkSize
          : plaintext.length;
      final chunkData = Uint8List.sublistView(plaintext, start, end);

      // Derive per-chunk IV to prevent IV reuse
      final chunkIv = await _deriveChunkIv(key, iv, i);
      final chunkAad = _buildChunkAad(i, chunkCount);

      final encrypted = await _cipher.encrypt(
        key: key,
        iv: chunkIv,
        plaintext: chunkData,
        aad: chunkAad,
      );

      chunks.add(encrypted);
    }

    return _assembleChunks(chunks, chunkCount);
  }

  /// Chunked AES-256-GCM decryption for large files.
  Future<Uint8List> _decryptChunked({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List ciphertext,
  }) async {
    final (chunks, chunkCount) = _disassembleChunks(ciphertext);

    final decryptedChunks = <Uint8List>[];
    for (var i = 0; i < chunks.length; i++) {
      final chunkIv = await _deriveChunkIv(key, iv, i);
      final chunkAad = _buildChunkAad(i, chunkCount);

      final decrypted = await _cipher.decrypt(
        key: key,
        iv: chunkIv,
        ciphertext: chunks[i],
        aad: chunkAad,
      );

      decryptedChunks.add(decrypted);
    }

    // Concatenate all decrypted chunks
    final totalLength = decryptedChunks.fold<int>(0, (s, c) => s + c.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in decryptedChunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return result;
  }

  /// Magic bytes to identify chunked ciphertext format.
  static final Uint8List _chunkMagicBytes =
      Uint8List.fromList([0xE2, 0xEE, 0xC4, 0x4B]);

  /// Check if ciphertext uses chunked format.
  bool _isChunkedCiphertext(Uint8List data) {
    if (data.length < 8) return false;
    return data[0] == _chunkMagicBytes[0] &&
        data[1] == _chunkMagicBytes[1] &&
        data[2] == _chunkMagicBytes[2] &&
        data[3] == _chunkMagicBytes[3];
  }

  /// Assemble encrypted chunks into the chunked format.
  Uint8List _assembleChunks(List<Uint8List> chunks, int chunkCount) {
    // Calculate total size
    var totalSize = 8; // 4 magic + 4 chunk count
    for (final chunk in chunks) {
      totalSize += 4 + chunk.length; // 4 length prefix + ciphertext
    }

    final result = Uint8List(totalSize);
    var offset = 0;

    // Write magic bytes
    result.setRange(0, 4, _chunkMagicBytes);
    offset += 4;

    // Write chunk count (big-endian 32-bit)
    result[offset] = (chunkCount >> 24) & 0xFF;
    result[offset + 1] = (chunkCount >> 16) & 0xFF;
    result[offset + 2] = (chunkCount >> 8) & 0xFF;
    result[offset + 3] = chunkCount & 0xFF;
    offset += 4;

    // Write each chunk: [4-byte length][ciphertext]
    for (final chunk in chunks) {
      result[offset] = (chunk.length >> 24) & 0xFF;
      result[offset + 1] = (chunk.length >> 16) & 0xFF;
      result[offset + 2] = (chunk.length >> 8) & 0xFF;
      result[offset + 3] = chunk.length & 0xFF;
      offset += 4;
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return result;
  }

  /// Disassemble chunked ciphertext into individual chunks.
  (List<Uint8List>, int) _disassembleChunks(Uint8List data) {
    if (data.length < 8) {
      throw ArgumentError('Chunked ciphertext too short');
    }

    var offset = 4; // Skip magic bytes

    // Read chunk count
    final chunkCount = (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
    offset += 4;

    final chunks = <Uint8List>[];
    for (var i = 0; i < chunkCount; i++) {
      if (offset + 4 > data.length) {
        throw ArgumentError('Truncated chunked ciphertext at chunk $i');
      }

      final chunkLen = (data[offset] << 24) |
          (data[offset + 1] << 16) |
          (data[offset + 2] << 8) |
          data[offset + 3];
      offset += 4;

      if (offset + chunkLen > data.length) {
        throw ArgumentError(
          'Chunk $i declares $chunkLen bytes but only '
          '${data.length - offset} available',
        );
      }

      chunks.add(Uint8List.sublistView(data, offset, offset + chunkLen));
      offset += chunkLen;
    }

    return (chunks, chunkCount);
  }

  /// Derive a unique 12-byte IV for each chunk using HKDF.
  Future<Uint8List> _deriveChunkIv(
    Uint8List key,
    Uint8List baseIv,
    int chunkIndex,
  ) async {
    final info = Uint8List.fromList([
      ...utf8.encode('chunk'),
      (chunkIndex >> 24) & 0xFF,
      (chunkIndex >> 16) & 0xFF,
      (chunkIndex >> 8) & 0xFF,
      chunkIndex & 0xFF,
    ]);

    return _crypto.hkdfDerive(
      inputKeyMaterial: key,
      salt: baseIv,
      info: info,
      outputLength: 12,
    );
  }

  /// Build AAD (additional authenticated data) from the media hash.
  Uint8List _buildAad(String hexHash) {
    return Uint8List.fromList(utf8.encode('media:$hexHash'));
  }

  /// Build per-chunk AAD binding chunk index and total count.
  Uint8List _buildChunkAad(int chunkIndex, int totalChunks) {
    return Uint8List.fromList(utf8.encode('chunk:$chunkIndex/$totalChunks'));
  }

  // =========================================================================
  // HASHING
  // =========================================================================

  /// Compute SHA-256 hash of data, returned as lowercase hex string.
  Future<String> _computeSha256(Uint8List data) async {
    // Use HMAC-SHA256 with a fixed key as a SHA-256 substitute.
    // This is a practical approach since CryptoProvider exposes HMAC-SHA256
    // but not raw SHA-256, and HMAC-SHA256(fixedKey, data) is
    // a collision-resistant hash for integrity purposes.
    final fixedKey = Uint8List.fromList(
      utf8.encode('media-integrity-hash-key-v1\x00\x00\x00\x00\x00\x00'),
    );
    final hash = await _crypto.hmacSha256(fixedKey, data);
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Exception thrown when media integrity verification fails.
class MediaIntegrityException implements Exception {
  final String message;
  const MediaIntegrityException(this.message);

  @override
  String toString() => 'MediaIntegrityException: $message';
}
