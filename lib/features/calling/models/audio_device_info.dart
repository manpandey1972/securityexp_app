import 'package:flutter/material.dart';

/// Detailed information about an audio device
class AudioDeviceInfo {
  /// Unique identifier for the device
  final String id;

  /// Display name of the device (e.g., "AirPods Pro", "Speaker")
  final String name;

  /// Type of audio device
  final AudioDeviceType type;

  /// Whether this device is currently active
  final bool isActive;

  /// Whether this device supports input (microphone)
  final bool hasInput;

  /// Whether this device supports output (audio playback)
  final bool hasOutput;

  const AudioDeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = false,
    this.hasInput = true,
    this.hasOutput = true,
  });

  factory AudioDeviceInfo.fromMap(Map<String, dynamic> map) {
    return AudioDeviceInfo(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown Device',
      type: AudioDeviceType.fromString(map['type'] as String? ?? 'unknown'),
      isActive: map['isActive'] as bool? ?? false,
      hasInput: map['hasInput'] as bool? ?? true,
      hasOutput: map['hasOutput'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.value,
      'isActive': isActive,
      'hasInput': hasInput,
      'hasOutput': hasOutput,
    };
  }

  AudioDeviceInfo copyWith({
    String? id,
    String? name,
    AudioDeviceType? type,
    bool? isActive,
    bool? hasInput,
    bool? hasOutput,
  }) {
    return AudioDeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      hasInput: hasInput ?? this.hasInput,
      hasOutput: hasOutput ?? this.hasOutput,
    );
  }

  /// Get the icon for this device type
  IconData get icon => type.icon;

  /// Get a simple display label (falls back to type label if name is generic)
  String get displayName {
    if (name.isEmpty || name == 'Unknown Device') {
      return type.label;
    }
    return name;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioDeviceInfo &&
        other.id == id &&
        other.name == name &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, name, type);

  @override
  String toString() {
    return 'AudioDeviceInfo(id: $id, name: $name, type: $type, isActive: $isActive)';
  }
}

/// Types of audio devices
enum AudioDeviceType {
  speaker('speaker'),
  earpiece('earpiece'),
  bluetooth('bluetooth'),
  wiredHeadset('headset'),
  bluetoothA2dp('bluetooth_a2dp'),
  bluetoothHfp('bluetooth_hfp'),
  bluetoothLe('bluetooth_le'),
  carPlay('carplay'),
  airPlay('airplay'),
  unknown('unknown');

  final String value;

  const AudioDeviceType(this.value);

  factory AudioDeviceType.fromString(String value) {
    switch (value.toLowerCase()) {
      case 'speaker':
        return AudioDeviceType.speaker;
      case 'earpiece':
        return AudioDeviceType.earpiece;
      case 'bluetooth':
        return AudioDeviceType.bluetooth;
      case 'headset':
      case 'wired_headset':
        return AudioDeviceType.wiredHeadset;
      case 'bluetooth_a2dp':
        return AudioDeviceType.bluetoothA2dp;
      case 'bluetooth_hfp':
        return AudioDeviceType.bluetoothHfp;
      case 'bluetooth_le':
        return AudioDeviceType.bluetoothLe;
      case 'carplay':
        return AudioDeviceType.carPlay;
      case 'airplay':
        return AudioDeviceType.airPlay;
      default:
        return AudioDeviceType.unknown;
    }
  }

  /// Whether this is a Bluetooth device type
  bool get isBluetooth {
    switch (this) {
      case AudioDeviceType.bluetooth:
      case AudioDeviceType.bluetoothA2dp:
      case AudioDeviceType.bluetoothHfp:
      case AudioDeviceType.bluetoothLe:
        return true;
      default:
        return false;
    }
  }

  /// Whether this is an external device (not built into the phone)
  bool get isExternal {
    switch (this) {
      case AudioDeviceType.speaker:
      case AudioDeviceType.earpiece:
        return false;
      default:
        return true;
    }
  }

  /// Get the display label for this device type
  String get label {
    switch (this) {
      case AudioDeviceType.speaker:
        return 'Speaker';
      case AudioDeviceType.earpiece:
        return 'iPhone';
      case AudioDeviceType.bluetooth:
        return 'Bluetooth';
      case AudioDeviceType.wiredHeadset:
        return 'Headphones';
      case AudioDeviceType.bluetoothA2dp:
        return 'Bluetooth Audio';
      case AudioDeviceType.bluetoothHfp:
        return 'Bluetooth Headset';
      case AudioDeviceType.bluetoothLe:
        return 'Bluetooth LE';
      case AudioDeviceType.carPlay:
        return 'CarPlay';
      case AudioDeviceType.airPlay:
        return 'AirPlay';
      case AudioDeviceType.unknown:
        return 'Unknown';
    }
  }

  /// Get the icon for this device type
  IconData get icon {
    switch (this) {
      case AudioDeviceType.speaker:
        return Icons.volume_up;
      case AudioDeviceType.earpiece:
        return Icons.phone_android;
      case AudioDeviceType.bluetooth:
      case AudioDeviceType.bluetoothA2dp:
      case AudioDeviceType.bluetoothHfp:
      case AudioDeviceType.bluetoothLe:
        return Icons.bluetooth_audio;
      case AudioDeviceType.wiredHeadset:
        return Icons.headset;
      case AudioDeviceType.carPlay:
        return Icons.directions_car;
      case AudioDeviceType.airPlay:
        return Icons.airplay;
      case AudioDeviceType.unknown:
        return Icons.volume_up;
    }
  }
}
