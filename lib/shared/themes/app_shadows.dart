import 'package:flutter/material.dart';

/// Shadow and elevation constants for depth and elevation in the Security Experts app.
class AppShadows {
  AppShadows._(); // Private constructor to prevent instantiation

  // ====================
  // Elevation Levels (for Material Design consistency)
  // ====================
  /// No elevation - flat surface
  static const double elevationNone = 0.0;

  /// Low elevation - subtle depth
  static const double elevationLow = 1.0;

  /// Standard elevation - cards, raised buttons
  static const double elevationStandard = 2.0;

  /// Medium elevation - floating action buttons, modals
  static const double elevationMedium = 4.0;

  /// High elevation - top-level surfaces, overlays
  static const double elevationHigh = 8.0;

  /// Very high elevation - maximum depth (modals, sheets)
  static const double elevationMax = 12.0;

  // ====================
  // Shadow Definitions (Legacy support - if needed)
  // ====================
  /// Subtle shadow for slight elevation
  static const List<BoxShadow> shadowSubtle = [
    BoxShadow(
      color: Color.fromARGB(15, 0, 0, 0),
      blurRadius: 3.0,
      offset: Offset(0, 1),
    ),
  ];

  /// Standard shadow for normal elevation
  static const List<BoxShadow> shadowStandard = [
    BoxShadow(
      color: Color.fromARGB(25, 0, 0, 0),
      blurRadius: 8.0,
      offset: Offset(0, 2),
    ),
  ];

  /// Medium shadow for increased elevation
  static const List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Color.fromARGB(30, 0, 0, 0),
      blurRadius: 12.0,
      offset: Offset(0, 4),
    ),
  ];

  /// Large shadow for high elevation
  static const List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: Color.fromARGB(40, 0, 0, 0),
      blurRadius: 16.0,
      offset: Offset(0, 8),
    ),
  ];

  /// Extra large shadow for maximum elevation
  static const List<BoxShadow> shadowXLarge = [
    BoxShadow(
      color: Color.fromARGB(50, 0, 0, 0),
      blurRadius: 24.0,
      offset: Offset(0, 12),
    ),
  ];

  // ====================
  // Color Constants for Shadows
  // ====================
  /// Shadow color with 15% opacity
  static const Color shadowColorSubtle = Color.fromARGB(15, 0, 0, 0);

  /// Shadow color with 25% opacity
  static const Color shadowColorNormal = Color.fromARGB(25, 0, 0, 0);

  /// Shadow color with 30% opacity
  static const Color shadowColorMedium = Color.fromARGB(30, 0, 0, 0);

  /// Shadow color with 40% opacity
  static const Color shadowColorLarge = Color.fromARGB(40, 0, 0, 0);

  /// Shadow color with 50% opacity
  static const Color shadowColorXLarge = Color.fromARGB(50, 0, 0, 0);
}
