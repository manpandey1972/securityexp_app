import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device and app context information captured for support tickets.
///
/// This helps the support team debug issues by providing
/// context about the user's device and app version.
class DeviceContext {
  /// Platform name (iOS, Android, Web)
  final String platform;

  /// Operating system version
  final String osVersion;

  /// App version string (e.g., "2.4.1")
  final String appVersion;

  /// App build number
  final String buildNumber;

  /// Device model name (e.g., "iPhone 15 Pro")
  final String? deviceModel;

  /// User's locale (e.g., "en_US")
  final String locale;

  /// User's timezone
  final String timezone;

  /// Screen size in pixels (e.g., "393x852")
  final String? screenSize;

  const DeviceContext({
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.buildNumber,
    this.deviceModel,
    required this.locale,
    required this.timezone,
    this.screenSize,
  });

  /// Capture the current device context.
  ///
  /// This collects device information, app version, and other
  /// relevant context for debugging support tickets.
  static Future<DeviceContext> capture() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String platform;
    String osVersion;
    String? deviceModel;

    if (kIsWeb) {
      platform = 'Web';
      final webInfo = await deviceInfo.webBrowserInfo;
      osVersion = webInfo.browserName.name;
      deviceModel = webInfo.platform;
    } else if (Platform.isIOS) {
      platform = 'iOS';
      final iosInfo = await deviceInfo.iosInfo;
      osVersion = iosInfo.systemVersion;
      deviceModel = iosInfo.model;
    } else if (Platform.isAndroid) {
      platform = 'Android';
      final androidInfo = await deviceInfo.androidInfo;
      osVersion = androidInfo.version.release;
      deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isMacOS) {
      platform = 'macOS';
      final macInfo = await deviceInfo.macOsInfo;
      osVersion = macInfo.osRelease;
      deviceModel = macInfo.model;
    } else if (Platform.isWindows) {
      platform = 'Windows';
      final windowsInfo = await deviceInfo.windowsInfo;
      osVersion = windowsInfo.productName;
      deviceModel = null;
    } else if (Platform.isLinux) {
      platform = 'Linux';
      final linuxInfo = await deviceInfo.linuxInfo;
      osVersion = linuxInfo.prettyName;
      deviceModel = null;
    } else {
      platform = 'Unknown';
      osVersion = 'Unknown';
      deviceModel = null;
    }

    String? screenSize;
    try {
      final view = PlatformDispatcher.instance.views.first;
      final size = view.physicalSize;
      screenSize = '${size.width.toInt()}x${size.height.toInt()}';
    } catch (_) {
      screenSize = null;
    }

    return DeviceContext(
      platform: platform,
      osVersion: osVersion,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      deviceModel: deviceModel,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
      screenSize: screenSize,
    );
  }

  /// Create a DeviceContext from a Firestore document
  factory DeviceContext.fromJson(Map<String, dynamic> json) {
    return DeviceContext(
      platform: json['platform'] as String? ?? 'Unknown',
      osVersion: json['osVersion'] as String? ?? 'Unknown',
      appVersion: json['appVersion'] as String? ?? 'Unknown',
      buildNumber: json['buildNumber'] as String? ?? '0',
      deviceModel: json['deviceModel'] as String?,
      locale: json['locale'] as String? ?? 'en_US',
      timezone: json['timezone'] as String? ?? 'UTC',
      screenSize: json['screenSize'] as String?,
    );
  }

  /// Convert to a Firestore-compatible map
  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'deviceModel': deviceModel,
      'locale': locale,
      'timezone': timezone,
      'screenSize': screenSize,
    };
  }

  /// Create a copy with some fields replaced
  DeviceContext copyWith({
    String? platform,
    String? osVersion,
    String? appVersion,
    String? buildNumber,
    String? deviceModel,
    String? locale,
    String? timezone,
    String? screenSize,
  }) {
    return DeviceContext(
      platform: platform ?? this.platform,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      deviceModel: deviceModel ?? this.deviceModel,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      screenSize: screenSize ?? this.screenSize,
    );
  }

  @override
  String toString() {
    return 'DeviceContext(platform: $platform, osVersion: $osVersion, '
        'appVersion: $appVersion, buildNumber: $buildNumber, '
        'deviceModel: $deviceModel, locale: $locale, '
        'timezone: $timezone, screenSize: $screenSize)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceContext &&
        other.platform == platform &&
        other.osVersion == osVersion &&
        other.appVersion == appVersion &&
        other.buildNumber == buildNumber &&
        other.deviceModel == deviceModel &&
        other.locale == locale &&
        other.timezone == timezone &&
        other.screenSize == screenSize;
  }

  @override
  int get hashCode {
    return Object.hash(
      platform,
      osVersion,
      appVersion,
      buildNumber,
      deviceModel,
      locale,
      timezone,
      screenSize,
    );
  }
}
