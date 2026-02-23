import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/native_crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/web_crypto_provider.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/features/chat/services/encryption_service.dart';
import 'package:securityexperts_app/features/chat/services/media_encryption_service.dart';
import 'package:securityexperts_app/features/chat/services/room_key_service.dart';

/// Register all E2EE crypto services with the service locator.
///
/// Call this from [setupServiceLocator] after core services are registered.
///
/// Registration order (v3 — KMS-protected per-room keys):
/// 1. CryptoProvider (platform-specific: Native vs Web)
/// 2. RoomKeyService (Cloud Function client + in-memory cache)
/// 3. EncryptionService (AES-256-GCM using room keys)
/// 4. MediaEncryptionService (per-file AES-256-GCM — unchanged)
void registerCryptoServices(GetIt sl) {
  // ========================================
  // CRYPTO PROVIDER — Platform-specific implementation
  // ========================================
  // Web: WebCryptoProvider (cryptography package with DartCryptography/BrowserCrypto)
  // Native: NativeCryptoProvider (cryptography package with platform FFI)

  sl.registerLazySingleton<CryptoProvider>(
    () => kIsWeb ? WebCryptoProvider() : NativeCryptoProvider(),
  );

  // ========================================
  // ROOM KEY SERVICE — Cloud Function client + in-memory cache
  // ========================================

  sl.registerLazySingleton<RoomKeyService>(
    () => RoomKeyService(
      functions: FirebaseFunctions.instance,
      logger: sl<AppLogger>(),
    ),
  );

  // ========================================
  // ENCRYPTION SERVICE — Per-room AES-256-GCM
  // ========================================

  sl.registerLazySingleton<EncryptionService>(
    () => EncryptionService(
      roomKeyService: sl<RoomKeyService>(),
      crypto: sl<CryptoProvider>(),
    ),
  );

  // ========================================
  // MEDIA ENCRYPTION SERVICE — Per-file AES-256-GCM (unchanged)
  // ========================================

  sl.registerLazySingleton<MediaEncryptionService>(
    () => MediaEncryptionService(
      crypto: sl<CryptoProvider>(),
    ),
  );
}
