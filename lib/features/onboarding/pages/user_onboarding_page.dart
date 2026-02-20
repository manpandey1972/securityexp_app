import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/core/validators/display_name_validator.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_borders.dart';
import 'package:securityexperts_app/shared/themes/app_shape_extensions.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/providers/auth_provider.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/services/firebase_messaging_service.dart';
import 'package:securityexperts_app/features/chat/services/user_presence_service.dart';
import 'package:securityexperts_app/features/calling/infrastructure/repositories/voip_token_repository.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/data/models/models.dart' as models;
import 'package:securityexperts_app/data/models/skill.dart';
import 'package:securityexperts_app/features/onboarding/presentation/view_models/onboarding_view_model.dart';
import 'package:securityexperts_app/shared/services/event_bus.dart';
import 'package:securityexperts_app/features/home/pages/home_page.dart';
import 'package:securityexperts_app/shared/themes/app_spacing.dart';
import 'package:securityexperts_app/shared/widgets/profanity_filtered_text_field.dart';
import 'package:flutter_radio_group/flutter_radio_group.dart';

/// User onboarding page with Provider state management
class UserOnboardingPage extends StatelessWidget {
  const UserOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OnboardingViewModel>(
      create: (_) => sl<OnboardingViewModel>()..initialize(),
      child: const _UserOnboardingPageView(),
    );
  }
}

class _UserOnboardingPageView extends StatefulWidget {
  const _UserOnboardingPageView();

  @override
  State<_UserOnboardingPageView> createState() =>
      _UserOnboardingPageViewState();
}

class _UserOnboardingPageViewState extends State<_UserOnboardingPageView> {
  late final UserRepository _userRepository;
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _skillSearchCtrl = TextEditingController();
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'UserOnboardingPage';

  bool _loading = true;
  String? _error;

  // Named listener methods for proper cleanup
  void _onDisplayNameChanged() {
    final viewModel = context.read<OnboardingViewModel>();
    if (_displayNameCtrl.text != viewModel.state.displayName) {
      viewModel.setDisplayName(_displayNameCtrl.text);
    }
  }

  void _onBioChanged() {
    final viewModel = context.read<OnboardingViewModel>();
    if (_bioCtrl.text != viewModel.state.bio) {
      viewModel.setBio(_bioCtrl.text);
    }
  }

  @override
  void initState() {
    super.initState();
    _userRepository = sl<UserRepository>();

    // Add listeners to update ViewModel when text changes
    _displayNameCtrl.addListener(_onDisplayNameChanged);
    _bioCtrl.addListener(_onBioChanged);

    _checkProfile();
  }

  @override
  void dispose() {
    _displayNameCtrl.removeListener(_onDisplayNameChanged);
    _bioCtrl.removeListener(_onBioChanged);
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _skillSearchCtrl.dispose();
    super.dispose();
  }

  Map<String, List<Skill>> _groupSkillsByCategory(List<Skill> skills) {
    final grouped = <String, List<Skill>>{};
    for (final skill in skills) {
      final category = skill.category.isNotEmpty ? skill.category : 'Other';
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(skill);
    }
    return grouped;
  }

  void _showSkillSelectionModal(OnboardingViewModel viewModel) {
    _skillSearchCtrl.clear();
    viewModel.searchSkills('');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => DraggableScrollableSheet(
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
                  controller: _skillSearchCtrl,
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
                          _skillSearchCtrl.text.isNotEmpty) {
                        return Center(
                          child: Text(
                            'No skills found',
                            style: AppTypography.captionSmall,
                          ),
                        );
                      }
                      return ListView(
                        controller: scrollController,
                        children: [
                          ..._buildSkillsList(context, viewModel, state),
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
    );
  }

  List<Widget> _buildSkillsList(
    BuildContext context,
    OnboardingViewModel viewModel,
    dynamic state,
  ) {
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
              style: AppTypography.bodyRegular.copyWith(
                fontWeight: AppTypography.bold,
              ),
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

  Future<void> _checkProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await ErrorHandler.handle<void>(
      operation: () async {
        final profile = await _userRepository.getCurrentUserProfile();
        if (profile != null && profile.name.trim().isNotEmpty) {
          UserProfileService().setUserProfile(profile);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
          return;
        }

        // Pre-fill fields if server returned other data
        if (profile != null && mounted) {
          _displayNameCtrl.text = profile.name;
          _bioCtrl.text = profile.bio ?? '';

          final viewModel = context.read<OnboardingViewModel>();
          viewModel.setDisplayName(profile.name);
          viewModel.setBio(profile.bio ?? '');
          viewModel.setIsExpert(profile.roles.contains('Expert'));
          viewModel.setIsMerchant(profile.roles.contains('Merchant'));

          for (final skillId in profile.expertises) {
            viewModel.toggleSkill(skillId);
          }
          for (final lang in profile.languages) {
            viewModel.toggleLanguage(lang);
          }
        }
      },
      fallback: null,
      onError: (error) {
        setState(() {
          _error = 'Failed to check profile: $error';
        });
      },
    );

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _createOrUpdate() async {
    final viewModel = context.read<OnboardingViewModel>();

    if (!_formKey.currentState!.validate()) return;

    await ErrorHandler.handle<void>(
      operation: () async {
        final userId = context.read<AuthState>().userId ?? '';

        final state = viewModel.state;
        final name = state.displayName.trim();

        // Build roles list
        final roles = <String>[];
        if (state.isExpert) roles.add('Expert');
        if (state.isMerchant) roles.add('Merchant');
        // If neither Expert nor Merchant, assign 'User' role (consumer)
        if (!state.isExpert && !state.isMerchant) roles.add('User');

        final userModel = models.User(
          id: userId,
          name: name,
          roles: roles,
          languages: state.selectedLanguages,
          expertises: state.selectedSkillIds,
          bio: state.bio.trim(),
        );

        final createdUser = await _userRepository.createUser(userModel);
        UserProfileService().setUserProfile(createdUser);
        EventBus().emitProfileUpdated();

        // Initialize FCM and VoIP tokens now that user document exists
        // This ensures tokens are saved to the newly created user document
        if (userId.isNotEmpty) {
          await _initializeTokenServices(userId);
        }

        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = 'Failed to create profile: $error';
          });
        }
      },
    );
  }

  /// Initialize FCM and VoIP token services for new user after profile creation
  Future<void> _initializeTokenServices(String userId) async {
    // Initialize user presence for push notification suppression
    try {
      await sl<UserPresenceService>().initialize();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to initialize user presence',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }

    // Initialize FCM for push notifications
    try {
      await sl<FirebaseMessagingService>().initialize(userId);
      _log.info('FCM initialized', tag: _tag);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to initialize FCM',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }

    // Initialize VoIP tokens for iOS CallKit push
    try {
      await sl<VoIPTokenRepository>().initialize(userId);
      _log.info('VoIP token sync initialized', tag: _tag);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to initialize VoIP token sync',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Security Experts'),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<OnboardingViewModel>(
        builder: (context, viewModel, _) {
          final state = viewModel.state;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: AppBorders.borderRadiusNormal,
                    ),
                    child: Text(
                      _error!,
                      style: AppTypography.bodyRegular.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.spacing16),
                ],
                if (state.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: AppBorders.borderRadiusNormal,
                    ),
                    child: Text(
                      state.error!,
                      style: AppTypography.bodyRegular.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.spacing16),
                ],
                Text(
                  "Let's set up your profile",
                  style: AppTypography.headingSmall,
                ),
                SizedBox(height: AppSpacing.spacing20),

                // Display Name
                Text('Display Name *', style: AppTypography.bodyEmphasis),
                SizedBox(height: AppSpacing.spacing8),
                ProfanityFilteredTextField(
                  controller: _displayNameCtrl,
                  maxLength: 32,
                  useSubstringMatching:
                      true, // Enable substring matching for display names
                  context: 'display_name', // Context for display name filtering
                  decoration: const InputDecoration(
                    hintText: 'Enter your display name',
                    border: OutlineInputBorder(),
                  ),
                  validator: DisplayNameValidator.formValidator,
                ),
                SizedBox(height: AppSpacing.spacing20),

                // Role Selection (Radio)
                Text('Select Your Role *', style: AppTypography.bodyEmphasis),
                SizedBox(height: AppSpacing.spacing8),
                FlutterRadioGroup(
                  titles: const ["Expert", "Merchant", "Other"],
                  labelStyle: AppTypography.bodyRegular,
                  labelVisible: false,
                  titleStyle: AppTypography.bodyRegular,
                  defaultSelected: state.isExpert
                      ? 0
                      : state.isMerchant
                      ? 1
                      : 2,
                  orientation: RGOrientation.HORIZONTAL,
                  activeColor: AppColors.primary,
                  onChanged: (index) {
                    if (index == 0) {
                      viewModel.setIsExpert(true);
                      viewModel.setIsMerchant(false);
                    } else if (index == 1) {
                      viewModel.setIsExpert(false);
                      viewModel.setIsMerchant(true);
                    } else {
                      viewModel.setIsExpert(false);
                      viewModel.setIsMerchant(false);
                    }
                  },
                ),

                // Expert-Only Sections
                if (state.isExpert) ...[
                  SizedBox(height: AppSpacing.spacing20),
                  // Bio
                  Text('About You (Bio)', style: AppTypography.bodyEmphasis),
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
                    ).withRoundedShape(radius: 8.0),
                  ),
                  SizedBox(height: AppSpacing.spacing20),

                  // Skills
                  Text('Skills *', style: AppTypography.bodyEmphasis),
                  SizedBox(height: AppSpacing.spacing12),
                  GestureDetector(
                    onTap: () => _showSkillSelectionModal(viewModel),
                    child: Card(
                      margin: EdgeInsets.zero,
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
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: AppTypography.semiBold,
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
                          onDeleted: () => viewModel.toggleSkill(skillId),
                          backgroundColor: AppColors.surfaceVariant,
                        );
                      }).toList(),
                    ),
                  ],
                  SizedBox(height: AppSpacing.spacing24),

                  // Languages
                  Text('Languages *', style: AppTypography.bodyEmphasis),
                  SizedBox(height: AppSpacing.spacing12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: OnboardingViewModel.topLanguages.map((language) {
                      final isSelected = state.selectedLanguages.contains(
                        language,
                      );
                      return FilterChip(
                        label: Text(language),
                        selected: isSelected,
                        onSelected: (selected) =>
                            viewModel.toggleLanguage(language),
                        backgroundColor: AppColors.surfaceVariant,
                        selectedColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                ],

                SizedBox(height: AppSpacing.spacing20),
                AppButtonVariants.secondary(
                  onPressed: (state.saving || state.displayName.trim().isEmpty)
                      ? null
                      : _createOrUpdate,
                  label: 'Continue',
                  isLoading: state.saving,
                  isEnabled: state.displayName.trim().isNotEmpty,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
