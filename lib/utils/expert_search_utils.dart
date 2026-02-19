import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/features/profile/services/skills_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';

/// Utility service for expert search, filtering, and skill name mapping.
/// Centralizes all expert-related filtering logic for reuse across multiple pages.
///
/// Usage:
/// ```dart
/// final utils = ExpertSearchUtils();
///
/// // Load skills once and reuse
/// await utils.loadSkills();
///
/// // Filter experts
/// final filtered = utils.filterExperts(_experts, _searchQuery);
///
/// // Get skill name from ID
/// final skillName = utils.getSkillName(skillId);
/// ```
class ExpertSearchUtils {
  final SkillsService _skillsService = SkillsService();
  final AppLogger _log = sl<AppLogger>();
  final AnalyticsService _analytics = sl<AnalyticsService>();
  static const String _tag = 'ExpertSearchUtils';
  final Map<String, String> _skillIdToName = {};
  bool _skillsLoaded = false;

  /// Get the skill mapping cache
  Map<String, String> get skillIdToName => _skillIdToName;

  /// Check if skills are loaded
  bool get skillsLoaded => _skillsLoaded;

  /// Load all skills and build ID-to-name mapping
  /// Safe to call multiple times - will only load once unless reset
  Future<void> loadSkills() async {
    if (_skillsLoaded) return;

    try {
      final skills = await _skillsService.getAllSkills();
      _skillIdToName.clear();
      for (final skill in skills) {
        _skillIdToName[skill.id] = skill.name;
      }
      _skillsLoaded = true;
      _log.info('Loaded ${skills.length} skills', tag: _tag);
    } catch (e, stackTrace) {
      _log.error('Error loading skills', tag: _tag, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get skill name by ID, returns ID if not found
  String getSkillName(String skillId) {
    return _skillIdToName[skillId] ?? skillId;
  }

  /// Get all skill names for a list of skill IDs
  List<String> getSkillNames(List<String> skillIds) {
    return skillIds
        .where(
          (id) => _skillIdToName.containsKey(id) && _skillIdToName[id] != null,
        )
        .map((id) => _skillIdToName[id]!)
        .toList();
  }

  /// Filter experts by search query (name and skills)
  /// Returns new filtered list, does not modify original
  List<User> filterExperts(List<User> experts, String query) {
    // Start performance trace (non-blocking)
    final trace = _analytics.newTrace('expert_search_filter');
    trace.start();
    trace.putAttribute('expert_count', experts.length.toString());
    trace.putAttribute('has_query', query.trim().isNotEmpty.toString());
    
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      trace.stop();
      return experts;
    }

    final lowerQuery = trimmedQuery.toLowerCase();
    trace.putAttribute('query_length', trimmedQuery.length.toString());

    final results = experts.where((expert) {
      try {
        // Search by name
        if (expert.name.toLowerCase().contains(lowerQuery)) return true;

        // Search by skills
        final skillIds = expert.expertises;
        if (skillIds.isEmpty) return false;

        for (final id in skillIds) {
          final skillName = _skillIdToName[id];
          if (skillName != null &&
              skillName.toLowerCase().contains(lowerQuery)) {
            return true;
          }
        }

        return false;
      } catch (e, stackTrace) {
        _log.error('Error filtering expert ${expert.id}: $e', tag: _tag, stackTrace: stackTrace);
        // Include on error to avoid data loss
        return true;
      }
    }).toList();
    
    trace.putAttribute('results_count', results.length.toString());
    trace.stop();
    return results;
  }

  /// Search by multiple criteria (name, skills)
  /// Returns match score for sorting: 0 = no match, higher = better match
  int getSearchScore(User expert, String query) {
    final lowerQuery = query.toLowerCase();
    int score = 0;

    // Name match scores highest (2x)
    if (expert.name.toLowerCase().startsWith(lowerQuery)) {
      score += 20;
    } else if (expert.name.toLowerCase().contains(lowerQuery)) {
      score += 10;
    }

    // Skill matches score lower
    for (final skillId in expert.expertises) {
      final skillName = _skillIdToName[skillId];
      if (skillName != null && skillName.toLowerCase().contains(lowerQuery)) {
        score += 5;
      }
    }

    return score;
  }

  /// Sort experts by search relevance
  /// Returns new sorted list, does not modify original
  List<User> sortByRelevance(List<User> experts, String query) {
    if (query.trim().isEmpty) {
      return experts;
    }

    final list = [...experts];
    list.sort(
      (a, b) => getSearchScore(b, query).compareTo(getSearchScore(a, query)),
    );
    return list;
  }

  /// Build a formatted expertise string from skill IDs
  /// Example: "Flutter, Dart, Firebase"
  String buildExpertiseString(
    List<String> skillIds, {
    String separator = ', ',
  }) {
    final skillNames = getSkillNames(skillIds);
    return skillNames.join(separator);
  }

  /// Reset the skill cache (useful for testing or refreshing)
  void reset() {
    _skillIdToName.clear();
    _skillsLoaded = false;
    _log.debug('Cache reset', tag: _tag);
  }
}
