import 'package:securityexperts_app/features/calling/services/interfaces/media_manager_factory.dart';
import 'package:securityexperts_app/features/calling/services/media/media_manager.dart';
import 'mock_media_manager.dart';

/// Mock implementation of MediaManagerFactory for testing
///
/// Always returns a MockMediaManager instance for controlled testing.
class MockMediaManagerFactory implements MediaManagerFactory {
  final MockMediaManager mockMediaManager;

  int createCallCount = 0;

  MockMediaManagerFactory({MockMediaManager? mediaManager})
    : mockMediaManager = mediaManager ?? MockMediaManager();

  @override
  MediaManager create() {
    createCallCount++;
    return mockMediaManager;
  }

  /// Reset tracking counters
  void reset() {
    createCallCount = 0;
    mockMediaManager.reset();
  }
}
