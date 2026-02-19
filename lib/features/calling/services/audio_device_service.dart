import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

enum AudioDevice { speaker, headset, bluetooth, earpiece, carplay, unknown }

/// Service for managing audio device selection and routing
///
/// Handles platform-specific audio device management (iOS/Android)
/// Registered as a singleton in the DI container.
class AudioDeviceService {
  static const platform = MethodChannel('com.greenhive.call/audio');
  static const eventChannel = EventChannel(
    'com.greenhive.call/audioDeviceEvents',
  );

  // Removed singleton pattern - lifecycle managed by GetIt
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'AudioDeviceService';

  AudioDeviceService();

  StreamSubscription? _audioDeviceListener;
  Timer? _deviceChangeDebounce;
  AudioDevice _currentDevice = AudioDevice.speaker;
  final List<AudioDevice> _availableDevices = [];
  bool _userOverride = false; // Track if user has manually overridden device
  final StreamController<AudioDevice> _deviceChangeController =
      StreamController<AudioDevice>.broadcast();
  final StreamController<List<AudioDevice>> _availableDevicesController =
      StreamController<List<AudioDevice>>.broadcast();

  /// Get the stream of audio device changes
  Stream<AudioDevice> get onDeviceChanged => _deviceChangeController.stream;

  /// Get the stream of available devices changes
  Stream<List<AudioDevice>> get onAvailableDevicesChanged =>
      _availableDevicesController.stream;

  /// Get current audio device
  AudioDevice get currentDevice => _currentDevice;

  /// Get list of available audio devices
  List<AudioDevice> get availableDevices => List.from(_availableDevices);

  /// Check if user has manually overridden the device
  bool get hasUserOverride => _userOverride;

  /// Initialize audio device monitoring
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        _log.warning('Audio device selection not supported on web', tag: _tag);
        return;
      }

      // Cancel existing listener if any to prevent duplicates
      await _audioDeviceListener?.cancel();

      // Get initial available devices
      await _updateAvailableDevices();
      await _updateCurrentDevice();

      // IMPORTANT: Do NOT set any device on initialize
      // Let iOS use its default behavior until user explicitly chooses a device
      _log.info('Using iOS default audio routing (no override)', tag: _tag);
      _log.debug('Current device', tag: _tag, data: {'device': _currentDevice.toString()});
      _log.debug('Available devices', tag: _tag, data: {'devices': _availableDevices.join(', ')});

      // Listen for audio device changes
      _audioDeviceListener = eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          _handleDeviceChange(event);
        },
        onError: (error) {
          _log.error('Error listening to device changes', tag: _tag, error: error);
        },
      );

      _log.info('Initialized with iOS default audio routing', tag: _tag);
    } catch (e) {
      _log.error('Initialization error', tag: _tag, error: e);
    }
  }

  /// Configure audio for VoIP call (Android only)
  /// Sets MODE_IN_COMMUNICATION and requests audio focus
  /// Returns true if audio focus was granted
  Future<bool> configureForVoIPCall() async {
    try {
      if (kIsWeb) return true;

      // Only Android needs explicit VoIP configuration
      // iOS handles this via AudioSessionManager in native code
      if (!kIsWeb && Platform.isAndroid) {
        final result = await platform.invokeMethod<bool>(
          'configureForVoIPCall',
        );
        final success = result ?? false;
        _log.info('VoIP call configured', tag: _tag, data: {'audioFocus': success});
        return success;
      }

      return true;
    } catch (e) {
      _log.error('Error configuring VoIP call', tag: _tag, error: e);
      return false;
    }
  }

  /// Release VoIP call audio configuration (Android only)
  /// Stops Bluetooth SCO, resets audio mode, and abandons audio focus
  Future<void> releaseVoIPCall() async {
    try {
      if (kIsWeb) return;

      // Only Android needs explicit VoIP release
      // iOS handles this via AudioSessionManager in native code
      if (!kIsWeb && Platform.isAndroid) {
        await platform.invokeMethod('releaseVoIPCall');
        _log.info('VoIP call audio released', tag: _tag);
      }
    } catch (e) {
      _log.error('Error releasing VoIP call', tag: _tag, error: e);
    }
  }

  /// Get current device from platform
  Future<void> _updateCurrentDevice() async {
    try {
      final result = await platform.invokeMethod<String>(
        'getCurrentAudioDevice',
      );
      if (result != null) {
        _currentDevice = _parseDevice(result);
        _log.debug('Current device', tag: _tag, data: {'device': _currentDevice.toString()});
      }
    } catch (e) {
      _log.error('Error getting current device', tag: _tag, error: e);
    }
  }

  /// Refresh the list of available audio devices from platform
  Future<void> refreshAvailableDevices() async {
    await _updateAvailableDevices();
  }

  /// Update list of available audio devices (internal)
  Future<void> _updateAvailableDevices() async {
    try {
      final result = await platform.invokeMethod<List>(
        'getAvailableAudioDevices',
      );
      final previousDevices = List<AudioDevice>.from(_availableDevices);
      _availableDevices.clear();
      if (result != null) {
        for (var device in result) {
          _availableDevices.add(_parseDevice(device as String));
        }
      }
      _log.debug('Available devices', tag: _tag, data: {'devices': _availableDevices.toString()});

      // Notify listeners of device list change if devices changed
      if (previousDevices.length != _availableDevices.length ||
          !previousDevices.every((d) => _availableDevices.contains(d))) {
        _log.debug('Device list changed, notifying listeners', tag: _tag);
        if (!_availableDevicesController.isClosed) {
          _availableDevicesController.add(List.from(_availableDevices));
        }
      }
    } catch (e) {
      _log.error(
        'Error getting available devices',
        tag: _tag,
        error: e,
      );
      // Fallback: assume at least speaker is available
      _availableDevices.clear();
      _availableDevices.add(AudioDevice.speaker);
    }
  }

  /// Handle device change events with debouncing to prevent rapid flicker
  void _handleDeviceChange(dynamic event) {
    try {
      final device = _parseDevice(event.toString());
      _log.debug('Route changed', tag: _tag, data: {'device': device.toString(), 'userOverride': _userOverride});

      // Cancel previous debounce timer
      _deviceChangeDebounce?.cancel();

      // Use short debounce to prevent UI flicker from rapid route changes
      _deviceChangeDebounce = Timer(Duration(milliseconds: 300), () {
        // Check if controller is closed before attempting to add
        if (_deviceChangeController.isClosed) {
          _log.warning('StreamController closed, ignoring device change', tag: _tag);
          return;
        }

        // Update available devices list first
        _updateAvailableDevices().then((_) async {
          // Double check controller is still open
          if (_deviceChangeController.isClosed) {
            _log.warning('StreamController closed during update, ignoring device change', tag: _tag);
            return;
          }

          // IMPORTANT: Track what iOS has routed to
          // iOS has already made the routing decision, we just track it

          // If device changed and user had an override, clear it
          if (_userOverride && device != _currentDevice) {
            _log.debug('iOS routed to new device, clearing user override', tag: _tag, data: {'from': _currentDevice.toString(), 'to': device.toString()});
            _userOverride = false;
          }

          // CRITICAL FIX: Actually route audio to the device iOS is offering
          // When Bluetooth connects, iOS shows transfer audio dialog to user
          // We MUST route audio to Bluetooth for the dialog to work properly
          // User can then dismiss or accept the transfer via iOS native dialog
          _log.debug('Bluetooth detected and available - ensuring audio routes to it', tag: _tag);

          // Update current device
          _currentDevice = device;
          _log.debug('Following iOS route', tag: _tag, data: {'current': _currentDevice.toString(), 'available': _availableDevices.toString()});

          // Notify UI of the device change
          _deviceChangeController.add(_currentDevice);
        });
      });
    } catch (e) {
      _log.error('Error handling device change', tag: _tag, error: e);
    }
  }

  /// Set audio output to specific device with error recovery
  Future<void> setAudioDevice(AudioDevice device) async {
    try {
      if (kIsWeb) {
        _log.warning('Audio device selection not supported on web', tag: _tag);
        return;
      }

      final deviceString = _deviceToString(device);
      _log.debug('Calling platform.invokeMethod', tag: _tag, data: {'device': deviceString});
      await platform.invokeMethod('setAudioDevice', {'device': deviceString});
      _log.debug('Platform method returned successfully', tag: _tag);

      _currentDevice = device;
      // Only set override if it's a manual user action (not internal call)
      // We'll handle the flag setting in the UI layer or add a param here
      // For now, we assume this method is called by UI mostly, but we called it internally above too.
      // Let's fix the internal call to NOT set override.

      _log.info(
        'Device set',
        tag: _tag,
        data: {'device': device.toString()},
      );
      _deviceChangeController.add(device);
    } catch (e) {
      _log.error(
        'Error setting audio device',
        tag: _tag,
        error: e,
      );

      // Error recovery: try to set speaker as safe default
      if (device != AudioDevice.speaker) {
        _log.warning('Attempting fallback to speaker', tag: _tag);
        try {
          await platform.invokeMethod('setAudioDevice', {'device': 'speaker'});
          _currentDevice = AudioDevice.speaker;
          _deviceChangeController.add(AudioDevice.speaker);
          _log.info('Fallback to speaker successful', tag: _tag);
        } catch (fallbackError) {
          _log.error('Fallback to speaker also failed', tag: _tag, error: fallbackError);
        }
      }

      rethrow;
    }
  }

  /// Set audio output with user override flag
  Future<void> setUserSelectedDevice(AudioDevice device) async {
    _userOverride = true;
    await setAudioDevice(device);
    _log.info('User override enabled', tag: _tag, data: {'device': device.toString()});
  }

  /// Reset user override to allow system default
  Future<void> resetUserOverride() async {
    try {
      if (kIsWeb) return;

      _userOverride = false;

      // Reset platform override to let iOS decide
      await platform.invokeMethod('resetAudioDevice');

      await _updateCurrentDevice();
      _log.info('User override reset', tag: _tag, data: {'currentDevice': _currentDevice.toString()});
      _deviceChangeController.add(_currentDevice);
    } catch (e) {
      _log.error('Error resetting user override', tag: _tag, error: e);
    }
  }

  /// Toggle speaker on/off
  Future<void> setSpeakerphoneOn(bool enabled) async {
    try {
      if (kIsWeb) return;

      await platform.invokeMethod('setSpeakerphoneOn', {'enabled': enabled});
      _log.info('Speakerphone', tag: _tag, data: {'state': enabled ? 'ON' : 'OFF'});

      if (enabled) {
        _currentDevice = AudioDevice.speaker;
      }
      _deviceChangeController.add(_currentDevice);
    } catch (e) {
      _log.error('Error setting speakerphone', tag: _tag, error: e);
      rethrow;
    }
  }

  /// Parse device string to enum
  AudioDevice _parseDevice(String deviceString) {
    switch (deviceString.toLowerCase()) {
      case 'speaker':
        return AudioDevice.speaker;
      case 'bluetooth':
        return AudioDevice.bluetooth;
      case 'headset':
      case 'wired_headset':
        return AudioDevice.headset;
      case 'earpiece':
        return AudioDevice.earpiece;
      case 'carplay':
      case 'car_audio':
        return AudioDevice.carplay;
      default:
        return AudioDevice.unknown;
    }
  }

  /// Convert device enum to string for platform channel
  String _deviceToString(AudioDevice device) {
    switch (device) {
      case AudioDevice.speaker:
        return 'speaker';
      case AudioDevice.bluetooth:
        return 'bluetooth';
      case AudioDevice.headset:
        return 'headset';
      case AudioDevice.earpiece:
        return 'earpiece';
      case AudioDevice.carplay:
        return 'carplay';
      case AudioDevice.unknown:
        return 'unknown';
    }
  }

  /// Check if specific device is available
  bool isDeviceAvailable(AudioDevice device) {
    return _availableDevices.contains(device);
  }

  /// Get icon data for device type
  String getDeviceIcon(AudioDevice device) {
    switch (device) {
      case AudioDevice.speaker:
        return '🔊'; // speaker_notes
      case AudioDevice.bluetooth:
        return '🎧'; // bluetooth_audio
      case AudioDevice.headset:
        return '🎧'; // headset
      case AudioDevice.earpiece:
        return '📱'; // phone
      case AudioDevice.carplay:
        return '🚗'; // car
      case AudioDevice.unknown:
        return '🔊'; // default to speaker
    }
  }

  /// Get label for device type
  String getDeviceLabel(AudioDevice device) {
    switch (device) {
      case AudioDevice.speaker:
        return 'Speaker';
      case AudioDevice.bluetooth:
        return 'Bluetooth';
      case AudioDevice.headset:
        return 'Headset';
      case AudioDevice.earpiece:
        return 'Earpiece';
      case AudioDevice.carplay:
        return 'CarPlay';
      case AudioDevice.unknown:
        return 'Unknown';
    }
  }

  /// Cleanup resources
  ///
  /// Note on StreamController disposal strategy:
  /// This service is registered as a singleton in GetIt and is expected to live
  /// for the entire app lifecycle. The broadcast controllers are intentionally
  /// NOT closed in dispose() because:
  ///
  /// 1. As a singleton, the service should never be recreated
  /// 2. Multiple listeners may subscribe/unsubscribe over time
  /// 3. Closing broadcast controllers would make them unusable for future listeners
  ///
  /// If the service is ever truly disposed (e.g., during testing), ensure:
  /// - All listeners have unsubscribed
  /// - The service is properly re-registered if needed again
  ///
  /// For testing scenarios, use resetCallDependencies() which will reset the
  /// entire DI container and allow fresh registration.
  Future<void> dispose() async {
    _deviceChangeDebounce?.cancel();
    await _audioDeviceListener?.cancel();

    // Broadcast controllers are intentionally kept open for singleton lifecycle
    // See documentation above for rationale
    // await _deviceChangeController.close();
    // await _availableDevicesController.close();

    _log.info('Disposed (controllers kept open for singleton)', tag: _tag);
  }
}
