import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../themes/app_spacing.dart';

/// Loading indicator variants for different use cases
/// Provides circular, linear, dot, and pulse loading indicators
class LoadingIndicators {
  /// Standard circular progress indicator
  static Widget circular({
    Color? color,
    double strokeWidth = 4,
    double size = 40,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primary,
        ),
      ),
    );
  }

  /// Linear progress indicator (horizontal)
  static Widget linear({
    Color? color,
    double height = 4,
    double minHeight = 1,
  }) {
    return SizedBox(
      height: height,
      child: LinearProgressIndicator(
        minHeight: minHeight,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primary,
        ),
      ),
    );
  }

  /// Animated dots loading indicator
  static Widget dots({
    Color? color,
    double dotSize = 8,
    int dotCount = 3,
  }) {
    return _DotsIndicator(
      color: color ?? AppColors.primary,
      dotSize: dotSize,
      dotCount: dotCount,
    );
  }

  /// Pulsing circle indicator
  static Widget pulse({
    Color? color,
    double size = 40,
  }) {
    return _PulseIndicator(
      color: color ?? AppColors.primary,
      size: size,
    );
  }

  /// Rotating circular indicator
  static Widget rotating({
    Color? color,
    double size = 40,
  }) {
    return _RotatingIndicator(
      color: color ?? AppColors.primary,
      size: size,
    );
  }

  /// Bouncing ball indicator
  static Widget bouncing({
    Color? color,
    double ballSize = 12,
  }) {
    return _BouncingIndicator(
      color: color ?? AppColors.primary,
      ballSize: ballSize,
    );
  }

  /// Wave/shimmer loading effect
  static Widget wave({
    Color? color,
    double height = 20,
  }) {
    return _WaveIndicator(
      color: color ?? AppColors.primary,
      height: height,
    );
  }

  /// Minimal centered loader with text
  static Widget withLabel({
    required String label,
    Color? color,
    double indicatorSize = 32,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          circular(
            color: color,
            size: indicatorSize,
          ),
          SizedBox(height: AppSpacing.spacing12),
          Text(
            label,
            style: TextStyle(
              color: color ?? AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated dots indicator
class _DotsIndicator extends StatefulWidget {
  final Color color;
  final double dotSize;
  final int dotCount;

  const _DotsIndicator({
    required this.color,
    required this.dotSize,
    required this.dotCount,
  });

  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.dotCount,
          (index) => _AnimatedDot(
            animation: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  index / widget.dotCount,
                  (index + 1) / widget.dotCount,
                  curve: Curves.easeInOut,
                ),
              ),
            ),
            color: widget.color,
            size: widget.dotSize,
          ),
        ),
      ),
    );
  }
}

class _AnimatedDot extends AnimatedWidget {
  final Color color;
  final double size;

  const _AnimatedDot({
    required Animation<double> animation,
    required this.color,
    required this.size,
  }) : super(listenable: animation);

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: size / 2),
      width: size * animation.value,
      height: size * animation.value,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Pulsing circle indicator
class _PulseIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const _PulseIndicator({
    required this.color,
    required this.size,
  });

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Rotating circular indicator
class _RotatingIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const _RotatingIndicator({
    required this.color,
    required this.size,
  });

  @override
  State<_RotatingIndicator> createState() => _RotatingIndicatorState();
}

class _RotatingIndicatorState extends State<_RotatingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotationTransition(
        turns: _controller,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            border: Border.all(color: widget.color.withValues(alpha: 0.3), width: 3),
            shape: BoxShape.circle,
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: widget.color, width: 3),
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouncing ball indicator
class _BouncingIndicator extends StatefulWidget {
  final Color color;
  final double ballSize;

  const _BouncingIndicator({
    required this.color,
    required this.ballSize,
  });

  @override
  State<_BouncingIndicator> createState() => _BouncingIndicatorState();
}

class _BouncingIndicatorState extends State<_BouncingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (index) => _BouncingBall(
            animation: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  index / 3,
                  (index + 1) / 3,
                  curve: Curves.easeInOut,
                ),
              ),
            ),
            color: widget.color,
            size: widget.ballSize,
          ),
        ),
      ),
    );
  }
}

class _BouncingBall extends AnimatedWidget {
  final Color color;
  final double size;

  const _BouncingBall({
    required Animation<double> animation,
    required this.color,
    required this.size,
  }) : super(listenable: animation);

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final offset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -20),
    ).evaluate(animation);

    return Transform.translate(
      offset: offset,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: size / 2),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Wave/shimmer loading effect
class _WaveIndicator extends StatefulWidget {
  final Color color;
  final double height;

  const _WaveIndicator({
    required this.color,
    required this.height,
  });

  @override
  State<_WaveIndicator> createState() => _WaveIndicatorState();
}

class _WaveIndicatorState extends State<_WaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 100,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: const Offset(1, 0),
                ).animate(_controller),
                child: Container(
                  width: 50,
                  color: widget.color.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
