import 'dart:async';
import 'package:flutter/material.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/profanity/profanity_filter_service.dart';

/// Extensible text field with profanity filtering
class ProfanityFilteredTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final InputDecoration? decoration;
  final TextStyle? style;
  final String? language;
  final bool showProfanityError;
  final String? profanityErrorMessage;
  final Duration? debounceDuration;
  final bool useSubstringMatching; // New parameter for substring matching
  final String? context; // New parameter for context (e.g., 'display_name', 'bio', 'chat')

  const ProfanityFilteredTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.validator,
    this.decoration,
    this.style,
    this.language,
    this.showProfanityError = true,
    this.profanityErrorMessage,
    this.debounceDuration,
    this.useSubstringMatching = false, // Default to false for backward compatibility
    this.context,
  });

  @override
  State<ProfanityFilteredTextField> createState() => _ProfanityFilteredTextFieldState();
}

class _ProfanityFilteredTextFieldState extends State<ProfanityFilteredTextField> {
  late final TextEditingController _controller;
  late final ProfanityFilterService _profanityFilter;
  Timer? _debounceTimer;
  String? _profanityError;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _profanityFilter = sl<ProfanityFilterService>();
    _initializeFilter();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeFilter() async {
    await _profanityFilter.initialize();
    if (!mounted) return;
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void didUpdateWidget(ProfanityFilteredTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    }
  }

  void _onTextChanged(String value) {
    widget.onChanged?.call(value);

    if (!_isInitialized || !_profanityFilter.config.enabled) {
      return;
    }

    // Cancel previous timer
    _debounceTimer?.cancel();

    // For real-time validation, check immediately
    if (_profanityFilter.config.realTimeValidation) {
      _checkProfanity(value);
      return;
    }

    // Otherwise, debounce the check
    final debounceMs = widget.debounceDuration?.inMilliseconds ??
                      _profanityFilter.config.debounceMs;

    _debounceTimer = Timer(Duration(milliseconds: debounceMs), () {
      _checkProfanity(value);
    });
  }

  Future<void> _checkProfanity(String text) async {
    final result = widget.useSubstringMatching
        ? await _profanityFilter.checkProfanitySubstring(text, language: widget.language, context: widget.context)
        : await _profanityFilter.checkProfanity(text, language: widget.language, context: widget.context);

    if (!mounted) return;
    setState(() {
      if (result.containsProfanity && widget.showProfanityError) {
        _profanityError = widget.profanityErrorMessage ??
                         'This content contains inappropriate language. Please revise your input.';
      } else {
        _profanityError = null;
      }
    });
  }

  String? _combinedValidator(String? value) {
    // First check custom validator
    final customError = widget.validator?.call(value);
    if (customError != null) return customError;

    // Then check profanity error
    if (_profanityError != null) return _profanityError;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDecoration = (widget.decoration ?? const InputDecoration()).copyWith(
      labelText: widget.labelText,
      hintText: widget.hintText,
      errorText: _profanityError ?? widget.errorText,
    );

    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      style: widget.style,
      decoration: effectiveDecoration,
      validator: _combinedValidator,
      onChanged: _onTextChanged,
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onSubmitted,
    );
  }
}

/// Note: Extension method removed temporarily due to property access issues.
/// Use ProfanityFilteredTextField directly for now.