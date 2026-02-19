import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/calling/pages/call_controller.dart';
import 'package:greenhive_app/core/config/call_config.dart';
import 'package:greenhive_app/core/errors/call_error_handler.dart';

import '../../mocks/mock_signaling_service.dart';
import '../../mocks/mock_media_manager_factory.dart';
import '../../mocks/mock_call_logger.dart';
import '../../helpers/call_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallController - Outgoing Call', () {
    late MockSignalingService mockSignaling;
    late MockMediaManagerFactory mockMediaFactory;
    late MockCallLogger mockLogger;
    late CallConfig testConfig;
    late CallErrorHandler errorHandler;
    late DebugAppLogger debugAppLogger;
    CallController? controller;

    setUp(() {
      // Register AppLogger first
      if (sl.isRegistered<AppLogger>()) {
        sl.unregister<AppLogger>();
      }
      debugAppLogger = DebugAppLogger();
      sl.registerSingleton<AppLogger>(debugAppLogger);

      mockSignaling = MockSignalingService();
      mockMediaFactory = MockMediaManagerFactory();
      mockLogger = MockCallLogger();
      testConfig = createTestCallConfig();
      errorHandler = CallErrorHandler(mockLogger);
    });

    tearDown(() {
      controller?.dispose();
      controller = null;
      mockSignaling.dispose();
      mockMediaFactory.mockMediaManager.dispose();
      mockLogger.clear();
      if (sl.isRegistered<AppLogger>()) {
        sl.unregister<AppLogger>();
      }
    });

    test('initializes with correct initial state', () {
      controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: 'user-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      expect(controller!.callState, CallState.initial);
      expect(controller!.isCaller, true);
      expect(controller!.isVideo, true);
      expect(controller!.calleeId, 'user-123');
      expect(controller!.errorMessage, isNull);
      expect(controller!.durationSeconds.value, 0);
    });

    test('successfully starts outgoing call', () async {
      controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: 'user-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      // Verify state is connecting (waiting for callee)
      expect(controller!.callState, CallState.connecting);

      // Verify signaling was called
      expect(mockSignaling.startCallCount, 1);
      expect(mockSignaling.lastCalleeId, 'user-123');

      // Verify media manager was created and initialized
      expect(mockMediaFactory.createCallCount, 1);
      expect(mockMediaFactory.mockMediaManager.initializeCalled, true);
      expect(mockMediaFactory.mockMediaManager.connectCalled, true);

      // Verify logging
      expect(mockLogger.infoCount, greaterThan(0));
      expect(mockLogger.hasLogWithMessage('Starting call connection'), true);
    });

    test('transitions to connected when callee accepts', () async {
      controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: 'user-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();
      expect(controller!.callState, CallState.connecting);

      // Simulate callee accepting
      mockSignaling.simulateRemoteConnect();

      // Wait for state change
      await waitForCondition(
        () => controller!.callState == CallState.connected,
      );

      expect(controller!.callState, CallState.connected);
      expect(mockLogger.hasLogWithMessage('accepted'), true);
    });

    test('times out if callee does not answer', () async {
      final shortTimeoutConfig = createTestCallConfig(
        callTimeoutSeconds: 1, // 1 second timeout
      );

      controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: 'user-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: shortTimeoutConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();
      expect(controller!.callState, CallState.connecting);

      // Wait for timeout - give extra time for the timeout to complete
      await Future.delayed(const Duration(milliseconds: 1500));

      // Should transition to ended due to timeout
      expect(controller!.callState, CallState.ended);
      expect(controller!.errorMessage, contains('timed out'));
      expect(mockLogger.hasLogWithMessage('timeout'), true);
    });

    test('handles signaling error during connect', () async {
      mockSignaling.shouldFailStartCall = true;

      controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: 'user-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      expect(controller!.callState, CallState.failed);
      expect(controller!.errorMessage, isNotNull);
      expect(mockLogger.errorCount, greaterThan(0));
    });

    test('handles media initialization failure', () async {
      mockMediaFactory.mockMediaManager.shouldFailInitialize = true;

      controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: 'user-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      expect(controller!.callState, CallState.failed);
      expect(mockLogger.errorCount, greaterThan(0));
    });

    test('throws error when calleeId is missing', () async {
      controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: null, // Missing calleeId
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      expect(controller!.callState, CallState.failed);
      expect(controller!.errorMessage, isNotNull);
    });
  });

  group('CallController - Incoming Call', () {
    late MockSignalingService mockSignaling;
    late MockMediaManagerFactory mockMediaFactory;
    late MockCallLogger mockLogger;
    late CallConfig testConfig;
    late CallErrorHandler errorHandler;
    late DebugAppLogger debugAppLogger;
    CallController? controller;

    setUp(() {
      // Register AppLogger first
      if (sl.isRegistered<AppLogger>()) {
        sl.unregister<AppLogger>();
      }
      debugAppLogger = DebugAppLogger();
      sl.registerSingleton<AppLogger>(debugAppLogger);

      mockSignaling = MockSignalingService();
      mockMediaFactory = MockMediaManagerFactory();
      mockLogger = MockCallLogger();
      testConfig = createTestCallConfig();
      errorHandler = CallErrorHandler(mockLogger);
    });

    tearDown(() {
      controller?.dispose();
      controller = null;
      mockSignaling.dispose();
      mockMediaFactory.mockMediaManager.dispose();
      mockLogger.clear();
      if (sl.isRegistered<AppLogger>()) {
        sl.unregister<AppLogger>();
      }
    });

    test('successfully accepts incoming call', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'incoming-call-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      // Callee should immediately transition to connected
      expect(controller!.callState, CallState.connected);
      expect(mockSignaling.acceptCallCount, 1);
      expect(mockSignaling.lastAcceptedCallId, 'incoming-call-123');
      expect(mockMediaFactory.mockMediaManager.connectCalled, true);
    });

    test('throws error when callId is missing', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: null, // Missing callId
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      expect(controller!.callState, CallState.failed);
      expect(controller!.errorMessage, isNotNull);
    });
  });

  group('CallController - Call Actions', () {
    late MockSignalingService mockSignaling;
    late MockMediaManagerFactory mockMediaFactory;
    late MockCallLogger mockLogger;
    late CallConfig testConfig;
    late CallErrorHandler errorHandler;
    CallController? controller;

    setUp(() {
      mockSignaling = MockSignalingService();
      mockMediaFactory = MockMediaManagerFactory();
      mockLogger = MockCallLogger();
      testConfig = createTestCallConfig();
      errorHandler = CallErrorHandler(mockLogger);
    });

    tearDown(() {
      controller?.dispose();
      controller = null;
      mockSignaling.dispose();
      mockMediaFactory.mockMediaManager.dispose();
      mockLogger.clear();
    });

    test('toggleMute works correctly', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      expect(controller!.isMuted, false);

      await controller!.toggleMute();
      expect(controller!.isMuted, true);
      expect(mockMediaFactory.mockMediaManager.toggleMuteCount, 1);

      await controller!.toggleMute();
      expect(controller!.isMuted, false);
      expect(mockMediaFactory.mockMediaManager.toggleMuteCount, 2);
    });

    test('toggleVideo works correctly', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      expect(controller!.isVideoEnabled, true);

      await controller!.toggleVideo();
      expect(controller!.isVideoEnabled, false);
      expect(mockMediaFactory.mockMediaManager.toggleVideoCount, 1);
    });

    test('switchCamera is called', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      await controller!.switchCamera();
      expect(mockMediaFactory.mockMediaManager.switchCameraCount, 1);
    });

    test('toggleSpeaker works correctly', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      expect(controller!.isSpeakerOn, true);

      await controller!.toggleSpeaker();
      expect(controller!.isSpeakerOn, false);
      expect(mockMediaFactory.mockMediaManager.toggleSpeakerCount, 1);
    });

    test('endCall ends the call successfully', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();
      expect(controller!.callState, CallState.connected);

      await controller!.endCall();

      expect(controller!.callState, CallState.ended);
      expect(mockSignaling.endCallCount, 1);
      expect(mockMediaFactory.mockMediaManager.disconnectCalled, true);
    });

    test('endCall is idempotent', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      await controller!.endCall();
      await controller!.endCall();
      await controller!.endCall();

      // Should only end once
      expect(mockSignaling.endCallCount, 1);
    });
  });

  group('CallController - Resource Management', () {
    late MockSignalingService mockSignaling;
    late MockMediaManagerFactory mockMediaFactory;
    late MockCallLogger mockLogger;
    late CallConfig testConfig;
    late CallErrorHandler errorHandler;
    CallController? controller;

    setUp(() {
      mockSignaling = MockSignalingService();
      mockMediaFactory = MockMediaManagerFactory();
      mockLogger = MockCallLogger();
      testConfig = createTestCallConfig();
      errorHandler = CallErrorHandler(mockLogger);
    });

    tearDown(() {
      controller?.dispose();
      controller = null;
      mockSignaling.dispose();
      mockMediaFactory.mockMediaManager.dispose();
      mockLogger.clear();
    });

    test('properly disposes all resources', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();

      // Dispose controller
      controller!.dispose();
      controller = null;

      // Verify logging happened
      expect(mockLogger.hasLogWithMessage('Disposing'), true);

      // MediaManager should be disposed (checked via internal flag)
      expect(mockMediaFactory.mockMediaManager.disconnectCalled, false);
    });

    test('duration timer increments correctly', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();
      expect(controller!.callState, CallState.connected);
      expect(controller!.durationSeconds.value, 0);

      // Wait for duration to increment
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(controller!.durationSeconds.value, greaterThanOrEqualTo(1));
    });

    test('handles remote disconnect event', () async {
      controller = CallController(
        isCaller: false,
        isVideo: true,
        callId: 'test-call',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();
      expect(controller!.callState, CallState.connected);

      // Simulate remote ending the call
      mockSignaling.simulateRemoteEnd();

      // Wait for state change
      await waitForCondition(() => controller!.callState == CallState.ended);

      expect(controller!.callState, CallState.ended);
    });

    test('prevents double connect', () async {
      controller = CallController(
        isCaller: true,
        isVideo: true,
        calleeId: 'user-123',
        signaling: mockSignaling,
        mediaFactory: mockMediaFactory,
        logger: mockLogger,
        config: testConfig,
        errorHandler: errorHandler,
      );

      await controller!.connect();
      expect(mockSignaling.startCallCount, 1);

      // Try to connect again
      await controller!.connect();

      // Should not call startCall again
      expect(mockSignaling.startCallCount, 1);
      expect(mockLogger.hasLogWithMessage('Cannot connect'), true);
    });
  });
}
