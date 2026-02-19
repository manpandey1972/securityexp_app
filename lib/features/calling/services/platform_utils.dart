import 'package:flutter/foundation.dart';

/// Platform utilities that work safely across web and native platforms.
///
/// Using `dart:io` Platform directly on web causes crashes.
/// This utility provides safe platform checks.
class PlatformUtils {
  PlatformUtils._();

  /// Whether the current platform is iOS (safely checks, returns false on web)
  static bool get isIOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Whether the current platform is Android (safely checks, returns false on web)
  static bool get isAndroid {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Whether the current platform is macOS
  static bool get isMacOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Whether the current platform is Windows
  static bool get isWindows {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Whether the current platform is Linux
  static bool get isLinux {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Whether running on a mobile device (iOS or Android)
  static bool get isMobile => isIOS || isAndroid;

  /// Whether running on desktop (macOS, Windows, Linux)
  static bool get isDesktop => isMacOS || isWindows || isLinux;
}
