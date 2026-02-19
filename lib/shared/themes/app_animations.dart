import 'package:flutter/material.dart';

/// Animation constants and utilities for consistent animations across the app.
/// Provides standardized durations, curves, and animation helpers.
class AppAnimations {
  AppAnimations._(); // Private constructor to prevent instantiation

  // ====================
  // Duration Constants
  // ====================
  /// Instant animation - for very quick feedback (100ms)
  static const Duration instant = Duration(milliseconds: 100);

  /// Fast animation - quick interactions (200ms)
  static const Duration fast = Duration(milliseconds: 200);

  /// Normal animation - standard interactions (300ms)
  static const Duration normal = Duration(milliseconds: 300);

  /// Medium animation - deliberate transitions (400ms)
  static const Duration medium = Duration(milliseconds: 400);

  /// Slow animation - entrance animations (500ms)
  static const Duration slow = Duration(milliseconds: 500);

  /// Very slow animation - complex transitions (700ms)
  static const Duration verySlow = Duration(milliseconds: 700);

  // ====================
  // Curve Constants
  // ====================
  /// Standard easing - used for most animations
  static const Curve standardEasing = Curves.easeInOut;

  /// Entrance easing - used for appearing elements
  static const Curve enterEasing = Curves.easeOut;

  /// Exit easing - used for disappearing elements
  static const Curve exitEasing = Curves.easeIn;

  /// Decelerate easing - smooth slow-down at the end
  static const Curve decelerateEasing = Curves.decelerate;

  /// Bounce easing - playful, bouncy animations
  static const Curve bounceEasing = Curves.elasticOut;

  // ====================
  // Spring Animations
  // ====================
  /// Spring animation - bouncy, playful feel
  static const Curve spring = Curves.elasticOut;

  /// Bouncy curve - even bouncier than spring
  static const Curve bouncy = Curves.bounceOut;

  // ====================
  // Animation Helpers
  // ====================

  /// Create a slide-in animation from bottom
  static Animation<Offset> slideInFromBottom(Animation<double> parent) {
    return Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: parent, curve: enterEasing),
    );
  }

  /// Create a slide-in animation from left
  static Animation<Offset> slideInFromLeft(Animation<double> parent) {
    return Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: parent, curve: enterEasing),
    );
  }

  /// Create a slide-in animation from right
  static Animation<Offset> slideInFromRight(Animation<double> parent) {
    return Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: parent, curve: enterEasing),
    );
  }

  /// Create a fade-in animation
  static Animation<double> fadeIn(Animation<double> parent) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: parent, curve: enterEasing),
    );
  }

  /// Create a fade-out animation
  static Animation<double> fadeOut(Animation<double> parent) {
    return Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: parent, curve: exitEasing),
    );
  }

  /// Create a scale animation (grow)
  static Animation<double> scaleUp(Animation<double> parent) {
    return Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: parent, curve: enterEasing),
    );
  }

  /// Create a scale animation (shrink)
  static Animation<double> scaleDown(Animation<double> parent) {
    return Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: parent, curve: exitEasing),
    );
  }

  /// Create a rotation animation (360 degrees)
  static Animation<double> rotate360(Animation<double> parent) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: parent, curve: standardEasing),
    );
  }

  /// Create a bounce scale animation
  static Animation<double> bounceScale(Animation<double> parent) {
    return Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: parent, curve: bounceEasing),
    );
  }

  // ====================
  // Preset Animation Configurations
  // ====================

  /// Quick button press feedback animation
  static const buttonPressConfig = (
    duration: fast,
    curve: standardEasing,
  );

  /// Smooth page transition animation
  static const pageTransitionConfig = (
    duration: normal,
    curve: enterEasing,
  );

  /// Subtle hover effect animation
  static const hoverConfig = (
    duration: instant,
    curve: standardEasing,
  );

  /// Loading animation configuration
  static const loadingConfig = (
    duration: Duration(milliseconds: 2000),
    curve: standardEasing,
  );

  /// Dialog entrance animation
  static const dialogEnterConfig = (
    duration: medium,
    curve: enterEasing,
  );

  /// Dialog exit animation
  static const dialogExitConfig = (
    duration: fast,
    curve: exitEasing,
  );

  /// Snackbar entrance animation
  static const snackbarConfig = (
    duration: fast,
    curve: enterEasing,
  );

  /// Notification entrance animation
  static const notificationConfig = (
    duration: medium,
    curve: enterEasing,
  );
}
