import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

// Conditional import - dart:html and dart:js only imported on web

/// Service to manage call ringtone sounds using Web Audio API on web and audioplayers on native
class RingtoneService {
  static const platform = MethodChannel('com.example.securityexpertsApp.call/ringtone');
  static final RingtoneService _instance = RingtoneService._internal();
  static const String _tag = 'RingtoneService';

  late AudioPlayer _audioPlayer;
  bool _isRinging = false;
  bool _ringtoneSupported = true;
  // ...existing code...

  RingtoneService._internal() {
    _audioPlayer = AudioPlayer();
    // Don't initialize on constructor, do it lazily on first use
  }

  factory RingtoneService() {
    return _instance;
  }

  /// Start playing the ringtone
  Future<void> startRingtone() async {
    if (_isRinging) {
      return;
    }

    try {
      // Ensure previous playback is completely stopped before starting new one
      try {
        await _audioPlayer.stop();
      } catch (_) {
        // Ignore
      }

      _isRinging = true;
      if (kIsWeb) {
        return;
      } else {
        await _startNativeRingtone();
      }
    } catch (_) {
      _isRinging = false;
    }
  }

  // ...existing code...

  /// Call a JavaScript function from Dart
  dynamic _callJsFunction(String functionName) {
    return null;
  }

  /// Start ringtone using audioplayers (native platforms)
  Future<void> _startNativeRingtone() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS: Use native AVAudioPlayer via MethodChannel to share AVAudioSession correctly with WebRTC
        // This avoids audioplayers package resetting the session category/mode and breaking camera input
        try {
          await platform.invokeMethod('play', {
            'assetPath': 'assets/sounds/ringtone1.mp3',
          });
        } catch (_) {
          _isRinging = false;
        }
        return;
      }

      // Android: Configure AudioContext to use PlayAndRecord
      // This ensures we don't switch the Audio Session category away from what WebRTC needs
      // Default audioplayers behavior switches to 'Playback' which kills camera capture on iOS
      final AudioContext audioContext = AudioContext(
        iOS: AudioContextIOS(
          // Kept for reference or non-iOS fallback if ever needed
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.allowBluetoothA2DP,
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.voiceCommunicationSignalling,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      );

      await _audioPlayer.setAudioContext(audioContext);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      await _audioPlayer.play(
        AssetSource('sounds/ringtone1.mp3', mimeType: 'audio/mpeg'),
        volume: 1.0,
      );
    } catch (e, stackTrace) {
      sl<AppLogger>().error('Error starting native ringtone', error: e, stackTrace: stackTrace, tag: _tag);
      _isRinging = false;
      _ringtoneSupported = false;
    }
  }

  /// Stop playing the ringtone
  Future<void> stopRingtone() async {
    if (!_isRinging) {
      return;
    }

    try {
      if (kIsWeb) {
        _stopWebRingtone();
      } else {
        await _stopNativeRingtone();
      }

      _isRinging = false;
    } catch (_) {
      _isRinging = false; // Force reset flag even if error
    }
  }

  /// Stop web ringtone
  void _stopWebRingtone() {
    try {
      _callJsFunction('stopWebRingtone');
    } catch (e, _) {
      sl<AppLogger>().warning('Error stopping web ringtone: $e', tag: _tag);
    }
  }

  /// Stop native ringtone (audioplayers)
  Future<void> _stopNativeRingtone() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await platform.invokeMethod('stop');
        return;
      }
      await _audioPlayer.stop();
    } catch (e, _) {
      sl<AppLogger>().warning('Error stopping native ringtone: $e', tag: _tag);
    }
  }

  /// Check if ringtone is currently playing
  bool get isRinging => _isRinging;

  /// Check if ringtone is supported on this platform
  bool get isSupported => _ringtoneSupported;

  /// Dispose resources
  Future<void> dispose() async {
    await stopRingtone();
    if (!kIsWeb) {
      await _audioPlayer.dispose();
    }
  }
}
