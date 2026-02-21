import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/secure_random.dart' as app_random;

/// Mobile implementation of [CryptoProvider].
///
/// Uses the `cryptography` Dart package which delegates to platform-native
/// crypto implementations (CommonCrypto on iOS, BoringSSL on Android) via FFI
/// for maximum performance and hardware acceleration.
class NativeCryptoProvider implements CryptoProvider {
  final _x25519 = X25519();
  final _ed25519 = Ed25519();
  final _aesGcm = AesGcm.with256bits();
  final _hmac = Hmac.sha256();

  @override
  Future<CryptoKeyPair> generateX25519KeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    return CryptoKeyPair(
      publicKey: Uint8List.fromList(publicKey.bytes),
      privateKey: Uint8List.fromList(privateKeyBytes),
    );
  }

  @override
  Future<Uint8List> x25519Dh(
    Uint8List privateKey,
    Uint8List publicKey,
  ) async {
    final keyPair = SimpleKeyPairData(
      privateKey,
      publicKey: SimplePublicKey(publicKey, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );

    final remotePublicKey = SimplePublicKey(
      publicKey,
      type: KeyPairType.x25519,
    );

    final secret = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remotePublicKey,
    );

    return Uint8List.fromList(await secret.extractBytes());
  }

  @override
  Future<CryptoKeyPair> generateEd25519KeyPair() async {
    final keyPair = await _ed25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();

    // Ed25519 private key is the seed (32 bytes) in the cryptography package
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    return CryptoKeyPair(
      publicKey: Uint8List.fromList(publicKey.bytes),
      privateKey: Uint8List.fromList(privateKeyBytes),
    );
  }

  @override
  Future<Uint8List> ed25519Sign(
    Uint8List privateKey,
    Uint8List message,
  ) async {
    // Reconstruct key pair from private key bytes
    final keyPair = await _ed25519.newKeyPairFromSeed(privateKey);
    final signature = await _ed25519.sign(message, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  @override
  Future<bool> ed25519Verify(
    Uint8List publicKey,
    Uint8List message,
    Uint8List signature,
  ) async {
    final pub = SimplePublicKey(publicKey, type: KeyPairType.ed25519);
    final sig = Signature(signature, publicKey: pub);
    return _ed25519.verify(message, signature: sig);
  }

  @override
  Future<Uint8List> aesGcmEncrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List plaintext,
    Uint8List? aad,
  }) async {
    final secretKey = SecretKey(key);
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: iv,
      aad: aad ?? const <int>[],
    );

    // Combine ciphertext + MAC (GCM tag) into single byte array
    final result = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length);
    result.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    result.setRange(
      secretBox.cipherText.length,
      result.length,
      secretBox.mac.bytes,
    );
    return result;
  }

  @override
  Future<Uint8List> aesGcmDecrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List ciphertext,
    Uint8List? aad,
  }) async {
    // Split ciphertext into actual ciphertext + 16-byte MAC
    final macLength = 16;
    final ct = ciphertext.sublist(0, ciphertext.length - macLength);
    final mac = Mac(ciphertext.sublist(ciphertext.length - macLength));

    final secretBox = SecretBox(ct, nonce: iv, mac: mac);
    final secretKey = SecretKey(key);

    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: aad ?? const <int>[],
    );

    return Uint8List.fromList(plaintext);
  }

  @override
  Future<Uint8List> hkdfDerive({
    required Uint8List inputKeyMaterial,
    required Uint8List salt,
    required Uint8List info,
    required int outputLength,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: outputLength);
    final secretKey = SecretKey(inputKeyMaterial);
    final derivedKey = await hkdf.deriveKey(
      secretKey: secretKey,
      nonce: salt,
      info: info,
    );
    return Uint8List.fromList(await derivedKey.extractBytes());
  }

  @override
  Future<Uint8List> hmacSha256(Uint8List key, Uint8List data) async {
    final secretKey = SecretKey(key);
    final mac = await _hmac.calculateMac(data, secretKey: secretKey);
    return Uint8List.fromList(mac.bytes);
  }

  @override
  Uint8List secureRandomBytes(int length) {
    return app_random.SecureRandom.generateBytes(length);
  }
}
