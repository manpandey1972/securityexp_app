import 'package:flutter/material.dart';

/// Shape style variants for buttons and text fields.
/// 
/// - [rounded]: Standard 8px rounded corners (default)
/// - [pill]: Fully rounded ends (stadium shape)
enum AppShapeStyle {
  /// Standard rounded corners (8px radius)
  rounded,
  
  /// Pill/stadium shape with fully rounded ends
  pill,
}

/// Global configuration for button and text field shapes.
/// 
/// Use this to easily switch between rounded corners and pill shapes
/// across the entire app.
/// 
/// Example:
/// ```dart
/// // In main.dart or app initialization
/// AppShapeConfig.style = AppShapeStyle.pill; // Enable pill shapes globally
/// 
/// // Or configure individual components
/// AppShapeConfig.buttonStyle = AppShapeStyle.pill;
/// AppShapeConfig.textFieldStyle = AppShapeStyle.rounded;
/// ```
class AppShapeConfig {
  AppShapeConfig._(); // Prevent instantiation

  // ====================
  // Global Style Setting
  // ====================
  
  /// Global shape style that applies to all components when individual
  /// styles are not set. Defaults to [AppShapeStyle.rounded].
  static AppShapeStyle _globalStyle = AppShapeStyle.rounded;
  
  /// Get the global shape style
  static AppShapeStyle get style => _globalStyle;
  
  /// Set the global shape style for all components
  static set style(AppShapeStyle value) {
    _globalStyle = value;
    _buttonStyle = null; // Reset individual overrides
    _textFieldStyle = null;
  }

  // ====================
  // Individual Component Styles
  // ====================
  
  static AppShapeStyle? _buttonStyle;
  static AppShapeStyle? _textFieldStyle;
  
  /// Shape style for buttons. Falls back to global style if not set.
  static AppShapeStyle get buttonStyle => _buttonStyle ?? _globalStyle;
  static set buttonStyle(AppShapeStyle value) => _buttonStyle = value;
  
  /// Shape style for text fields. Falls back to global style if not set.
  static AppShapeStyle get textFieldStyle => _textFieldStyle ?? _globalStyle;
  static set textFieldStyle(AppShapeStyle value) => _textFieldStyle = value;
  
  /// Reset individual style to use global style
  static void resetButtonStyle() => _buttonStyle = null;
  static void resetTextFieldStyle() => _textFieldStyle = null;
  
  /// Reset all styles to defaults
  static void resetAll() {
    _globalStyle = AppShapeStyle.rounded;
    _buttonStyle = null;
    _textFieldStyle = null;
  }

  // ====================
  // Border Radius Constants
  // ====================
  
  /// Standard rounded corner radius (8px)
  static const double roundedRadius = 8.0;
  
  /// Pill shape radius - use a large value that creates stadium effect
  static const double pillRadius = 100.0;

  // ====================
  // Computed Border Radius Values
  // ====================
  
  /// Get the current button border radius based on configuration
  static double get buttonRadius => 
      buttonStyle == AppShapeStyle.pill ? pillRadius : roundedRadius;
  
  /// Get the current text field border radius based on configuration
  static double get textFieldRadius => 
      textFieldStyle == AppShapeStyle.pill ? pillRadius : roundedRadius;
  
  /// Get BorderRadius for buttons
  static BorderRadius get buttonBorderRadius => 
      BorderRadius.circular(buttonRadius);
  
  /// Get BorderRadius for text fields
  static BorderRadius get textFieldBorderRadius => 
      BorderRadius.circular(textFieldRadius);

  // ====================
  // Shape Objects for Material Components
  // ====================
  
  /// Get the appropriate OutlinedBorder for buttons based on style
  static OutlinedBorder get buttonShape {
    if (buttonStyle == AppShapeStyle.pill) {
      return const StadiumBorder();
    }
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(roundedRadius),
    );
  }
  
  /// Get RoundedRectangleBorder for text field inputs based on style
  static OutlineInputBorder textFieldBorder({
    Color borderColor = const Color(0xFFE0E0E0),
    double borderWidth = 1.0,
  }) {
    return OutlineInputBorder(
      borderRadius: textFieldBorderRadius,
      borderSide: BorderSide(color: borderColor, width: borderWidth),
    );
  }

  // ====================
  // Size-Aware Radius (for consistent pill appearance)
  // ====================
  
  /// Get button radius that accounts for height (pill = height/2)
  /// This ensures perfect pill shape regardless of button height
  static double buttonRadiusForHeight(double height) {
    if (buttonStyle == AppShapeStyle.pill) {
      return height / 2;
    }
    return roundedRadius;
  }
  
  /// Get text field radius that accounts for height
  static double textFieldRadiusForHeight(double height) {
    if (textFieldStyle == AppShapeStyle.pill) {
      return height / 2;
    }
    return roundedRadius;
  }
}
