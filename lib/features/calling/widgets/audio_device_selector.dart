import 'dart:async';

import 'package:flutter/material.dart';

import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import '../services/audio_device_service.dart';

/// A bottom sheet widget for selecting audio output devices.
///
/// Shows all available audio devices with their names and icons,
/// highlighting the currently active device.
class AudioDeviceSelector extends StatefulWidget {
  /// The audio device service to use
  final AudioDeviceService audioDeviceService;

  /// Callback when a device is selected
  final ValueChanged<AudioDevice>? onDeviceSelected;

  /// Whether to auto-dismiss after selection
  final bool autoDismiss;

  const AudioDeviceSelector({
    super.key,
    required this.audioDeviceService,
    this.onDeviceSelected,
    this.autoDismiss = true,
  });

  /// Show the audio device selector as a bottom sheet
  static Future<AudioDevice?> show(
    BuildContext context, {
    required AudioDeviceService audioDeviceService,
    ValueChanged<AudioDevice>? onDeviceSelected,
  }) {
    return showModalBottomSheet<AudioDevice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AudioDeviceSelector(
        audioDeviceService: audioDeviceService,
        onDeviceSelected: onDeviceSelected,
      ),
    );
  }

  @override
  State<AudioDeviceSelector> createState() => _AudioDeviceSelectorState();
}

class _AudioDeviceSelectorState extends State<AudioDeviceSelector> {
  late AudioDevice _currentDevice;
  late List<AudioDevice> _availableDevices;
  StreamSubscription? _deviceChangeSubscription;
  StreamSubscription? _availableDevicesSubscription;

  @override
  void initState() {
    super.initState();
    _currentDevice = widget.audioDeviceService.currentDevice;
    _availableDevices = widget.audioDeviceService.availableDevices;

    // Refresh available devices
    widget.audioDeviceService.refreshAvailableDevices();

    // Listen for device changes
    _deviceChangeSubscription = widget.audioDeviceService.onDeviceChanged
        .listen((device) {
          if (mounted) {
            setState(() {
              _currentDevice = device;
            });
          }
        });

    _availableDevicesSubscription = widget
        .audioDeviceService
        .onAvailableDevicesChanged
        .listen((devices) {
          if (mounted) {
            setState(() {
              _availableDevices = devices;
            });
          }
        });
  }

  @override
  void dispose() {
    _deviceChangeSubscription?.cancel();
    _availableDevicesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _selectDevice(AudioDevice device) async {
    await widget.audioDeviceService.setUserSelectedDevice(device);
    widget.onDeviceSelected?.call(device);

    if (widget.autoDismiss && mounted) {
      Navigator.of(context).pop(device);
    }
  }

  IconData _getDeviceIcon(AudioDevice device) {
    switch (device) {
      case AudioDevice.speaker:
        return Icons.volume_up;
      case AudioDevice.earpiece:
        return Icons.phone_android;
      case AudioDevice.bluetooth:
        return Icons.bluetooth_audio;
      case AudioDevice.headset:
        return Icons.headset;
      case AudioDevice.carplay:
        return Icons.directions_car;
      case AudioDevice.unknown:
        return Icons.volume_up;
    }
  }

  String _getDeviceLabel(AudioDevice device) {
    return widget.audioDeviceService.getDeviceLabel(device);
  }

  Color _getDeviceColor(AudioDevice device) {
    if (device == _currentDevice) {
      return Theme.of(context).colorScheme.primary;
    }
    return AppColors.white.withValues(alpha: 0.7);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Audio Output',
                style: AppTypography.bodyEmphasis.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),

            // Device list
            ..._availableDevices.map((device) => _buildDeviceTile(device)),

            // Bottom padding
            SizedBox(height: bottomPadding + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(AudioDevice device) {
    final isSelected = device == _currentDevice;
    final color = _getDeviceColor(device);

    return InkWell(
      onTap: () => _selectDevice(device),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          children: [
            // Device icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(_getDeviceIcon(device), color: color, size: 22),
            ),

            const SizedBox(width: 16),

            // Device name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDeviceLabel(device),
                    style: AppTypography.bodyRegular.copyWith(
                      color: color,
                      fontWeight: isSelected
                          ? AppTypography.semiBold
                          : AppTypography.regular,
                    ),
                  ),
                  if (device == AudioDevice.bluetooth)
                    Text(
                      'Connected',
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            // Checkmark for selected
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: AppIconSizes.standard,
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact audio device button for the call screen.
///
/// Shows the current device icon and opens the selector on tap.
class AudioDeviceButton extends StatefulWidget {
  final AudioDeviceService audioDeviceService;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const AudioDeviceButton({
    super.key,
    required this.audioDeviceService,
    this.size = 48,
    this.color,
    this.backgroundColor,
  });

  @override
  State<AudioDeviceButton> createState() => _AudioDeviceButtonState();
}

class _AudioDeviceButtonState extends State<AudioDeviceButton> {
  late AudioDevice _currentDevice;
  StreamSubscription? _deviceChangeSubscription;

  @override
  void initState() {
    super.initState();
    _currentDevice = widget.audioDeviceService.currentDevice;

    _deviceChangeSubscription = widget.audioDeviceService.onDeviceChanged
        .listen((device) {
          if (mounted) {
            setState(() {
              _currentDevice = device;
            });
          }
        });
  }

  @override
  void dispose() {
    _deviceChangeSubscription?.cancel();
    super.dispose();
  }

  IconData _getDeviceIcon() {
    switch (_currentDevice) {
      case AudioDevice.speaker:
        return Icons.volume_up;
      case AudioDevice.earpiece:
        return Icons.phone_android;
      case AudioDevice.bluetooth:
        return Icons.bluetooth_audio;
      case AudioDevice.headset:
        return Icons.headset;
      case AudioDevice.carplay:
        return Icons.directions_car;
      case AudioDevice.unknown:
        return Icons.volume_up;
    }
  }

  void _showDeviceSelector() {
    AudioDeviceSelector.show(
      context,
      audioDeviceService: widget.audioDeviceService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showDeviceSelector,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? AppColors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getDeviceIcon(),
          color: widget.color ?? AppColors.white,
          size: widget.size * 0.5,
        ),
      ),
    );
  }
}
