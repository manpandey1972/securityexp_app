import 'package:flutter/material.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/admin/data/models/faq.dart';
import 'package:greenhive_app/features/admin/services/admin_faq_service.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/themes/app_shape_config.dart';
import 'package:greenhive_app/shared/themes/app_shape_extensions.dart';
import 'package:greenhive_app/features/admin/widgets/admin_section_wrapper.dart';
import 'package:greenhive_app/shared/widgets/app_button_variants.dart';
import 'package:greenhive_app/core/permissions/permission_types.dart';

/// Page for creating or editing an FAQ.
class AdminFaqEditorPage extends StatefulWidget {
  final String? faqId;

  const AdminFaqEditorPage({super.key, this.faqId});

  @override
  State<AdminFaqEditorPage> createState() => _AdminFaqEditorPageState();
}

class _AdminFaqEditorPageState extends State<AdminFaqEditorPage> {
  late final AdminFaqService _faqService;
  final _formKey = GlobalKey<FormState>();

  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _tagsController = TextEditingController();

  List<FaqCategory> _categories = [];
  String _selectedCategoryId = '';
  bool _isPublished = false;
  bool _isLoading = true;
  bool _isSaving = false;
  Faq? _existingFaq;

  bool get _isEditing => widget.faqId != null;

  @override
  void initState() {
    super.initState();
    _faqService = sl<AdminFaqService>();
    _loadData();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _categories = await _faqService.getCategories();

      if (_isEditing) {
        _existingFaq = await _faqService.getFaq(widget.faqId!);
        if (_existingFaq != null) {
          _questionController.text = _existingFaq!.question;
          _answerController.text = _existingFaq!.answer;
          _tagsController.text = _existingFaq!.tags.join(', ');
          _selectedCategoryId = _existingFaq!.categoryId ?? '';
          _isPublished = _existingFaq!.isPublished;
        }
      } else if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first.id;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _saveFaq() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      String? faqId;

      if (_isEditing) {
        final success = await _faqService.updateFaq(
          widget.faqId!,
          question: _questionController.text.trim(),
          answer: _answerController.text.trim(),
          categoryId: _selectedCategoryId,
          tags: tags,
          isPublished: _isPublished,
        );
        if (success) {
          faqId = widget.faqId;
        }
      } else {
        faqId = await _faqService.createFaq(
          question: _questionController.text.trim(),
          answer: _answerController.text.trim(),
          categoryId: _selectedCategoryId,
          tags: tags,
          isPublished: _isPublished,
        );
      }

      if (faqId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'FAQ updated' : 'FAQ created'),
          ),
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save FAQ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving FAQ: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminRouteGuard(
      minimumRole: UserRole.support,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(
            _isEditing ? 'Edit FAQ' : 'New FAQ',
            style: AppTypography.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Category selector
                      Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Category',
                                style: AppTypography.bodyEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategoryId.isEmpty
                                    ? null
                                    : _selectedCategoryId,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                ),
                                hint: const Text('Select category'),
                                items: _categories.map((c) {
                                  return DropdownMenuItem(
                                    value: c.id,
                                    child: Row(
                                      children: [
                                        Text(c.icon ?? '📋'),
                                        const SizedBox(width: 8),
                                        Text(c.name),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => _selectedCategoryId = value ?? '');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Question
                      Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question',
                                style: AppTypography.bodyEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _questionController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter the question...',
                                ).withRoundedShape(radius: AppShapeConfig.roundedRadius),
                                maxLines: 2,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Question is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Answer
                      Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Answer',
                                style: AppTypography.bodyEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _answerController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter the answer...',
                                ).withRoundedShape(radius: AppShapeConfig.roundedRadius),
                                maxLines: 8,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Answer is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Supports basic Markdown formatting',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tags',
                                style: AppTypography.bodyEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _tagsController,
                                decoration: const InputDecoration(
                                  hintText: 'tag1, tag2, tag3',
                                ).withRoundedShape(radius: AppShapeConfig.roundedRadius),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Separate tags with commas',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Publish toggle
                      Card(
                        color: AppColors.surface,
                        child: SwitchListTile(
                          title: Text(
                            'Publish',
                            style: AppTypography.bodyRegular.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _isPublished
                                ? 'FAQ is visible to users'
                                : 'FAQ is saved as draft',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          value: _isPublished,
                          onChanged: (value) {
                            setState(() => _isPublished = value);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      AppButtonVariants.secondary(
                        onPressed: _isSaving ? null : _saveFaq,
                        label: _isEditing ? 'Update FAQ' : 'Create FAQ',
                        isLoading: _isSaving,
                      ),

                      // Stats for existing FAQ
                      if (_existingFaq != null) ...[
                        const SizedBox(height: 24),
                        Card(
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Statistics',
                                  style: AppTypography.bodyEmphasis.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _StatItem(
                                      icon: Icons.visibility,
                                      label: 'Views',
                                      value: '${_existingFaq!.viewCount}',
                                    ),
                                    const SizedBox(width: 24),
                                    _StatItem(
                                      icon: Icons.thumb_up,
                                      label: 'Helpful',
                                      value: '${_existingFaq!.helpfulCount}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Created: ${_formatDate(_existingFaq!.createdAt)}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (_existingFaq!.updatedAt != null)
                                  Text(
                                    'Updated: ${_formatDate(_existingFaq!.updatedAt!)}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
