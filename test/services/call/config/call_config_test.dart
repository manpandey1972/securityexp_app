import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/core/config/call_config.dart';
import 'package:greenhive_app/core/config/remote_config_service.dart';
import '../../../helpers/call_test_helpers.dart';

void main() {
  group('CallConfig', () {
    test('creates with default values from RemoteConfig', () {
      final config = createTestCallConfig();

      // Check that values come from mock remote config
      expect(config.callTimeout, const Duration(seconds: 1));
      expect(config.reconnectInterval, const Duration(seconds: 1));
      expect(config.maxReconnectAttempts, 3);
      expect(config.retryInitialDelay, const Duration(seconds: 2));
      expect(config.retryBackoffMultiplier, 2.0);
      expect(config.maxRetryAttempts, 2);
      expect(config.enableDebugLogging, false); // logLevel != 'debug'
      expect(config.enableQualityMonitoring, true);
    });

    test('creates with custom RemoteConfig values', () {
      final config = createTestCallConfig(
        callTimeoutSeconds: 60,
        connectionTimeoutSeconds: 10,
        maxSetupRetries: 5,
      );

      expect(config.callTimeout, const Duration(seconds: 60));
      expect(config.reconnectInterval, const Duration(seconds: 10));
      expect(config.maxRetryAttempts, 5);
    });

    test('quality monitoring is enabled by default', () {
      final config = createTestCallConfig();
      expect(config.enableQualityMonitoring, true);
    });

    test('debug logging depends on logLevel', () {
      final debugConfig = CallConfig(
        remoteConfig:
            MockRemoteConfigService(logLevel: 'debug') as RemoteConfigService,
      );
      expect(debugConfig.enableDebugLogging, true);

      final infoConfig = CallConfig(
        remoteConfig:
            MockRemoteConfigService(logLevel: 'info') as RemoteConfigService,
      );
      expect(infoConfig.enableDebugLogging, false);
    });
  });
}
