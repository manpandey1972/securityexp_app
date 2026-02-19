import 'package:flutter/material.dart';

/// Modern page transition animations for GreenHive app
/// Provides smooth, visually appealing navigation transitions
class PageTransitions {
  PageTransitions._();

  /// Fade transition with scale
  static Route<T> fadeScale<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        final tween = Tween(begin: begin, end: end);
        final fadeAnimation = animation.drive(tween);

        const scaleBegin = 0.95;
        const scaleEnd = 1.0;
        final scaleTween = Tween(begin: scaleBegin, end: scaleEnd);
        final scaleAnimation = animation.drive(
          scaleTween.chain(CurveTween(curve: Curves.easeOutCubic)),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
    );
  }

  /// Slide from right (Material-like but smoother)
  static Route<T> slideFromRight<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );

        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
    );
  }

  /// Slide from bottom (for modal-like pages)
  static Route<T> slideFromBottom<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
    );
  }

  /// Zoom in transition
  static Route<T> zoom<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        final tween = Tween(begin: begin, end: end);
        final fadeAnimation = animation.drive(tween);

        const scaleBegin = 0.8;
        const scaleEnd = 1.0;
        final scaleTween = Tween(begin: scaleBegin, end: scaleEnd);
        final scaleAnimation = animation.drive(
          scaleTween.chain(CurveTween(curve: Curves.easeOutCubic)),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
    );
  }

  /// Shared axis transition (Material 3 pattern)
  static Route<T> sharedAxis<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.3, 0.0);
        const end = Offset.zero;
        final slideTween = Tween(begin: begin, end: end);
        final slideAnimation = animation.drive(
          slideTween.chain(CurveTween(curve: Curves.easeInOutCubic)),
        );

        const fadeBegin = 0.0;
        const fadeEnd = 1.0;
        final fadeTween = Tween(begin: fadeBegin, end: fadeEnd);
        final fadeAnimation = animation.drive(fadeTween);

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
    );
  }

  /// Fade through transition (for replacing content)
  static Route<T> fadeThrough<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Incoming page fades in after a delay
        final inAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
          ),
        );

        return FadeTransition(opacity: inAnimation, child: child);
      },
    );
  }

  /// Custom rotation + fade transition
  static Route<T> rotateScale<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final rotationTween = Tween<double>(begin: 0.0, end: 1.0);
        final scaleTween = Tween<double>(begin: 0.8, end: 1.0);
        final fadeTween = Tween<double>(begin: 0.0, end: 1.0);

        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: fadeTween.animate(curvedAnimation),
          child: ScaleTransition(
            scale: scaleTween.animate(curvedAnimation),
            child: RotationTransition(
              turns: rotationTween.animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Extension for easy navigation with transitions
extension NavigatorTransitionExtension on NavigatorState {
  /// Push with fade+scale transition
  Future<T?> pushFadeScale<T>(Widget page) {
    return push<T>(PageTransitions.fadeScale(page: page));
  }

  /// Push with slide from right
  Future<T?> pushSlideRight<T>(Widget page) {
    return push<T>(PageTransitions.slideFromRight(page: page));
  }

  /// Push with slide from bottom
  Future<T?> pushSlideBottom<T>(Widget page) {
    return push<T>(PageTransitions.slideFromBottom(page: page));
  }

  /// Push with zoom transition
  Future<T?> pushZoom<T>(Widget page) {
    return push<T>(PageTransitions.zoom(page: page));
  }

  /// Push with shared axis transition
  Future<T?> pushSharedAxis<T>(Widget page) {
    return push<T>(PageTransitions.sharedAxis(page: page));
  }
}
