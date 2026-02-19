import 'package:flutter/material.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';
import 'package:greenhive_app/shared/widgets/app_button_variants.dart';

import '../services/support_service.dart';
import '../services/support_analytics.dart';
import '../presentation/view_models/new_ticket_view_model.dart';
import '../widgets/ticket_type_selector.dart';
import '../widgets/category_dropdown.dart';
import '../widgets/attachment_picker.dart';
import '../data/models/models.dart';

/// Page for creating a new support ticket.
class NewTicketPage extends StatefulWidget {
  /// Initial ticket type to pre-select.
  final TicketType? initialType;

  /// Initial description to pre-fill.
  final String? initialDescription;

  const NewTicketPage({
    super.key,
    this.initialType,
    this.initialDescription,
  });

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  late final NewTicketViewModel _viewModel;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _viewModel = NewTicketViewModel(supportService: sl<SupportService>());
    _viewModel.addListener(_onViewModelChanged);

    // Apply initial values if provided
    if (widget.initialType != null) {
      _viewModel.setType(widget.initialType);
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
      _viewModel.setDescription(widget.initialDescription!);
    }
  }

  void _onViewModelChanged() {
    final state = _viewModel.state;

    // Show success message and pop
    if (state.successMessage != null) {
      SnackbarService.show(state.successMessage!);
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _subjectFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('New Ticket'),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final state = _viewModel.state;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error banner
                if (state.error != null) _buildErrorBanner(state.error!),

                // Ticket type selector
                TicketTypeSelector(
                  selectedType: state.type,
                  onSelected: (type) {
                    _viewModel.setType(type);
                    // Track ticket started when type is first selected
                    if (state.type == null) {
                      sl<SupportAnalytics>().trackTicketStarted(type: type);
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Category dropdown
                CategoryDropdown(
                  selectedCategory: state.category,
                  onChanged: _viewModel.setCategory,
                  hasError: state.hasAttemptedSubmit && state.category == null,
                ),
                const SizedBox(height: 24),

                // Subject field
                _buildSubjectField(),
                const SizedBox(height: 24),

                // Description field
                _buildDescriptionField(),
                const SizedBox(height: 24),

                // Attachments
                AttachmentPicker(
                  attachments: state.attachments,
                  onPickImage: _viewModel.pickImageFromGallery,
                  onTakePhoto: _viewModel.takePhoto,
                  onPickFile: _viewModel.pickFile,
                  onRemove: _viewModel.removeAttachment,
                ),
                const SizedBox(height: 32),

                // Submit button
                ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) {
                    final state = _viewModel.state;
                    return AppButtonVariants.secondary(
                      onPressed: state.isSubmitting || !state.isValid
                          ? null
                          : _submitTicket,
                      label: 'Submit Ticket',
                      isLoading: state.isSubmitting,
                      isEnabled: state.isValid,
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.error, size: 18),
            onPressed: _viewModel.clearError,
            constraints: BoxConstraints.tight(const Size(24, 24)),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectField() {
    final state = _viewModel.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subject',
              style: AppTypography.bodyRegular.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${state.subject.length}/100',
              style: AppTypography.captionSmall.copyWith(
                color: state.subjectCharsRemaining < 10
                    ? AppColors.error
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _subjectController,
          focusNode: _subjectFocusNode,
          maxLength: 100,
          maxLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Brief summary of your issue',
            hintStyle: AppTypography.bodyRegular.copyWith(
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: state.subjectError != null
                    ? AppColors.error
                    : AppColors.divider,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: state.subjectError != null
                    ? AppColors.error
                    : AppColors.divider,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorText: state.subjectError,
            counterText: '',
          ),
          style: AppTypography.bodyRegular,
          onChanged: _viewModel.setSubject,
          onSubmitted: (_) => _descriptionFocusNode.requestFocus(),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    final state = _viewModel.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Description',
              style: AppTypography.bodyRegular.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${state.description.length}/5000',
              style: AppTypography.captionSmall.copyWith(
                color: state.descriptionCharsRemaining < 100
                    ? AppColors.error
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          focusNode: _descriptionFocusNode,
          maxLength: 5000,
          maxLines: 8,
          minLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText:
                'Please describe your issue in detail...\n\nInclude:\n• Steps to reproduce (for bugs)\n• What you expected vs what happened\n• Any relevant details',
            hintStyle: AppTypography.bodyRegular.copyWith(
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: state.descriptionError != null
                    ? AppColors.error
                    : AppColors.divider,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: state.descriptionError != null
                    ? AppColors.error
                    : AppColors.divider,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorText: state.descriptionError,
            counterText: '',
            alignLabelWithHint: true,
          ),
          style: AppTypography.bodyRegular,
          onChanged: _viewModel.setDescription,
        ),
      ],
    );
  }

  Future<void> _submitTicket() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    await _viewModel.submit();
  }
}
