import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Represents a long-term X25519 identity key pair for E2EE.
///
/// Each device generates exactly one identity key pair during E2EE registration.
/// The public key is shared with other users via Firestore PreKeyBundles.
/// The private key is stored in the platform-native secure keystore.
class IdentityKeyPair extends Equatable {
  /// X25519 public key (32 bytes).
  final Uint8List publicKey;

  /// X25519 private key (32 bytes). Only accessible on the owning device.
  final Uint8List privateKey;

  /// Ed25519 signing public key (32 bytes) for identity attestation.
  final Uint8List signingPublicKey;

  /// Ed25519 signing private key (64 bytes).
  final Uint8List signingPrivateKey;

  /// Unique registration ID for this device (uint32).
  final int registrationId;

  const IdentityKeyPair({
    required this.publicKey,
    required this.privateKey,
    required this.signingPublicKey,
    required this.signingPrivateKey,
    required this.registrationId,
  });

  /// Serialize identity key pair for secure storage.
  Map<String, String> toSecureStorage() {
    return {
      'publicKey': base64Encode(publicKey),
      'privateKey': base64Encode(privateKey),
      'signingPublicKey': base64Encode(signingPublicKey),
      'signingPrivateKey': base64Encode(signingPrivateKey),
      'registrationId': registrationId.toString(),
    };
  }

  /// Deserialize identity key pair from secure storage.
  factory IdentityKeyPair.fromSecureStorage(Map<String, String> data) {
    return IdentityKeyPair(
      publicKey: base64Decode(data['publicKey']!),
      privateKey: base64Decode(data['privateKey']!),
      signingPublicKey: base64Decode(data['signingPublicKey']!),
      signingPrivateKey: base64Decode(data['signingPrivateKey']!),
      registrationId: int.parse(data['registrationId']!),
    );
  }

  /// Serialize to JSON for Firestore (public parts only).
  Map<String, dynamic> toPublicJson() {
    return {
      'identity_key': base64Encode(publicKey),
      'signing_key': base64Encode(signingPublicKey),
      'registration_id': registrationId,
    };
  }

  @override
  List<Object?> get props => [
        publicKey,
        privateKey,
        signingPublicKey,
        signingPrivateKey,
        registrationId,
      ];
}
