import 'package:flutter/material.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/admin/services/admin_skills_service.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_shape_config.dart';
import 'package:securityexperts_app/shared/themes/app_shape_extensions.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_section_wrapper.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';

/// Page for creating or editing a skill.
class AdminSkillEditorPage extends StatefulWidget {
  final String? skillId;

  const AdminSkillEditorPage({super.key, this.skillId});

  @override
  State<AdminSkillEditorPage> createState() => _AdminSkillEditorPageState();
}

class _AdminSkillEditorPageState extends State<AdminSkillEditorPage> {
  late final AdminSkillsService _skillsService;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  List<SkillCategory> _categories = [];
  String _selectedCategoryId = '';
  bool _isActive = true;
  bool _isLoading = true;
  bool _isSaving = false;
  AdminSkill? _existingSkill;

  bool get _isEditing => widget.skillId != null;

  @override
  void initState() {
    super.initState();
    _skillsService = sl<AdminSkillsService>();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _categories = await _skillsService.getCategories();

      if (_isEditing) {
        _existingSkill = await _skillsService.getSkill(widget.skillId!);
        if (_existingSkill != null) {
          _nameController.text = _existingSkill!.name;
          _descriptionController.text = _existingSkill!.description ?? '';
          _tagsController.text = _existingSkill!.tags.join(', ');
          // Find category ID from name
          final cat = _categories.firstWhere(
            (c) => c.name == _existingSkill!.category,
            orElse: () => SkillCategory(
              id: '',
              name: _existingSkill!.category,
              order: 0,
              createdAt: DateTime.now(),
            ),
          );
          _selectedCategoryId = cat.id;
          _isActive = _existingSkill!.isActive;
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

  Future<void> _saveSkill() async {
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

      String? skillId;

      if (_isEditing) {
        // Find category name from ID
        final selectedCat = _categories.firstWhere(
          (c) => c.id == _selectedCategoryId,
          orElse: () => _categories.first,
        );
        final success = await _skillsService.updateSkill(
          widget.skillId!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: selectedCat.name,
          tags: tags,
          isActive: _isActive,
        );
        if (success) {
          skillId = widget.skillId;
        }
      } else {
        // Find category name from ID
        final selectedCat = _categories.firstWhere(
          (c) => c.id == _selectedCategoryId,
          orElse: () => _categories.first,
        );
        skillId = await _skillsService.createSkill(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: selectedCat.name,
          tags: tags,
          isActive: _isActive,
        );
      }

      if (skillId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Skill updated' : 'Skill created'),
          ),
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save skill')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving skill: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminRouteGuard(
      minimumRole: UserRole.admin,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(
            _isEditing ? 'Edit Skill' : 'New Skill',
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
                      // Name
                      Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Basic Info',
                                style: AppTypography.bodyEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  hintText: 'e.g., Plant Care',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Name is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

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
                                        Text(c.icon ?? '🛠️'),
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

                      // Description
                      Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Description',
                                style: AppTypography.bodyEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  hintText: 'Describe this skill...',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ).withRoundedShape(radius: AppShapeConfig.roundedRadius),
                                maxLines: 4,
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
                                decoration: InputDecoration(
                                  hintText: 'gardening, indoor, outdoor',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Separate tags with commas. Used for search and filtering.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Active toggle
                      Card(
                        color: AppColors.surface,
                        child: SwitchListTile(
                          title: Text(
                            'Active',
                            style: AppTypography.bodyRegular.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _isActive
                                ? 'Skill is visible to experts'
                                : 'Skill is hidden from experts',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          value: _isActive,
                          onChanged: (value) {
                            setState(() => _isActive = value);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      AppButtonVariants.secondary(
                        onPressed: _isSaving ? null : _saveSkill,
                        label: _isEditing ? 'Update Skill' : 'Create Skill',
                        isLoading: _isSaving,
                      ),

                      // Stats for existing skill
                      if (_existingSkill != null) ...[
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
                                _StatRow(
                                  icon: Icons.trending_up,
                                  label: 'Usage count',
                                  value: '${_existingSkill!.usageCount}',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Created: ${_formatDate(_existingSkill!.createdAt)}',
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

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.bodyEmphasis.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
