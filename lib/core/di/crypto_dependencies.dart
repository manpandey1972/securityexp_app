import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/native_crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/signal_protocol_engine.dart';
import 'package:securityexperts_app/core/crypto/web_crypto_provider.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/repositories/crypto/crypto_repositories.dart';
import 'package:securityexperts_app/features/chat/services/device_management_service.dart';
import 'package:securityexperts_app/features/chat/services/e2ee_initialization_service.dart';
import 'package:securityexperts_app/features/chat/services/encryption_service.dart';
import 'package:securityexperts_app/features/chat/services/identity_key_change_detector.dart';
import 'package:securityexperts_app/features/chat/services/key_backup_service.dart';
import 'package:securityexperts_app/features/chat/services/media_encryption_service.dart';
import 'package:securityexperts_app/features/chat/services/safety_number_service.dart';

/// Register all E2EE crypto services with the service locator.
///
/// Call this from [setupServiceLocator] after core services are registered.
///
/// Registration order:
/// 1. CryptoProvider (platform-specific: Native vs Web)
/// 2. SignalProtocolEngine
/// 3. Key repositories (KeyStore, Session, PreKey, Backup)
/// 4. EncryptionService (orchestrator)
/// 5. E2EE Initialization Service (device registration hook)
/// 6. Key Backup Service
/// 7. Safety Number Service
/// 8. Identity Key Change Detector
/// 9. Device Management Service
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
  // SIGNAL PROTOCOL ENGINE
  // ========================================

  sl.registerLazySingleton<SignalProtocolEngine>(
    () => SignalProtocolEngine(sl<CryptoProvider>()),
  );

  // ========================================
  // KEY STORE REPOSITORY — Platform-specific key storage
  // ========================================
  // Web: WebKeyStoreRepository (in-memory + AES-GCM encrypted)
  // Native: NativeKeyStoreRepository (iOS Keychain / Android Keystore)

  sl.registerLazySingleton<IKeyStoreRepository>(
    () => kIsWeb
        ? WebKeyStoreRepository(crypto: sl<CryptoProvider>())
        : NativeKeyStoreRepository(crypto: sl<CryptoProvider>()),
  );

  // ========================================
  // SESSION REPOSITORY — Platform-specific session persistence
  // ========================================
  // Web: WebSessionRepository (in-memory + AES-GCM encrypted)
  // Native: NativeSessionRepository (FlutterSecureStorage)

  sl.registerLazySingleton<ISessionRepository>(
    () => kIsWeb
        ? WebSessionRepository(crypto: sl<CryptoProvider>())
        : NativeSessionRepository(),
  );

  // ========================================
  // PREKEY REPOSITORY — Firestore CRUD for prekey bundles
  // ========================================

  sl.registerLazySingleton<PreKeyRepository>(
    () => PreKeyRepository(
      firestore: sl<FirebaseFirestore>(),
      keyStore: sl<IKeyStoreRepository>(),
      crypto: sl<CryptoProvider>(),
    ),
  );

  // ========================================
  // KEY BACKUP REPOSITORY — Cloud key backup
  // ========================================

  sl.registerLazySingleton<KeyBackupRepository>(
    () => KeyBackupRepository(
      functions: FirebaseFunctions.instance,
      crypto: sl<CryptoProvider>(),
    ),
  );

  // ========================================
  // ENCRYPTION SERVICE — Core orchestrator
  // ========================================

  sl.registerLazySingleton<EncryptionService>(
    () => EncryptionService(
      protocol: sl<SignalProtocolEngine>(),
      keyStore: sl<IKeyStoreRepository>(),
      sessionRepo: sl<ISessionRepository>(),
      preKeyRepo: sl<PreKeyRepository>(),
    ),
  );

  // ========================================
  // MEDIA ENCRYPTION SERVICE — Per-file AES-256-GCM
  // ========================================

  sl.registerLazySingleton<MediaEncryptionService>(
    () => MediaEncryptionService(
      crypto: sl<CryptoProvider>(),
    ),
  );

  // ========================================
  // E2EE INITIALIZATION SERVICE — Device registration hook
  // ========================================

  sl.registerLazySingleton<E2eeInitializationService>(
    () => E2eeInitializationService(
      keyStore: sl<IKeyStoreRepository>(),
      preKeyRepo: sl<PreKeyRepository>(),
      log: sl<AppLogger>(),
    ),
  );

  // ========================================
  // KEY BACKUP SERVICE — High-level backup/restore
  // ========================================

  sl.registerLazySingleton<KeyBackupService>(
    () => KeyBackupService(
      backupRepo: sl<KeyBackupRepository>(),
      keyStore: sl<IKeyStoreRepository>(),
      log: sl<AppLogger>(),
    ),
  );

  // ========================================
  // SAFETY NUMBER SERVICE — Verification management
  // ========================================

  sl.registerLazySingleton<SafetyNumberService>(
    () => SafetyNumberService(
      keyStore: sl<IKeyStoreRepository>(),
      preKeyRepo: sl<PreKeyRepository>(),
      log: sl<AppLogger>(),
    ),
  );

  // ========================================
  // IDENTITY KEY CHANGE DETECTOR — Key change monitoring
  // ========================================

  sl.registerLazySingleton<IdentityKeyChangeDetector>(
    () => IdentityKeyChangeDetector(
      keyStore: sl<IKeyStoreRepository>(),
      preKeyRepo: sl<PreKeyRepository>(),
      safetyNumberService: sl<SafetyNumberService>(),
      log: sl<AppLogger>(),
    ),
  );

  // ========================================
  // DEVICE MANAGEMENT SERVICE — Device CRUD
  // ========================================

  sl.registerLazySingleton<DeviceManagementService>(
    () => DeviceManagementService(
      preKeyRepo: sl<PreKeyRepository>(),
      keyStore: sl<IKeyStoreRepository>(),
      log: sl<AppLogger>(),
    ),
  );
}
