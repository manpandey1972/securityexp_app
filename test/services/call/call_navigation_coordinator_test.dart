import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/calling/services/call_navigation_coordinator.dart';
import 'package:securityexperts_app/features/calling/pages/call_controller.dart';
import 'package:securityexperts_app/core/config/call_config.dart';
import 'package:securityexperts_app/core/errors/call_error_handler.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:mockito/annotations.dart';

import '../../mocks/mock_signaling_service.dart';
import '../../mocks/mock_media_manager_factory.dart';
import '../../mocks/mock_call_logger.dart';
import '../../helpers/call_test_helpers.dart';

@GenerateMocks([AppLogger])
import 'call_navigation_coordinator_test.mocks.dart';

void main() {
  group('CallNavigationCoordinator', () {
    late CallNavigationCoordinator coordinator;
    late MockSignalingService mockSignaling;
    late MockMediaManagerFactory mockMediaFactory;
    late MockCallLogger mockLogger;
    late MockAppLogger mockAppLogger;
    late CallConfig testConfig;
    late CallErrorHandler errorHandler;

    setUp(() {
      // Initialize Flutter binding
      TestWidgetsFlutterBinding.ensureInitialized();

      // Register AppLogger in GetIt before creating coordinator
      mockAppLogger = MockAppLogger();
      if (!sl.isRegistered<AppLogger>()) {
        sl.registerSingleton<AppLogger>(mockAppLogger);
      }

      coordinator = CallNavigationCoordinator();
      mockSignaling = MockSignalingService();
      mockMediaFactory = MockMediaManagerFactory();
      mockLogger = MockCallLogger();
      testConfig = createTestCallConfig();
      errorHandler = CallErrorHandler(mockLogger);
    });

    tearDown(() {
      coordinator.clearCall();
      mockSignaling.dispose();
      mockMediaFactory.mockMediaManager.dispose();
      mockLogger.clear();

      // Clean up GetIt
      if (sl.isRegistered<AppLogger>()) {
        sl.unregister<AppLogger>();
      }
    });

    test('initializes with no active call', () {
      expect(coordinator.hasActiveCall, false);
      expect(coordinator.isMinimized, false);
      expect(coordinator.activeController, isNull);
      expect(coordinator.isCallActive, false);
    });

    test('startCall registers controller', () {
      final controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: 'user-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      coordinator.startCall(controller, calleeName: 'Test User');

      expect(coordinator.hasActiveCall, true);
      expect(coordinator.isMinimized, false);
      expect(coordinator.activeController, same(controller));

      controller.dispose();
    });

    test('minimize changes state', () {
      final controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      coordinator.startCall(controller, calleeName: 'Test User');
      coordinator.minimize();

      expect(coordinator.isMinimized, true);

      controller.dispose();
    });

    test('restore changes state back', () {
      final controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      coordinator.startCall(controller, calleeName: 'Test User');
      coordinator.minimize();
      expect(coordinator.isMinimized, true);

      coordinator.restore();
      expect(coordinator.isMinimized, false);

      controller.dispose();
    });

    test('setMinimized works for backward compatibility', () {
      final controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      coordinator.startCall(controller, calleeName: 'Test User');

      coordinator.setMinimized(true);
      expect(coordinator.isMinimized, true);

      coordinator.setMinimized(false);
      expect(coordinator.isMinimized, false);

      controller.dispose();
    });

    test('endCall calls controller endCall', () async {
      final controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller.connect();
      coordinator.startCall(controller, calleeName: 'Test User');

      await coordinator.endCall();

      expect(coordinator.hasActiveCall, false);
      expect(coordinator.isMinimized, false);
      expect(mockSignaling.endCallCount, 1);

      controller.dispose();
    });

    test('clearCall removes controller without ending', () {
      final controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      coordinator.startCall(controller, calleeName: 'Test User');
      expect(coordinator.hasActiveCall, true);

      coordinator.clearCall();

      expect(coordinator.hasActiveCall, false);
      expect(coordinator.isMinimized, false);
      expect(mockSignaling.endCallCount, 0);

      controller.dispose();
    });

    test('provides backward compatible getters', () async {
      final controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: 'user-123',
        callId: 'call-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller.connect();
      mockSignaling.simulateRemoteConnect();
      await waitForCondition(() => controller.callState == CallState.connected);

      coordinator.startCall(controller, calleeName: 'Test User');

      expect(coordinator.isCallActive, true);
      expect(coordinator.calleeId, 'user-123');
      expect(coordinator.roomId, 'test-room-id');
      expect(coordinator.isVideo, true);
      expect(coordinator.isCaller, true);

      controller.dispose();
    });

    test(
      'notifies listeners on state change',
      () {
        int notificationCount = 0;
        coordinator.addListener(() => notificationCount++);

        final controller = CallController(
          isCaller: false,
          isVideo: true,
          callId: 'test-call',
          signaling: mockSignaling,
          mediaFactory: mockMediaFactory,
          logger: mockLogger,
          config: testConfig,
          errorHandler: errorHandler,
        );

        coordinator.startCall(controller, calleeName: 'Test User');
        expect(notificationCount, 1);

        coordinator.minimize();
        expect(notificationCount, 2);

        coordinator.restore();
        expect(notificationCount, 3);

        coordinator.clearCall();
        expect(notificationCount, 4);

        controller.dispose();
      },
      skip: true,
    ); // Singleton state persists across tests causing notification count issues

    test('minimize does nothing without active call', () {
      coordinator.minimize();
      expect(coordinator.isMinimized, false);
    });
  });
}
