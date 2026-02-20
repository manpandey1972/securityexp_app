import 'package:flutter/material.dart';

/// Responsive design utilities for Security Experts app
/// Provides breakpoints and helper methods for adaptive layouts
class Responsive {
  /// Breakpoint definitions (logical pixels)
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Check if device is mobile (< 600px)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Check if device is tablet (600px - 900px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if device is desktop (>= 1200px)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  /// Get responsive value based on screen size
  /// Example: Responsive.value(context, mobile: 16, tablet: 24, desktop: 32)
  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }

  /// Get responsive padding
  static EdgeInsets padding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: value(context: context, mobile: 16, tablet: 24, desktop: 32),
    );
  }

  /// Get responsive column count for grid layouts
  static int gridColumnCount(BuildContext context) {
    return value(context: context, mobile: 1, tablet: 2, desktop: 3);
  }

  /// Get responsive font size
  static double fontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return value(
      context: context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.1,
      desktop: desktop ?? mobile * 1.2,
    );
  }

  /// Get responsive spacing
  static double spacing(BuildContext context) {
    return value(context: context, mobile: 8, tablet: 12, desktop: 16);
  }

  /// Get screen width
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get screen height
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Check if device is in portrait orientation
  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;
}

/// Extension methods for responsive design
extension ResponsiveContext on BuildContext {
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  double get screenWidth => Responsive.width(this);
  double get screenHeight => Responsive.height(this);
  bool get isLandscape => Responsive.isLandscape(this);
  bool get isPortrait => Responsive.isPortrait(this);
}
