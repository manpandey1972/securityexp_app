import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/shared/services/event_bus.dart';

void main() {
  group('EventBus', () {
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
    });

    test('should create singleton instance', () {
      final instance1 = EventBus();
      final instance2 = EventBus();
      expect(instance1, same(instance2));
    });

    group('Profile Update Events', () {
      test('should emit profile updated event', () async {
        var eventReceived = false;

        eventBus.onProfileUpdated.listen((_) {
          eventReceived = true;
        });

        eventBus.emitProfileUpdated();
        await Future.delayed(Duration.zero); // Allow event to propagate

        expect(eventReceived, true);
      });

      test('should notify multiple subscribers', () async {
        var subscriber1Called = false;
        var subscriber2Called = false;

        eventBus.onProfileUpdated.listen((_) => subscriber1Called = true);
        eventBus.onProfileUpdated.listen((_) => subscriber2Called = true);

        eventBus.emitProfileUpdated();
        await Future.delayed(Duration.zero); // Allow event to propagate

        expect(subscriber1Called, true);
        expect(subscriber2Called, true);
      });

      test('should emit multiple events', () async {
        var eventCount = 0;

        eventBus.onProfileUpdated.listen((_) {
          eventCount++;
        });

        eventBus.emitProfileUpdated();
        eventBus.emitProfileUpdated();
        eventBus.emitProfileUpdated();
        await Future.delayed(Duration.zero); // Allow events to propagate

        expect(eventCount, 3);
      });
    });

    group('Subscription Management', () {
      test(
        'should stop receiving events after canceling subscription',
        () async {
          var eventCount = 0;

          final subscription = eventBus.onProfileUpdated.listen((_) {
            eventCount++;
          });

          eventBus.emitProfileUpdated();
          await Future.delayed(Duration.zero);
          await subscription.cancel();
          eventBus.emitProfileUpdated();
          await Future.delayed(Duration.zero);

          expect(eventCount, 1);
        },
      );

      test('should handle multiple subscriptions independently', () async {
        var events1Count = 0;
        var events2Count = 0;

        final sub1 = eventBus.onProfileUpdated.listen((_) => events1Count++);
        eventBus.onProfileUpdated.listen((_) => events2Count++);

        eventBus.emitProfileUpdated();
        await Future.delayed(Duration.zero);
        await sub1.cancel();
        eventBus.emitProfileUpdated();
        await Future.delayed(Duration.zero);

        expect(events1Count, 1);
        expect(events2Count, 2);
      });
    });

    group('Stream Behavior', () {
      test('should handle rapid event emission', () async {
        var eventCount = 0;

        eventBus.onProfileUpdated.listen((_) {
          eventCount++;
        });

        for (var i = 0; i < 10; i++) {
          eventBus.emitProfileUpdated();
        }
        await Future.delayed(Duration.zero); // Allow events to propagate

        expect(eventCount, 10);
      });

      test('should not buffer events before subscription', () async {
        eventBus.emitProfileUpdated();

        var eventCount = 0;
        eventBus.onProfileUpdated.listen((_) {
          eventCount++;
        });

        eventBus.emitProfileUpdated();
        await Future.delayed(Duration.zero); // Allow event to propagate

        expect(eventCount, 1);
      });

      test('should support broadcast stream', () {
        // Verify multiple subscriptions work (broadcast behavior)
        final subscription1 = eventBus.onProfileUpdated.listen((_) {});
        final subscription2 = eventBus.onProfileUpdated.listen((_) {});

        expect(subscription1, isNotNull);
        expect(subscription2, isNotNull);

        subscription1.cancel();
        subscription2.cancel();
      });
    });

    group('Lifecycle', () {
      test('should dispose cleanly', () {
        eventBus.dispose();
        expect(true, true); // Dispose should not throw
      });
    });
  });
}
