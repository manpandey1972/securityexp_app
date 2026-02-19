/// Standardized icon sizes for consistent iconography across the app.
///
/// Usage:
/// ```dart
/// Icon(Icons.settings, size: AppIconSizes.standard)
/// Icon(Icons.home, size: AppIconSizes.large)
/// Icon(Icons.star, size: AppIconSizes.hero)
/// ```
///
/// Size Guidelines:
/// - [tiny] (14): Small inline icons, status indicators
/// - [small] (16): Secondary action icons, list item trailing icons
/// - [medium] (20): Standard button icons, input field icons
/// - [standard] (24): Default icon size, app bar icons
/// - [large] (28): Emphasized icons, tab bar icons
/// - [xlarge] (32): Featured icons, card headers
/// - [display] (48): Empty state icons, feature highlights
/// - [hero] (64): Large decorative icons, onboarding illustrations
abstract class AppIconSizes {
  AppIconSizes._();

  /// Tiny icon size (14) - Small inline icons, status indicators
  static const double tiny = 14;

  /// Small icon size (16) - Secondary action icons, list item trailing icons
  static const double small = 16;

  /// Medium icon size (20) - Standard button icons, input field icons
  static const double medium = 20;

  /// Standard icon size (24) - Default icon size, app bar icons
  static const double standard = 24;

  /// Large icon size (28) - Emphasized icons, tab bar icons
  static const double large = 28;

  /// Extra large icon size (32) - Featured icons, card headers
  static const double xlarge = 32;

  /// Display icon size (48) - Empty state icons, feature highlights
  static const double display = 48;

  /// Hero icon size (64) - Large decorative icons, onboarding illustrations
  static const double hero = 64;

  /// Extra hero icon size (80) - Very large decorative icons
  static const double heroLarge = 80;

  /// Max hero icon size (100) - Maximum size for decorative icons
  static const double heroMax = 100;
}
