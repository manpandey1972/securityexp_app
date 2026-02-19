import 'package:flutter/material.dart';
import 'app_shape_config.dart';

/// Extension methods for InputDecoration to easily apply shape configuration
extension InputDecorationShapeExtension on InputDecoration {
  /// Apply the configured shape style to this InputDecoration
  /// 
  /// Example:
  /// ```dart
  /// TextField(
  ///   decoration: InputDecoration(
  ///     hintText: 'Enter text',
  ///   ).withConfiguredShape(),
  /// )
  /// ```
  InputDecoration withConfiguredShape({
    Color? borderColor,
    Color? focusedBorderColor,
    Color? errorBorderColor,
    double borderWidth = 1.0,
    double focusedBorderWidth = 2.0,
  }) {
    final radius = AppShapeConfig.textFieldBorderRadius;
    final defaultBorderColor = borderColor ?? const Color(0xFFE0E0E0);
    final defaultFocusedColor = focusedBorderColor ?? const Color(0xFF4CAF50);
    final defaultErrorColor = errorBorderColor ?? const Color(0xFFE74C3C);

    return copyWith(
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultBorderColor, width: borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultBorderColor, width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultFocusedColor, width: focusedBorderWidth),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultErrorColor, width: borderWidth),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultErrorColor, width: focusedBorderWidth),
      ),
    );
  }
  
  /// Apply pill shape explicitly (ignoring global config)
  InputDecoration withPillShape({
    Color? borderColor,
    Color? focusedBorderColor,
    Color? errorBorderColor,
    double borderWidth = 1.0,
    double focusedBorderWidth = 2.0,
  }) {
    final radius = BorderRadius.circular(AppShapeConfig.pillRadius);
    final defaultBorderColor = borderColor ?? const Color(0xFFE0E0E0);
    final defaultFocusedColor = focusedBorderColor ?? const Color(0xFF4CAF50);
    final defaultErrorColor = errorBorderColor ?? const Color(0xFFE74C3C);

    return copyWith(
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultBorderColor, width: borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultBorderColor, width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultFocusedColor, width: focusedBorderWidth),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultErrorColor, width: borderWidth),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: defaultErrorColor, width: focusedBorderWidth),
      ),
    );
  }
  
  /// Apply rounded shape explicitly (ignoring global config)
  InputDecoration withRoundedShape({
    Color? borderColor,
    Color? focusedBorderColor,
    Color? errorBorderColor,
    double borderWidth = 1.0,
    double focusedBorderWidth = 2.0,
    double radius = 8.0,
  }) {
    final borderRadius = BorderRadius.circular(radius);
    final defaultBorderColor = borderColor ?? const Color(0xFFE0E0E0);
    final defaultFocusedColor = focusedBorderColor ?? const Color(0xFF4CAF50);
    final defaultErrorColor = errorBorderColor ?? const Color(0xFFE74C3C);

    return copyWith(
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: defaultBorderColor, width: borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: defaultBorderColor, width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: defaultFocusedColor, width: focusedBorderWidth),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: defaultErrorColor, width: borderWidth),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: defaultErrorColor, width: focusedBorderWidth),
      ),
    );
  }
}

/// Extension methods for ButtonStyle to easily apply shape configuration
extension ButtonStyleShapeExtension on ButtonStyle {
  /// Apply the configured shape style to this ButtonStyle
  ButtonStyle withConfiguredShape() {
    return copyWith(
      shape: WidgetStatePropertyAll(AppShapeConfig.buttonShape),
    );
  }
  
  /// Apply pill shape explicitly (ignoring global config)
  ButtonStyle withPillShape() {
    return copyWith(
      shape: const WidgetStatePropertyAll(StadiumBorder()),
    );
  }
  
  /// Apply rounded shape explicitly (ignoring global config)
  ButtonStyle withRoundedShape({double radius = 8.0}) {
    return copyWith(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

/// Extension on ElevatedButton.styleFrom result for easy shape application
extension ElevatedButtonStyleExtension on ButtonStyle {
  /// Create a copy with pill shape
  ButtonStyle asPill() => withPillShape();
  
  /// Create a copy with rounded shape  
  ButtonStyle asRounded({double radius = 8.0}) => withRoundedShape(radius: radius);
}
