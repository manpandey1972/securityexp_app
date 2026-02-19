import 'package:flutter/material.dart';
import 'package:greenhive_app/core/validators/display_name_validator.dart';
import 'package:provider/provider.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/shared/themes/app_shape_config.dart';
import 'package:greenhive_app/shared/themes/app_shape_extensions.dart';
import 'package:greenhive_app/shared/widgets/app_button_variants.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/profile/presentation/view_models/user_profile_view_model.dart';
import 'package:greenhive_app/features/profile/widgets/profile_widgets.dart';
import 'package:greenhive_app/shared/widgets/profile_picture_widget.dart';
import 'package:greenhive_app/data/models/skill.dart';
import 'package:greenhive_app/shared/widgets/profanity_filtered_text_field.dart';

/// User profile page with Provider state management
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserProfileViewModel>(
      create: (_) => sl<UserProfileViewModel>()..initialize(),
      child: const _UserProfilePageView(),
    );
  }
}

class _UserProfilePageView extends StatefulWidget {
  const _UserProfilePageView();

  @override
  State<_UserProfilePageView> createState() => _UserProfilePageViewState();
}

class _UserProfilePageViewState extends State<_UserProfilePageView> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _skillSearchCtrl = TextEditingController();

  // Store ViewModel reference to safely remove listener in dispose
  UserProfileViewModel? _viewModel;

  @override
  void initState() {
    super.initState();

    // Add listeners to update ViewModel when text changes
    _displayNameCtrl.addListener(_onDisplayNameChanged);
    _bioCtrl.addListener(_onBioChanged);

    // Listen to ViewModel changes to populate controllers when data loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel = context.read<UserProfileViewModel>();
      _viewModel!.addListener(_updateControllersFromState);
      _updateControllersFromState();
    });
  }

  void _onDisplayNameChanged() {
    final viewModel = _viewModel;
    if (viewModel != null &&
        _displayNameCtrl.text != viewModel.state.displayName) {
      viewModel.setDisplayName(_displayNameCtrl.text);
    }
  }

  void _onBioChanged() {
    final viewModel = _viewModel;
    if (viewModel != null && _bioCtrl.text != viewModel.state.bio) {
      viewModel.setBio(_bioCtrl.text);
    }
  }

  void _updateControllersFromState() {
    final viewModel = _viewModel;
    if (viewModel == null) return;
    final state = viewModel.state;

    // Update display name if needed
    if (_displayNameCtrl.text != state.displayName &&
        state.displayName.isNotEmpty) {
      _displayNameCtrl.text = state.displayName;
    }

    // Update bio if needed
    if (_bioCtrl.text != state.bio && state.bio.isNotEmpty) {
      _bioCtrl.text = state.bio;
    }
  }

  @override
  void dispose() {
    // Remove listeners using stored reference (safe during dispose)
    _viewModel?.removeListener(_updateControllersFromState);
    _displayNameCtrl.removeListener(_onDisplayNameChanged);
    _bioCtrl.removeListener(_onBioChanged);
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _skillSearchCtrl.dispose();
    super.dispose();
  }

  void _showProfilePictureOptions(BuildContext context) {
    final viewModel = context.read<UserProfileViewModel>();
    final profile = viewModel.state.profile;

    if (profile == null) return;

    showProfilePictureOptions(
      context: context,
      hasProfilePicture: profile.hasProfilePicture == true,
      onTakePhoto: _takePhoto,
      onPickImage: _pickImage,
      onDeletePhoto: _deleteProfilePicture,
    );
  }

  Future<void> _takePhoto() async {
    final viewModel = context.read<UserProfileViewModel>();
    final imageFile = await viewModel.takePhotoWithCamera();
    if (imageFile != null) {
      await viewModel.uploadProfilePicture(imageFile);
    }
  }

  Future<void> _pickImage() async {
    final viewModel = context.read<UserProfileViewModel>();
    final imageFile = await viewModel.pickImageFromGallery();
    if (imageFile != null) {
      await viewModel.uploadProfilePicture(imageFile);
    }
  }

  Future<void> _deleteProfilePicture() async {
    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Profile Picture?',
          style: AppTypography.bodyEmphasis,
        ),
        content: Text(
          'Are you sure you want to delete your profile picture?',
          style: AppTypography.bodyRegular,
        ),
        actions: [
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            label: 'Cancel',
          ),
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            label: 'Delete',
            isDestructive: true,
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final viewModel = context.read<UserProfileViewModel>();
    await viewModel.deleteProfilePicture();
  }

  void _showSkillSelectionModal(
    BuildContext context,
    UserProfileViewModel viewModel,
  ) {
    showSkillSelectionModal(context, viewModel, _skillSearchCtrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: Consumer<UserProfileViewModel>(
        builder: (context, viewModel, _) {
          final state = viewModel.state;

          if (state.loadingProfile) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${state.error}',
                    style: AppTypography.bodyRegular.copyWith(color: AppColors.error),
                  ),
                  SizedBox(height: AppSpacing.spacing16),
                  AppButtonVariants.compact(
                    onPressed: () => viewModel.refreshProfile(),
                    label: 'Retry',
                  ),
                ],
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile Picture Section
                Center(
                  child: GestureDetector(
                    onTap: () => _showProfilePictureOptions(context),
                    child: state.profile != null
                        ? Stack(
                            children: [
                              ProfilePictureWidget(
                                user: state.profile!,
                                size: 100,
                                showBorder: true,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: AppColors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const CircularProgressIndicator(),
                  ),
                ),
                SizedBox(height: AppSpacing.spacing24),

                // Display Name Section
                Text(
                  'Display Name *',
                  style: AppTypography.bodyEmphasis.copyWith(
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: AppSpacing.spacing8),
                ProfanityFilteredTextField(
                  controller: _displayNameCtrl,
                  maxLength: 32,
                  useSubstringMatching: true, // Enable substring matching for display names
                  context: 'display_name', // Context for display name filtering
                  decoration: const InputDecoration(
                    hintText: 'Enter your display name',
                  ),
                  validator: DisplayNameValidator.formValidator,
                ),
                SizedBox(height: AppSpacing.spacing20),

                // Role Display (read-only)
                Text(
                  'Role',
                  style: AppTypography.bodyEmphasis,
                ),
                SizedBox(height: AppSpacing.spacing8),
                Builder(
                  builder: (context) {
                    final roles = <String>[];
                    if (state.isExpert) roles.add('Expert');
                    if (state.isMerchant) roles.add('Merchant');
                    if (!state.isExpert && !state.isMerchant) roles.add('Other');
                    return Row(
                      children: roles
                          .map((role) => Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  role,
                                  style: AppTypography.bodyRegular.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.spacing20),

                // Expert-Only Sections
                if (state.isExpert) ...[
                  // Bio Section
                  Text(
                    'About You (Bio)',
                    style: AppTypography.bodyEmphasis.copyWith(
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: AppSpacing.spacing8),
                  ProfanityFilteredTextField(
                    controller: _bioCtrl,
                    maxLines: 5,
                    minLines: 3,
                    context: 'bio', // Context for bio filtering
                    decoration: InputDecoration(
                      hintText: 'Describe yourself...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ).withRoundedShape(radius: AppShapeConfig.roundedRadius),
                  ),
                  SizedBox(height: AppSpacing.spacing20),

                  // Skills Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Skills *',
                        style: AppTypography.bodyEmphasis.copyWith(
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Consumer<UserProfileViewModel>(
                        builder: (context, viewModel, _) {
                          return IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh skills',
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: viewModel.state.loadingSkills
                                ? null
                                : () async {
                                    await viewModel.refreshSkills();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Skills refreshed'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.spacing12),
                  GestureDetector(
                    onTap: () => _showSkillSelectionModal(context, viewModel),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppShapeConfig.roundedRadius),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${state.selectedSkillIds.length} of ${state.allSkills.length} skills selected',
                                  style: AppTypography.bodyEmphasis.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (state.selectedSkillIds.isNotEmpty) ...[
                                  SizedBox(height: AppSpacing.spacing4),
                                  Text(
                                    'Tap to manage skills',
                                    style: AppTypography.captionSmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Icon(Icons.edit, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (state.selectedSkillIds.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.spacing12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.selectedSkillIds.map((skillId) {
                        final allSkills = state.allSkills.whereType<Skill>();
                        final skill = allSkills.firstWhere(
                          (s) => s.id == skillId,
                          orElse: () => Skill(
                            id: skillId,
                            name: skillId,
                            category: '',
                            tags: [],
                          ),
                        );
                        return Chip(
                          label: Text(skill.name),
                          onDeleted: () {
                            viewModel.toggleSkill(skillId);
                          },
                          backgroundColor: AppColors.primary,
                          labelStyle: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textPrimary),
                        );
                      }).toList(),
                    ),
                  ],
                  SizedBox(height: AppSpacing.spacing24),

                  // Languages Section
                  Text(
                    'Languages',
                    style: AppTypography.bodyEmphasis.copyWith(
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: AppSpacing.spacing12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserProfileViewModel.topLanguages.map((language) {
                      final isSelected = state.selectedLanguages.contains(
                        language,
                      );
                      return FilterChip(
                        label: Text(language),
                        selected: isSelected,
                        onSelected: (selected) {
                          viewModel.toggleLanguage(language);
                        },
                        backgroundColor: AppColors.surfaceVariant,
                        selectedColor: AppColors.primary,
                        labelStyle: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: AppSpacing.spacing24),
                ],

                // Storage Section
                const Divider(),
                SizedBox(height: AppSpacing.spacing16),
                Text(
                  'Storage',
                  style: AppTypography.bodyEmphasis.copyWith(
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: AppSpacing.spacing12),
                const StorageSection(),
                SizedBox(height: AppSpacing.spacing24),

                // Biometric Section (if available)
                if (state.biometricAvailable) ...[
                  const Divider(),
                  SizedBox(height: AppSpacing.spacing16),
                  Text(
                    'Security',
                    style: AppTypography.bodyEmphasis.copyWith(
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: AppSpacing.spacing12),
                  SwitchListTile(
                    title: const Text('Enable Biometric Login'),
                    subtitle: Text(
                      'Use ${state.biometricTypeName} to log in',
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: state.biometricEnabled,
                    onChanged: (value) {
                      viewModel.toggleBiometric(value);
                    },
                    activeThumbColor: AppColors.primary,
                  ),
                  SizedBox(height: AppSpacing.spacing20),
                ],

                // Save Button
                AppButtonVariants.secondary(
                  onPressed: (state.savingProfile || !state.isFormValid)
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            viewModel.submitForm();
                          }
                        },
                  label: 'Save Profile',
                  isLoading: state.savingProfile,
                  isEnabled: state.isFormValid,
                ),
                SizedBox(height: AppSpacing.spacing16),
              ],
            ),
          );
        },
      ),
    );
  }
}
