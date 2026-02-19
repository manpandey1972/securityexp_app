import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/models/device_context.dart';

/// Service for capturing device and application information.
///
/// Used to automatically populate support ticket device context
/// for debugging and troubleshooting purposes.
class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  PackageInfo? _cachedPackageInfo;

  /// Capture current device context for support tickets.
  ///
  /// Returns a [DeviceContext] populated with:
  /// - Platform (iOS, Android, web, etc.)
  /// - OS version
  /// - App version and build number
  /// - Device model
  /// - Locale and timezone
  /// - Screen size
  Future<DeviceContext> captureDeviceContext() async {
    try {
      final packageInfo = await _getPackageInfo();

      String platform;
      String osVersion;
      String deviceModel;

      if (kIsWeb) {
        platform = 'web';
        final webInfo = await _deviceInfo.webBrowserInfo;
        osVersion = webInfo.browserName.name;
        deviceModel = webInfo.platform ?? 'Unknown';
      } else if (Platform.isIOS) {
        platform = 'iOS';
        final iosInfo = await _deviceInfo.iosInfo;
        osVersion = iosInfo.systemVersion;
        deviceModel = iosInfo.utsname.machine;
      } else if (Platform.isAndroid) {
        platform = 'Android';
        final androidInfo = await _deviceInfo.androidInfo;
        osVersion =
            'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isMacOS) {
        platform = 'macOS';
        final macInfo = await _deviceInfo.macOsInfo;
        osVersion =
            '${macInfo.majorVersion}.${macInfo.minorVersion}.${macInfo.patchVersion}';
        deviceModel = macInfo.model;
      } else if (Platform.isWindows) {
        platform = 'Windows';
        final windowsInfo = await _deviceInfo.windowsInfo;
        osVersion =
            'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
        deviceModel = windowsInfo.computerName;
      } else if (Platform.isLinux) {
        platform = 'Linux';
        final linuxInfo = await _deviceInfo.linuxInfo;
        osVersion = linuxInfo.version ?? 'Unknown';
        deviceModel = linuxInfo.prettyName;
      } else {
        platform = 'Unknown';
        osVersion = 'Unknown';
        deviceModel = 'Unknown';
      }

      // Get screen size from the first window (if available)
      String? screenSize;
      try {
        final view = PlatformDispatcher.instance.implicitView;
        if (view != null) {
          final size = view.physicalSize / view.devicePixelRatio;
          screenSize = '${size.width.toInt()}x${size.height.toInt()}';
        }
      } catch (e) {
        // Screen size not available
      }

      return DeviceContext(
        platform: platform,
        osVersion: osVersion,
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        deviceModel: deviceModel,
        locale: PlatformDispatcher.instance.locale.toString(),
        timezone: DateTime.now().timeZoneName,
        screenSize: screenSize,
      );
    } catch (e) {
      // Return minimal context if capture fails
      return DeviceContext(
        platform: _getPlatformName(),
        osVersion: 'Unknown',
        appVersion: 'Unknown',
        buildNumber: 'Unknown',
        deviceModel: 'Unknown',
        locale: PlatformDispatcher.instance.locale.toString(),
        timezone: DateTime.now().timeZoneName,
      );
    }
  }

  /// Get cached or fresh package info.
  Future<PackageInfo> _getPackageInfo() async {
    _cachedPackageInfo ??= await PackageInfo.fromPlatform();
    return _cachedPackageInfo!;
  }

  /// Get current platform name.
  String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Get app version string (e.g., "1.2.3+45").
  Future<String> getAppVersionString() async {
    final info = await _getPackageInfo();
    return '${info.version}+${info.buildNumber}';
  }

  /// Get detailed device info as a formatted string.
  ///
  /// Useful for display in app settings or support pages.
  Future<String> getFormattedDeviceInfo() async {
    final context = await captureDeviceContext();
    final buffer = StringBuffer();

    buffer.writeln('Platform: ${context.platform}');
    buffer.writeln('OS Version: ${context.osVersion}');
    buffer.writeln(
      'App Version: ${context.appVersion} (${context.buildNumber})',
    );
    buffer.writeln('Device: ${context.deviceModel}');
    buffer.writeln('Locale: ${context.locale}');
    buffer.writeln('Timezone: ${context.timezone}');
    if (context.screenSize != null) {
      buffer.writeln('Screen: ${context.screenSize}');
    }

    return buffer.toString().trimRight();
  }
}
