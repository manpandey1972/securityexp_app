import 'package:flutter/material.dart';
import 'package:securityexperts_app/features/admin/data/models/faq.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

/// Bottom sheet editor for FAQ categories.
class CategoryEditorSheet extends StatefulWidget {
  final FaqCategory? category;
  final Future<void> Function({
    required String name,
    required String description,
    required String icon,
  }) onSave;

  const CategoryEditorSheet({
    super.key,
    this.category,
    required this.onSave,
  });

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _iconController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descController = TextEditingController(text: widget.category?.description ?? '');
    _iconController = TextEditingController(text: widget.category?.icon ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        name: _nameController.text,
        description: _descController.text,
        icon: _iconController.text.isEmpty ? '📋' : _iconController.text,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.category == null ? 'New Category' : 'Edit Category',
            style: AppTypography.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _iconController,
            decoration: const InputDecoration(
              labelText: 'Icon (emoji)',
              border: OutlineInputBorder(),
              hintText: '📱',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.category == null ? 'Create' : 'Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Show category editor bottom sheet
Future<void> showCategoryEditor(
  BuildContext context, {
  FaqCategory? category,
  required Future<void> Function({
    required String name,
    required String description,
    required String icon,
  }) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => CategoryEditorSheet(
      category: category,
      onSave: onSave,
    ),
  );
}
