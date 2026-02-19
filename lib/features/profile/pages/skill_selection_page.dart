import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/data/models/skill.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/features/profile/services/skills_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

class SkillSelectionPage extends StatefulWidget {
  final List<String> initialSelectedSkillIds;

  const SkillSelectionPage({super.key, this.initialSelectedSkillIds = const []})
    : super();

  @override
  State<SkillSelectionPage> createState() => _SkillSelectionPageState();
}

class _SkillSelectionPageState extends State<SkillSelectionPage> {
  late final SkillsService _skillsService;
  List<Skill> _allSkills = [];
  List<Skill> _filteredSkills = [];
  Set<String> _selectedSkillIds = {};
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _skillsService = sl<SkillsService>();
    _selectedSkillIds = Set.from(widget.initialSelectedSkillIds);
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final skills = await _skillsService.getAllSkills();
        setState(() {
          _allSkills = skills;
          _filteredSkills = skills;
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading skills: $error')),
          );
        }
      },
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredSkills = _skillsService.searchSkills(query, _allSkills);
    });
  }

  void _toggleSkill(String skillId) {
    setState(() {
      if (_selectedSkillIds.contains(skillId)) {
        _selectedSkillIds.remove(skillId);
      } else {
        _selectedSkillIds.add(skillId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Group by category
    final grouped = _skillsService.groupByCategory(_filteredSkills);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Skills'),
        actions: [
          if (_selectedSkillIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: AppButtonVariants.compact(
                  onPressed: () {
                    Navigator.pop(context, _selectedSkillIds.toList());
                  },
                  label: 'Done (${_selectedSkillIds.length})',
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SearchBar(
                    hintText: 'Search skills...',
                    leading: const Icon(Icons.search),
                    onChanged: _onSearchChanged,
                  ),
                ),
                // Info text
                if (_searchQuery.isEmpty && _allSkills.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Total: ${_allSkills.length} skills',
                      style: AppTypography.subtitle,
                    ),
                  ),
                // Skills list grouped by category
                Expanded(
                  child: _filteredSkills.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No skills available'
                                : 'No skills match your search',
                            style: AppTypography.bodyRegular.copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final category = grouped.keys.elementAt(index);
                            final skills = grouped[category]!;

                            return ExpansionTile(
                              key: ValueKey(category),
                              title: Text(
                                category,
                                style: AppTypography.bodyEmphasis,
                              ),
                              subtitle: Text(
                                '${skills.length} skill${skills.length > 1 ? 's' : ''}',
                                style: AppTypography.captionSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              children: skills.map((skill) {
                                final isSelected = _selectedSkillIds.contains(
                                  skill.id,
                                );
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Material(
                                    color: isSelected
                                        ? AppColors.primary.withValues(
                                            alpha: 0.1,
                                          )
                                        : Colors.transparent,
                                    borderRadius: AppBorders.borderRadiusNormal,
                                    child: InkWell(
                                      onTap: () => _toggleSkill(skill.id),
                                      borderRadius: AppBorders.borderRadiusNormal,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.divider,
                                            width: isSelected ? 2 : 1,
                                          ),
                                          borderRadius: AppBorders.borderRadiusSmall,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : AppColors.textSecondary,
                                                  width: 2,
                                                ),
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : Colors.transparent,
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color: AppColors.white,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                skill.name,
                                                style: AppTypography.bodyEmphasis.copyWith(
                                                  fontWeight: isSelected
                                                      ? AppTypography.semiBold
                                                      : AppTypography.regular,
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : AppColors.background,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
