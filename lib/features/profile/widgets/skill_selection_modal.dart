import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/data/models/skill.dart';
import 'package:greenhive_app/features/profile/presentation/view_models/user_profile_view_model.dart';

/// Skills selection modal for profile page.
class SkillSelectionModal extends StatelessWidget {
  final UserProfileViewModel viewModel;
  final TextEditingController searchController;

  const SkillSelectionModal({
    super.key,
    required this.viewModel,
    required this.searchController,
  });

  Map<String, List<Skill>> _groupSkillsByCategory(List<Skill> skills) {
    final grouped = <String, List<Skill>>{};
    for (final skill in skills) {
      final category = skill.category.isNotEmpty ? skill.category : 'Other';
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(skill);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(38),
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (scrollContext, scrollController) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Select Skills',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: AppSpacing.spacing12),
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search skills...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => viewModel.searchSkills(value),
                    ),
                    SizedBox(height: AppSpacing.spacing12),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: viewModel,
                        builder: (context, _) {
                          final state = viewModel.state;
                          if (state.loadingSkills) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (state.filteredSkills.isEmpty &&
                              searchController.text.isNotEmpty) {
                            return Center(
                              child: Text(
                                'No skills found',
                                style: AppTypography.bodyRegular.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          }
                          return ListView(
                            controller: scrollController,
                            children: [
                              ..._buildSkillsList(context, state),
                              SizedBox(height: AppSpacing.spacing16),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSkillsList(BuildContext context, dynamic state) {
    final allSkills = state.filteredSkills.whereType<Skill>().toList();
    final grouped = _groupSkillsByCategory(allSkills);
    final widgets = <Widget>[];
    final sortedCategories = grouped.keys.toList()..sort();

    for (final category in sortedCategories) {
      final skills = grouped[category]!;

      widgets.add(
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              category,
              style: AppTypography.headingXSmall,
            ),
            subtitle: Text(
              '${skills.length} skill${skills.length > 1 ? 's' : ''}',
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            children: skills.map((skill) {
              final isSelected = state.selectedSkillIds.contains(skill.id);
              return CheckboxListTile(
                title: Text(skill.name),
                value: isSelected,
                onChanged: (selected) {
                  viewModel.toggleSkill(skill.id);
                },
                activeColor: AppColors.primary,
              );
            }).toList(),
          ),
        ),
      );
    }

    return widgets;
  }
}

/// Show skill selection modal
void showSkillSelectionModal(
  BuildContext context,
  UserProfileViewModel viewModel,
  TextEditingController searchController,
) {
  searchController.clear();
  viewModel.searchSkills('');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SkillSelectionModal(
      viewModel: viewModel,
      searchController: searchController,
    ),
  );
}
