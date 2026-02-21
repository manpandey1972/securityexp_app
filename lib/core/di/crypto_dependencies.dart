import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get_it/get_it.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/native_crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/signal_protocol_engine.dart';
import 'package:securityexperts_app/data/repositories/crypto/crypto_repositories.dart';
import 'package:securityexperts_app/features/chat/services/encryption_service.dart';

/// Register all E2EE crypto services with the service locator.
///
/// Call this from [setupServiceLocator] after core services are registered.
///
/// Registration order:
/// 1. CryptoProvider (platform-specific)
/// 2. SignalProtocolEngine
/// 3. Key repositories (KeyStore, Session, PreKey, Backup)
/// 4. EncryptionService (orchestrator)
void registerCryptoServices(GetIt sl) {
  // ========================================
  // CRYPTO PROVIDER — Platform-specific implementation
  // ========================================

  sl.registerLazySingleton<CryptoProvider>(
    () => NativeCryptoProvider(),
  );

  // ========================================
  // SIGNAL PROTOCOL ENGINE
  // ========================================

  sl.registerLazySingleton<SignalProtocolEngine>(
    () => SignalProtocolEngine(sl<CryptoProvider>()),
  );

  // ========================================
  // KEY STORE REPOSITORY — Platform keychain integration
  // ========================================

  sl.registerLazySingleton<IKeyStoreRepository>(
    () => NativeKeyStoreRepository(crypto: sl<CryptoProvider>()),
  );

  // ========================================
  // SESSION REPOSITORY — Encrypted session persistence
  // ========================================

  sl.registerLazySingleton<ISessionRepository>(
    () => NativeSessionRepository(),
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
}
