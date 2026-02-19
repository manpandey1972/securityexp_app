import 'package:securityexperts_app/features/calling/services/media/media_manager.dart';
import 'package:securityexperts_app/features/calling/services/media/livekit_media_manager.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/room_service.dart';
import 'package:securityexperts_app/features/calling/services/audio_device_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Factory interface for creating MediaManager instances
///
/// This abstraction allows for easy testing and provider switching.
abstract class MediaManagerFactory {
  /// Creates a MediaManager instance
  MediaManager create();
}

/// Default implementation of MediaManagerFactory
///
/// Creates actual MediaManager instances for production use.
/// Uses dependency injection to provide required services.
class DefaultMediaManagerFactory implements MediaManagerFactory {
  @override
  MediaManager create() {
    // All calls use LiveKit
    return LiveKitMediaManager(
      roomService: sl<RoomService>(),
      audioService: sl<AudioDeviceService>(),
    );
  }
}
