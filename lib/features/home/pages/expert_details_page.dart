import 'package:flutter/material.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/features/profile/services/skills_service.dart';
import 'package:greenhive_app/features/ratings/data/models/rating.dart';
import 'package:greenhive_app/features/ratings/services/rating_service.dart';
import 'package:greenhive_app/features/ratings/widgets/expert_rating_summary.dart';
import 'package:greenhive_app/features/ratings/widgets/rating_card.dart';
import 'package:greenhive_app/features/ratings/pages/expert_reviews_page.dart';
import 'package:greenhive_app/shared/widgets/profile_picture_widget.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/shared/themes/app_card_styles.dart';

class ExpertDetailsPage extends StatefulWidget {
  final models.User expert; // Required user object

  const ExpertDetailsPage({super.key, required this.expert});

  @override
  State<ExpertDetailsPage> createState() => _ExpertDetailsPageState();
}

class _ExpertDetailsPageState extends State<ExpertDetailsPage> {
  late final SkillsService _skillsService;
  late final RatingService _ratingService;
  final Map<String, String> _skillIdToName = {};
  bool _loadingSkills = false;
  bool _loadingRatings = false;
  double _averageRating = 0.0;
  int _totalRatings = 0;
  List<Rating> _recentRatings = [];
  final _log = sl<AppLogger>();
  static const _tag = 'ExpertDetailsPage';

  @override
  void initState() {
    super.initState();
    _skillsService = sl<SkillsService>();
    _ratingService = sl<RatingService>();
    _loadSkills();
    _loadRatings();
  }

  Future<void> _loadSkills() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        setState(() => _loadingSkills = true);
        final skills = await _skillsService.getAllSkills();
        final map = <String, String>{};
        for (final skill in skills) {
          map[skill.id] = skill.name;
        }
        if (mounted) {
          setState(() {
            _skillIdToName.clear();
            _skillIdToName.addAll(map);
            _loadingSkills = false;
          });
        }
      },
      onError: (error) {
        setState(() => _loadingSkills = false);
        _log.error('Error loading skills: $error', tag: _tag);
      },
    );
  }

  Future<void> _loadRatings() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        setState(() => _loadingRatings = true);

        // Load stats and recent ratings in parallel
        final statsFuture = _ratingService.getExpertRatingStats(widget.expert.id);
        final ratingsFuture = _ratingService.getExpertRatings(
          expertId: widget.expert.id,
          limit: 3,
        );

        final results = await Future.wait([statsFuture, ratingsFuture]);
        final stats = results[0] as Map<String, dynamic>;
        final ratings = results[1] as List<Rating>;

        if (mounted) {
          setState(() {
            _averageRating = (stats['averageRating'] as num?)?.toDouble() ?? 0.0;
            _totalRatings = (stats['totalRatings'] as int?) ?? 0;
            _recentRatings = ratings;
            _loadingRatings = false;
          });
        }
      },
      onError: (error) {
        setState(() => _loadingRatings = false);
        _log.error('Error loading ratings: $error', tag: _tag);
      },
    );
  }

  void _navigateToAllReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpertReviewsPage(
          expertId: widget.expert.id,
          expertName: widget.expert.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expert Profile')),
      body: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile section - centered
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile picture
                      ProfilePictureWidget(
                        user: widget.expert,
                        size: 72,
                        showBorder: true,
                      ),
                      SizedBox(height: AppSpacing.spacing12),
                      // Name
                      Text(
                        widget.expert.name,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: AppTypography.medium,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Rating summary below name
                      if (_totalRatings > 0 || !_loadingRatings) ...[
                        SizedBox(height: AppSpacing.spacing8),
                        ExpertRatingSummary(
                          averageRating: _averageRating,
                          totalRatings: _totalRatings,
                          onTap: _totalRatings > 0 ? _navigateToAllReviews : null,
                          variant: 'normal',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Content section - left aligned
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'About',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: AppTypography.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.spacing12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppCardStyle.filled,
                        child: Text(
                          widget.expert.bio?.isNotEmpty == true
                              ? widget.expert.bio!
                              : 'No bio available',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                height: 1.6,
                                color: widget.expert.bio?.isNotEmpty == true
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (widget.expert.expertises.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'Areas of Expertise',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: AppTypography.bold),
                        ),
                      ),
                      SizedBox(height: AppSpacing.spacing12),
                      _loadingSkills
                          ? const SizedBox(
                              height: 40,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: widget.expert.expertises.map((id) {
                                  final skillName = _skillIdToName.isNotEmpty
                                      ? _skillIdToName[id] ?? id
                                      : id;
                                  return Chip(
                                    label: Text(skillName),
                                    backgroundColor: AppColors.surfaceVariant,
                                    labelStyle: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                  );
                                }).toList(),
                              ),
                            ),
                      const SizedBox(height: 28),
                    ],
                    if (widget.expert.languages.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'Languages',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: AppTypography.bold),
                        ),
                      ),
                      SizedBox(height: AppSpacing.spacing12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.expert.languages
                              .map(
                                (l) => Chip(
                                  label: Text(l),
                                  backgroundColor: AppColors.surfaceVariant,
                                  labelStyle: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(color: AppColors.textPrimary),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                    // Reviews section
                    if (_recentRatings.isNotEmpty || _loadingRatings) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Reviews',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: AppTypography.bold),
                            ),
                            if (_totalRatings > _recentRatings.length)
                              TextButton(
                                onPressed: _navigateToAllReviews,
                                child: Text(
                                  'See all ($_totalRatings)',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.spacing12),
                      _loadingRatings
                          ? const SizedBox(
                              height: 80,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Column(
                                children: _recentRatings
                                    .map((rating) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: RatingCard(rating: rating),
                                        ))
                                    .toList(),
                              ),
                            ),
                      const SizedBox(height: 28),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
