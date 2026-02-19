import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../themes/app_button_sizes.dart';
import '../themes/app_borders.dart';
import '../themes/app_shape_config.dart';

/// A modern search input field with built-in clear button and state management.
/// Provides a clean, Material Design 3 compliant search experience.
///
/// Usage:
/// ```dart
/// SearchInputField(
///   controller: _searchController,
///   onChanged: (query) => _performSearch(query),
///   hintText: 'Search conversations...',
/// )
/// ```
class SearchInputField extends StatefulWidget {
  /// Text editing controller
  final TextEditingController controller;

  /// Hint text displayed in the search field
  final String hintText;

  /// Callback when text changes
  final ValueChanged<String>? onChanged;

  /// Callback when clear button is tapped
  final VoidCallback? onClear;

  /// Callback when submit is triggered
  final ValueChanged<String>? onSubmitted;

  /// Custom prefix icon (defaults to search icon)
  final IconData prefixIcon;

  /// Whether the field is enabled
  final bool isEnabled;

  /// Maximum lines for the input
  final int maxLines;

  /// Obscure text (for password fields)
  final bool obscureText;

  /// Input decoration customization
  final String? labelText;

  /// Error text to display
  final String? errorText;

  /// Custom text input action
  final TextInputAction textInputAction;

  /// Custom keyboard type
  final TextInputType keyboardType;

  /// Focus node for manual focus management
  final FocusNode? focusNode;

  /// Border radius of the field (null = use AppShapeConfig)
  final double? borderRadius;

  /// Content padding
  final EdgeInsets contentPadding;

  const SearchInputField({
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.prefixIcon = Icons.search,
    this.isEnabled = true,
    this.maxLines = 1,
    this.obscureText = false,
    this.labelText,
    this.errorText,
    this.textInputAction = TextInputAction.search,
    this.keyboardType = TextInputType.text,
    this.focusNode,
    this.borderRadius,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    super.key,
  });

  @override
  State<SearchInputField> createState() => _SearchInputFieldState();
}

class _SearchInputFieldState extends State<SearchInputField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _focusNode = widget.focusNode ?? FocusNode();

    _controller.addListener(_updateHasText);
    _focusNode.addListener(_updateFocusState);

    _updateHasText();
  }

  @override
  void didUpdateWidget(SearchInputField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_updateHasText);
      _controller = widget.controller;
      _controller.addListener(_updateHasText);
      _updateHasText();
    }

    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_updateFocusState);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_updateFocusState);
    }
  }

  void _updateHasText() {
    setState(() => _hasText = _controller.text.isNotEmpty);
  }

  void _updateFocusState() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _handleClear() {
    _controller.clear();
    widget.onClear?.call();
    _updateHasText();
    FocusScope.of(context).requestFocus(_focusNode);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateHasText);
    _focusNode.removeListener(_updateFocusState);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.isEnabled,
      maxLines: widget.maxLines,
      obscureText: widget.obscureText,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        errorText: widget.errorText,
        contentPadding: widget.contentPadding,

        // Prefix icon
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            widget.prefixIcon,
            color: _getIconColor(),
            size: AppButtonSizes.iconStandard,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 0,
          minHeight: 0,
        ),

        // Suffix icon (clear button)
        suffixIcon: _hasText
            ? _buildClearButton()
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 0,
          minHeight: 0,
        ),

        // Border styling
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? AppShapeConfig.textFieldRadius),
          borderSide: const BorderSide(color: AppColors.divider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? AppShapeConfig.textFieldRadius),
          borderSide: const BorderSide(color: AppColors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? AppShapeConfig.textFieldRadius),
          borderSide: const BorderSide(
            color: AppColors.primaryLight,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? AppShapeConfig.textFieldRadius),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? AppShapeConfig.textFieldRadius),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),

        // Filled styling
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }

  Widget _buildClearButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isEnabled ? _handleClear : null,
          borderRadius: AppBorders.borderRadiusSmall,
          child: Icon(
            Icons.close,
            color: _hasText ? AppColors.textSecondary : Colors.transparent,
            size: AppButtonSizes.iconStandard,
          ),
        ),
      ),
    );
  }

  Color _getIconColor() {
    if (!widget.isEnabled) {
      return AppColors.textMuted;
    }

    if (widget.errorText != null) {
      return AppColors.error;
    }

    if (_isFocused) {
      return AppColors.primary;
    }

    return AppColors.textMuted;
  }
}
