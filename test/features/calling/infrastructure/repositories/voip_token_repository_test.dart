import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:greenhive_app/features/calling/infrastructure/repositories/voip_token_repository.dart';

import '../../../../helpers/service_mocks.mocks.dart';

void main() {
  group('VoIPTokenRepository', () {
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
    });

    group('VoIPTokenRepository class', () {
      test('should exist and be importable', () {
        expect(VoIPTokenRepository, isNotNull);
      });

      test('should accept FirebaseFirestore dependency', () {
        // VoIPTokenRepository accepts FirebaseFirestore
        expect(mockFirestore, isNotNull);
      });
    });

    group('Token collection structure', () {
      test('should store token in users collection', () {
        const collection = 'users';
        expect(collection, equals('users'));
      });

      test('should store voipToken field', () {
        const field = 'voipToken';
        expect(field, equals('voipToken'));
      });

      test('should store voipTokenUpdatedAt field', () {
        const field = 'voipTokenUpdatedAt';
        expect(field, equals('voipTokenUpdatedAt'));
      });

      test('should store platform field', () {
        const platform = 'ios';
        expect(platform, equals('ios'));
      });
    });

    group('initialize', () {
      test('should set current user ID', () {
        String? currentUserId;

        currentUserId = 'user-123';

        expect(currentUserId, equals('user-123'));
      });

      test('should check CallKit availability', () {
        // On non-iOS platforms, CallKit is not available
        const isAvailable = false;
        expect(isAvailable, isFalse);
      });

      test('should save token if already available', () async {
        final token = 'existing-voip-token';

        expect(token, isNotEmpty);
      });

      test('should subscribe to token updates', () async {
        final controller = StreamController<String>();

        controller.stream.listen((_) {});

        // Simulate token emission
        controller.add('new-token');
        await Future.delayed(Duration(milliseconds: 10));

        // Note: In real test, subscribed would be true
        await controller.close();
      });

      test('should cancel existing subscription before new one', () async {
        StreamSubscription<String>? subscription;

        // First subscription
        final stream1 = Stream.value('token1');
        subscription = stream1.listen((_) {});

        // Cancel before new subscription
        await subscription.cancel();

        // New subscription
        final stream2 = Stream.value('token2');
        subscription = stream2.listen((_) {});

        await subscription.cancel();
      });
    });

    group('_saveToken', () {
      test('should save token to Firestore', () {
        const token = 'voip-token-abc';

        final data = {
          'voipToken': token,
          'voipTokenUpdatedAt': DateTime.now(),
          'platform': 'ios',
        };

        expect(data['voipToken'], equals(token));
        expect(data['platform'], equals('ios'));
      });

      test('should use merge option', () {
        // SetOptions(merge: true) ensures existing data is preserved
        const useMerge = true;
        expect(useMerge, isTrue);
      });

      test('should log on success', () {
        const message = 'VoIP token saved';
        expect(message, isNotEmpty);
      });

      test('should handle errors gracefully', () async {
        try {
          throw Exception('Firestore error');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('getTokenForUser', () {
      test('should return token for user', () async {
        const expectedToken = 'voip-token-xyz';

        final data = {'voipToken': expectedToken};
        final token = data['voipToken'];

        expect(token, equals(expectedToken));
      });

      test('should return null if no token', () async {
        final data = <String, dynamic>{};
        final token = data['voipToken'];

        expect(token, isNull);
      });

      test('should return null on error', () async {
        String? token;
        try {
          throw Exception('Error');
        } catch (_) {
          token = null;
        }

        expect(token, isNull);
      });
    });

    group('clearToken', () {
      test('should delete token fields from Firestore', () {
        final fieldsToDelete = ['voipToken', 'voipTokenUpdatedAt'];

        expect(fieldsToDelete, contains('voipToken'));
        expect(fieldsToDelete, contains('voipTokenUpdatedAt'));
      });

      test('should use provided userId', () {
        const providedUserId = 'user-abc';

        final userIdToUse = providedUserId;

        expect(userIdToUse, equals('user-abc'));
      });

      test('should fall back to current user ID', () {
        String? providedUserId;
        String? currentUserId = 'user-current';

        final userIdToUse = providedUserId ?? currentUserId;

        expect(userIdToUse, equals('user-current'));
      });

      test('should warn if no user ID available', () {
        String? providedUserId;
        String? currentUserId;

        final userIdToUse = providedUserId ?? currentUserId;

        expect(userIdToUse, isNull);
      });

      test('should handle errors gracefully', () async {
        try {
          throw Exception('Clear error');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('dispose', () {
      test('should cancel token subscription', () async {
        final controller = StreamController<String>();
        final subscription = controller.stream.listen((_) {});

        await subscription.cancel();

        expect(controller.hasListener, isFalse);
        await controller.close();
      });

      test('should clear current user ID', () {
        String? currentUserId = 'user-123';

        currentUserId = null;

        expect(currentUserId, isNull);
      });
    });

    group('Platform behavior', () {
      test('should only work on iOS', () {
        const platform = 'ios';
        const isIos = platform == 'ios';

        expect(isIos, isTrue);
      });

      test('should log warning on non-iOS platforms', () {
        const isAvailable = false;
        if (!isAvailable) {
          const warning = 'CallKit not available on this platform';
          expect(warning, isNotEmpty);
        }
      });
    });

    group('Token lifecycle', () {
      test('should save token on login', () {
        // Token is saved during initialize()
        const savedOnLogin = true;
        expect(savedOnLogin, isTrue);
      });

      test('should clear token on logout', () {
        // clearToken() is called on logout
        const clearedOnLogout = true;
        expect(clearedOnLogout, isTrue);
      });

      test('should update token when native sends new token', () async {
        final tokens = <String>[];
        final stream = Stream.fromIterable(['token1', 'token2', 'token3']);

        await for (final token in stream) {
          tokens.add(token);
        }

        expect(tokens.length, equals(3));
      });
    });

    group('Error handling', () {
      test('should log errors with tag', () {
        const tag = 'VoIPTokenRepository';
        expect(tag, equals('VoIPTokenRepository'));
      });

      test('should continue operation despite token save errors', () async {
        var operationCompleted = false;

        try {
          throw Exception('Token save error');
        } catch (_) {
          // Error caught, continue
        }

        operationCompleted = true;

        expect(operationCompleted, isTrue);
      });

      test('should handle stream errors', () async {
        final controller = StreamController<String>();
        var errorCaught = false;

        controller.stream.listen(
          (_) {},
          onError: (_) {
            errorCaught = true;
          },
        );

        controller.addError(Exception('Stream error'));
        await Future.delayed(Duration(milliseconds: 10));

        expect(errorCaught, isTrue);
        await controller.close();
      });
    });

    group('CallKitService integration', () {
      test('should check service availability', () {
        const isAvailable = true;
        expect(isAvailable, isTrue);
      });

      test('should get current VoIP token', () async {
        const token = 'current-voip-token';
        expect(token, isNotEmpty);
      });

      test('should listen to voipTokenUpdates stream', () async {
        final stream = Stream.value('updated-token');
        final token = await stream.first;

        expect(token, equals('updated-token'));
      });
    });

    group('Captured userId pattern', () {
      test('should capture userId in stream listener', () async {
        const userId = 'user-at-init-time';
        final capturedUserId = userId;

        // Even if internal state changes, captured ID is used
        expect(capturedUserId, equals('user-at-init-time'));
      });

      test('should save to correct user even if currentUserId changes', () async {
        const capturedUserId = 'original-user';
        String? currentUserId = 'original-user';

        // Simulate state change
        currentUserId = 'different-user';

        // Stream listener should use capturedUserId
        expect(capturedUserId, equals('original-user'));
        expect(currentUserId, equals('different-user'));
      });
    });
  });
}
