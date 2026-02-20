import 'package:flutter/material.dart';

/// Border radius and border-related styling constants for the Security Experts app.
class AppBorders {
  AppBorders._(); // Private constructor to prevent instantiation

  // ====================
  // Border Radius Scale
  // ====================
  /// 2pt border radius - minimal rounding (drag handles, thin elements)
  static const double radius2 = 2.0;
  static const double radiusSmall = 2.0;

  /// 4pt border radius - tiny rounding (indicators, progress bars)
  static const double radius4 = 4.0;

  /// 6pt border radius - very small rounding
  static const double radius6 = 6.0;

  /// 8pt border radius - subtle rounding
  static const double radius8 = 8.0;

  /// 12pt border radius - standard rounding
  static const double radius12 = 12.0;
  static const double radiusMedium = 12.0;

  /// 14pt border radius - slightly larger standard
  static const double radius14 = 14.0;

  /// 16pt border radius - cards and medium surfaces
  static const double radius16 = 16.0;

  /// 20pt border radius - large surfaces
  static const double radius20 = 20.0;
  static const double radiusLarge = 20.0;

  /// 24pt border radius - extra large containers
  static const double radius24 = 24.0;

  /// 32pt border radius - maximum rounding
  static const double radius32 = 32.0;

  /// 38pt border radius - large rounded containers, bottom sheets
  static const double radius38 = 38.0;

  /// 50pt border radius - pill shapes
  static const double radiusPill = 50.0;

  // ====================
  // BorderRadius Objects (for convenience)
  // ====================
  /// Minimal rounding (drag handles)
  static final BorderRadius borderRadiusTiny = BorderRadius.circular(radius2);

  /// Tiny rounding (indicators)
  static final BorderRadius borderRadiusXSmall = BorderRadius.circular(radius4);

  /// Very small rounding
  static final BorderRadius borderRadiusSmallAlt = BorderRadius.circular(
    radius6,
  );

  /// Subtle rounded corners
  static final BorderRadius borderRadiusSmall = BorderRadius.circular(radius8);

  /// Standard rounded corners
  static final BorderRadius borderRadiusNormal = BorderRadius.circular(
    radius12,
  );

  /// Medium rounded corners
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(
    radius16,
  );

  /// Card border radius - used for cards and elevated surfaces
  static final BorderRadius borderRadiusCard = BorderRadius.circular(radius16);

  /// Large rounded corners
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(radius20);

  /// Extra large rounded corners
  static final BorderRadius borderRadiusXLarge = BorderRadius.circular(
    radius24,
  );

  /// Maximum rounded corners (near circle)
  static final BorderRadius borderRadiusCircle = BorderRadius.circular(
    radius32,
  );

  /// Large sheet/modal radius
  static final BorderRadius borderRadiusSheet = BorderRadius.circular(radius38);

  /// Pill shape (fully rounded ends)
  static final BorderRadius borderRadiusPill = BorderRadius.circular(radiusPill);

  // ====================
  // Common Border Definitions
  // ====================
  /// Standard divider border
  static const Border dividerBorder = Border(
    bottom: BorderSide(
      color: Color(0xFF2A2A2A), // divider
      width: 0.5,
    ),
  );

  /// Card border with subtle outline
  static final Border cardBorder = Border.all(
    color: const Color(0xFF2A2A2A), // divider
    width: 0.5,
  );

  /// Active/focused border
  static final Border activeBorder = Border.all(
    color: const Color(0xFF4CAF50), // primary
    width: 1.5,
  );

  // ====================
  // Card Shape (Material 3 Compliance)
  // ====================
  /// Standard card shape with rounded corners
  static final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: borderRadiusCard,
  );

  /// Button shape with standard rounding
  static final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: borderRadiusNormal,
  );

  /// Circular shape (for icons, avatars)
  static final CircleBorder circleBorder = const CircleBorder();

  /// Stadium shape (pill-shaped buttons)
  static final StadiumBorder stadiumBorder = const StadiumBorder();
}
