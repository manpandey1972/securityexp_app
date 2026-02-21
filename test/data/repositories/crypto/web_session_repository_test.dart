import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/web_crypto_provider.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/repositories/crypto/web_session_repository.dart';

void main() {
  late WebSessionRepository sessionRepo;
  late WebCryptoProvider crypto;

  setUp(() {
    crypto = WebCryptoProvider();
    sessionRepo = WebSessionRepository(crypto: crypto);
  });

  /// Create a minimal valid SessionState for testing.
  SessionState createTestSession({
    required String remoteUserId,
    required String remoteDeviceId,
    DateTime? lastActive,
  }) {
    return SessionState(
      remoteUserId: remoteUserId,
      remoteDeviceId: remoteDeviceId,
      dhPrivateKey: Uint8List.fromList(List.generate(32, (i) => i)),
      dhPublicKey: Uint8List.fromList(List.generate(32, (i) => i + 32)),
      remoteDhPublicKey: Uint8List.fromList(List.generate(32, (i) => i + 64)),
      rootKey: Uint8List.fromList(List.generate(32, (i) => i + 96)),
      sendingChainKey: Uint8List.fromList(List.generate(32, (i) => i + 128)),
      receivingChainKey: Uint8List.fromList(List.generate(32, (i) => i + 160)),
      sendMessageNumber: 0,
      receiveMessageNumber: 0,
      previousSendingChainLength: 0,
      lastActive: lastActive ?? DateTime.now(),
      skippedMessageKeys: const {},
      remoteIdentityKey: Uint8List.fromList(List.generate(32, (i) => i + 192)),
    );
  }

  group('WebSessionRepository - Save and Get', () {
    test('should save and retrieve a session', () async {
      final session = createTestSession(
        remoteUserId: 'user_a',
        remoteDeviceId: 'device_1',
      );

      await sessionRepo.saveSession(session);
      final retrieved = await sessionRepo.getSession('user_a', 'device_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.remoteUserId, 'user_a');
      expect(retrieved.remoteDeviceId, 'device_1');
      expect(retrieved.rootKey, equals(session.rootKey));
    });

    test('should return null for non-existent session', () async {
      final result = await sessionRepo.getSession('nobody', 'none');
      expect(result, isNull);
    });

    test('should overwrite existing session', () async {
      final session1 = createTestSession(
        remoteUserId: 'user_a',
        remoteDeviceId: 'device_1',
      );

      await sessionRepo.saveSession(session1);

      // Update with new root key
      final session2 = SessionState(
        remoteUserId: 'user_a',
        remoteDeviceId: 'device_1',
        dhPrivateKey: session1.dhPrivateKey,
        dhPublicKey: session1.dhPublicKey,
        remoteDhPublicKey: session1.remoteDhPublicKey,
        rootKey: Uint8List.fromList(List.generate(32, (i) => 255 - i)),
        sendingChainKey: session1.sendingChainKey,
        receivingChainKey: session1.receivingChainKey,
        sendMessageNumber: 1,
        receiveMessageNumber: 0,
        previousSendingChainLength: 0,
        lastActive: DateTime.now(),
        skippedMessageKeys: const {},
        remoteIdentityKey: session1.remoteIdentityKey,
      );

      await sessionRepo.saveSession(session2);
      final retrieved = await sessionRepo.getSession('user_a', 'device_1');

      expect(retrieved!.sendMessageNumber, 1);
    });
  });

  group('WebSessionRepository - Get Sessions For User', () {
    test('should get all sessions for a user', () async {
      final s1 = createTestSession(
        remoteUserId: 'user_a',
        remoteDeviceId: 'device_1',
      );
      final s2 = createTestSession(
        remoteUserId: 'user_a',
        remoteDeviceId: 'device_2',
      );
      final s3 = createTestSession(
        remoteUserId: 'user_b',
        remoteDeviceId: 'device_1',
      );

      await sessionRepo.saveSession(s1);
      await sessionRepo.saveSession(s2);
      await sessionRepo.saveSession(s3);

      final userASessions = await sessionRepo.getSessionsForUser('user_a');
      expect(userASessions.length, 2);

      final userBSessions = await sessionRepo.getSessionsForUser('user_b');
      expect(userBSessions.length, 1);
    });

    test('should return empty list for user with no sessions', () async {
      final sessions = await sessionRepo.getSessionsForUser('nobody');
      expect(sessions, isEmpty);
    });
  });

  group('WebSessionRepository - Delete', () {
    test('should delete a specific session', () async {
      final session = createTestSession(
        remoteUserId: 'user_a',
        remoteDeviceId: 'device_1',
      );

      await sessionRepo.saveSession(session);
      await sessionRepo.deleteSession('user_a', 'device_1');

      final result = await sessionRepo.getSession('user_a', 'device_1');
      expect(result, isNull);
    });

    test('should delete all sessions for a user', () async {
      final s1 = createTestSession(
        remoteUserId: 'user_a',
        remoteDeviceId: 'device_1',
      );
      final s2 = createTestSession(
        remoteUserId: 'user_a',
        remoteDeviceId: 'device_2',
      );

      await sessionRepo.saveSession(s1);
      await sessionRepo.saveSession(s2);
      await sessionRepo.deleteSessionsForUser('user_a');

      final sessions = await sessionRepo.getSessionsForUser('user_a');
      expect(sessions, isEmpty);
    });
  });

  group('WebSessionRepository - Clear All', () {
    test('should clear all sessions', () async {
      final s1 = createTestSession(
        remoteUserId: 'user_a',
        remoteDeviceId: 'device_1',
      );
      final s2 = createTestSession(
        remoteUserId: 'user_b',
        remoteDeviceId: 'device_1',
      );

      await sessionRepo.saveSession(s1);
      await sessionRepo.saveSession(s2);

      await sessionRepo.clearAll();

      final a = await sessionRepo.getSessionsForUser('user_a');
      final b = await sessionRepo.getSessionsForUser('user_b');
      expect(a, isEmpty);
      expect(b, isEmpty);
    });
  });
}
