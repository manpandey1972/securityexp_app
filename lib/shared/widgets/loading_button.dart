import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../themes/app_animations.dart';
import '../themes/app_typography.dart';

/// A button widget that displays a loading indicator while an async operation is in progress.
/// Automatically disables the button and shows a spinner during loading.
///
/// Usage:
/// ```dart
/// LoadingButton(
///   isLoading: _isLoading,
///   onPressed: _handleSubmit,
///   label: 'Submit',
/// )
/// ```
class LoadingButton extends StatefulWidget {
  /// Whether the button is currently in a loading state
  final bool isLoading;

  /// Callback when button is pressed (not called while loading)
  final VoidCallback onPressed;

  /// Label text displayed on the button
  final String label;

  /// Whether the button is enabled (independent of loading state)
  final bool isEnabled;

  /// Style variant of the button
  final LoadingButtonVariant variant;

  /// Width of the button (if null, uses default)
  final double? width;

  /// Height of the button
  final double height;

  /// Color of the loading indicator (defaults to white or text color)
  final Color? loadingIndicatorColor;

  /// Size of the loading indicator (defaults to 18)
  final double loadingIndicatorSize;

  /// Stroke width of the loading indicator
  final double loadingIndicatorStrokeWidth;

  /// Optional icon to display before the text
  final IconData? icon;

  /// Spacing between icon and text
  final double iconSpacing;

  /// Custom text style
  final TextStyle? textStyle;

  const LoadingButton({
    required this.isLoading,
    required this.onPressed,
    required this.label,
    this.isEnabled = true,
    this.variant = LoadingButtonVariant.elevated,
    this.width,
    this.height = 44,
    this.loadingIndicatorColor,
    this.loadingIndicatorSize = 18,
    this.loadingIndicatorStrokeWidth = 2,
    this.icon,
    this.iconSpacing = 8,
    this.textStyle,
    super.key,
  });

  /// Elevated variant - primary button style
  factory LoadingButton.elevated({
    required bool isLoading,
    required VoidCallback onPressed,
    required String label,
    bool isEnabled = true,
    double? width,
    double height = 44,
    IconData? icon,
  }) {
    return LoadingButton(
      isLoading: isLoading,
      onPressed: onPressed,
      label: label,
      isEnabled: isEnabled,
      variant: LoadingButtonVariant.elevated,
      width: width,
      height: height,
      icon: icon,
    );
  }

  /// Outlined variant - secondary button style
  factory LoadingButton.outlined({
    required bool isLoading,
    required VoidCallback onPressed,
    required String label,
    bool isEnabled = true,
    double? width,
    double height = 44,
    IconData? icon,
  }) {
    return LoadingButton(
      isLoading: isLoading,
      onPressed: onPressed,
      label: label,
      isEnabled: isEnabled,
      variant: LoadingButtonVariant.outlined,
      width: width,
      height: height,
      icon: icon,
    );
  }

  /// Text variant - minimal button style
  factory LoadingButton.text({
    required bool isLoading,
    required VoidCallback onPressed,
    required String label,
    bool isEnabled = true,
    double? width,
    double height = 44,
    IconData? icon,
  }) {
    return LoadingButton(
      isLoading: isLoading,
      onPressed: onPressed,
      label: label,
      isEnabled: isEnabled,
      variant: LoadingButtonVariant.text,
      width: width,
      height: height,
      icon: icon,
    );
  }

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimations.loadingConfig.duration,
      vsync: this,
    );

    if (widget.isLoading) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(LoadingButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isLoading && !oldWidget.isLoading) {
      _animationController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = !widget.isEnabled || widget.isLoading;

    switch (widget.variant) {
      case LoadingButtonVariant.elevated:
        return _buildElevatedButton(isDisabled);
      case LoadingButtonVariant.outlined:
        return _buildOutlinedButton(isDisabled);
      case LoadingButtonVariant.text:
        return _buildTextButton(isDisabled);
    }
  }

  Widget _buildElevatedButton(bool isDisabled) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ElevatedButton(
        onPressed: isDisabled ? null : widget.onPressed,
        child: _buildButtonContent(
          textColor: isDisabled ? AppColors.textMuted : AppColors.white,
          loadingIndicatorColor: widget.loadingIndicatorColor ?? AppColors.white,
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(bool isDisabled) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: OutlinedButton(
        onPressed: isDisabled ? null : widget.onPressed,
        child: _buildButtonContent(
          textColor: isDisabled
              ? AppColors.textMuted
              : AppColors.primary,
          loadingIndicatorColor:
              widget.loadingIndicatorColor ?? AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildTextButton(bool isDisabled) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: TextButton(
        onPressed: isDisabled ? null : widget.onPressed,
        child: _buildButtonContent(
          textColor:
              isDisabled ? AppColors.textMuted : AppColors.primary,
          loadingIndicatorColor:
              widget.loadingIndicatorColor ?? AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildButtonContent({
    required Color textColor,
    required Color loadingIndicatorColor,
  }) {
    return AnimatedCrossFade(
      firstChild: _buildLabelContent(textColor),
      secondChild: _buildLoadingContent(loadingIndicatorColor),
      crossFadeState: widget.isLoading
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: AppAnimations.fast,
    );
  }

  Widget _buildLabelContent(Color textColor) {
    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: textColor, size: 18),
          SizedBox(width: widget.iconSpacing),
          Text(
            widget.label,
            style: widget.textStyle ??
                AppTypography.bodySmall.copyWith(color: textColor),
          ),
        ],
      );
    }

    return Text(
      widget.label,
      style: widget.textStyle ??
          AppTypography.bodySmall.copyWith(color: textColor),
    );
  }

  Widget _buildLoadingContent(Color loadingIndicatorColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: _animationController,
          child: SizedBox(
            width: widget.loadingIndicatorSize,
            height: widget.loadingIndicatorSize,
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(loadingIndicatorColor),
              strokeWidth: widget.loadingIndicatorStrokeWidth,
            ),
          ),
        ),
        SizedBox(width: widget.iconSpacing),
        Text(
          'Loading...',
          style: widget.textStyle ??
              TextStyle(
                color: loadingIndicatorColor,
                fontSize: 14,
              ),
        ),
      ],
    );
  }
}

/// Enum for loading button variants
enum LoadingButtonVariant {
  /// Elevated button style - primary action
  elevated,

  /// Outlined button style - secondary action
  outlined,

  /// Text button style - minimal action
  text,
}
