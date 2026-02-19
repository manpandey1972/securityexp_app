import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/shared/services/profanity/profanity_models.dart';
import 'package:greenhive_app/shared/services/profanity/text_normalizer.dart';
import 'package:greenhive_app/shared/services/profanity/profanity_allowlist.dart';


/// Core profanity filtering service
class ProfanityFilterService {
  static ProfanityFilterService? _instance;
  static ProfanityFilterService get _singletonInstance {
    _instance ??= ProfanityFilterService._internal();
    return _instance!;
  }
  factory ProfanityFilterService() => _singletonInstance;
  ProfanityFilterService._internal() : _remoteConfig = FirebaseRemoteConfig.instance;

  // Constructor for testing with dependency injection
  @visibleForTesting
  ProfanityFilterService.withRemoteConfig(FirebaseRemoteConfig remoteConfig)
      : _remoteConfig = remoteConfig;

  final AppLogger _log = sl<AppLogger>();
  late final FirebaseRemoteConfig _remoteConfig;

  // Core data structures
  final Map<String, Set<String>> _profanityLists = {};
  final Map<String, RegExp> _compiledPatterns = {};
  final Map<String, RegExp> _substringPatterns = {};
  final Map<String, Map<String, String>> _wordSeverities = {}; // word -> severity mapping
  final Map<String, Map<String, String>> _normalizedToCanonical = {}; // normalized -> canonical word mapping
  final Map<String, RegExp> _consonantPatterns = {};
  final Map<String, Map<String, String>> _consonantToCanonical = {};

  // Configuration
  ProfanityConfig _config = const ProfanityConfig();
  bool _initialized = false;

  /// Get current configuration
  ProfanityConfig get config => _config;

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Initialize the profanity filter service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _log.info('Initializing ProfanityFilterService', tag: 'ProfanityFilter');

      // Load default configuration
      await _loadDefaultConfig();

      // Load bundled profanity lists
      await _loadBundledLists();

      // Setup remote config
      await _setupRemoteConfig();

      // Load remote configuration
      await _loadRemoteConfig();

      _initialized = true;
      _log.info('ProfanityFilterService initialized successfully', tag: 'ProfanityFilter');
    } catch (e, stackTrace) {
      _log.error('Failed to initialize ProfanityFilterService: $e', tag: 'ProfanityFilter', stackTrace: stackTrace);
      // Continue with default configuration
      _initialized = true;
    }
  }

  /// Convert word to consonant skeleton (remove vowels)
  String _toConsonantSkeleton(String word) {
    return toConsonantSkeleton(word);
  }

  /// Check if a position in text is at a word boundary
  bool _isWordBoundary(String text, int start, int end) {
    return isWordBoundary(text, start, end);
  }

  /// Downgrade severity for skeleton matches
  String _downgradeSeverity(String severity) {
    return downgradeSeverity(severity);
  }

  /// Load default configuration
  Future<void> _loadDefaultConfig() async {
    _config = const ProfanityConfig();
  }

  /// Load bundled profanity lists from assets
  Future<void> _loadBundledLists() async {
    try {
      // Load English list from base64 encoded asset (same format as Remote Config)
      await _loadBundledLdnoobwList('en');

      // Load other active languages (if any)
      for (final lang in _config.activeLanguages) {
        if (lang != 'en') {
          await _loadLanguageList(lang);
        }
      }
    } catch (e, stackTrace) {
      _log.error('Failed to load bundled lists: $e', tag: 'ProfanityFilter', stackTrace: stackTrace);
    }
  }

  /// Load profanity list for a specific language
  Future<void> _loadLanguageList(String language) async {
    try {
      final fileName = 'assets/profanity/$language.txt';
      final content = await rootBundle.loadString(fileName);

      final words = <String>{};
      final severities = <String, String>{};

      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        // Parse format: word or word:severity
        final parts = trimmed.split(':');
        final word = parts[0].toLowerCase();
        final severity = parts.length > 1 ? parts[1] : 'medium'; // Default severity

        words.add(word);
        severities[word] = severity;
      }

      _profanityLists[language] = words;
      _wordSeverities[language] = severities;

      // Compile regex pattern for efficient matching
      _compilePatterns(language);
      _compileSubstringPatterns(language);

      _log.debug('Loaded ${words.length} profanity words for $language', tag: 'ProfanityFilter');
    } catch (e, stackTrace) {
      _log.error('Failed to load profanity list for $language: $e', tag: 'ProfanityFilter', stackTrace: stackTrace);
    }
  }

  /// Compile regex patterns for efficient matching
  void _compilePatterns(String language) {
    final words = _profanityLists[language];
    if (words == null || words.isEmpty) return;

    final normalizedToOriginal = <String, String>{};
    final normalizedWords = <String>[];

    for (final word in words) {
      final normalized = _normalizeAggressive(word);
      // Only include alphabetic, reasonably long words (≥3)
      if (normalized.length >= 3 && RegExp(r'^[a-zA-Z\s]+$').hasMatch(normalized)) {
        normalizedToOriginal[normalized] = word;
        normalizedWords.add(normalized);
      }
    }

    if (normalizedWords.isEmpty) return;

    normalizedWords.sort((a, b) => b.length.compareTo(a.length));

    final escapedWords = normalizedWords.map((word) => RegExp.escape(word));
    final pattern = '(${escapedWords.join('|')})';

    _compiledPatterns[language] = RegExp(
      pattern,
      caseSensitive: false,
      multiLine: true,
    );

    _normalizedToCanonical[language] = normalizedToOriginal;

    // Compile consonant skeleton patterns
    final consonantMap = <String, String>{};
    final consonants = <String>[];

    for (final word in normalizedWords) {
      final skeleton = _toConsonantSkeleton(word);
      if (skeleton.length >= 3) {
        consonantMap[skeleton] = normalizedToOriginal[word]!;
        consonants.add(skeleton);
      }
    }

    if (consonants.isNotEmpty) {
      _consonantPatterns[language] = RegExp(
        '(${consonants.map(RegExp.escape).join('|')})',
        caseSensitive: false,
      );
      _consonantToCanonical[language] = consonantMap;
    }
  }

  /// Compile patterns for substring matching (usernames/display names)
  void _compileSubstringPatterns(String language) {
    final words = _profanityLists[language];
    if (words == null || words.isEmpty) return;

    // Use the normalized-to-canonical mapping from _compilePatterns
    // This ensures consistency in word matching
    final normalizedToOriginal = _normalizedToCanonical[language] ?? {};

    final normalizedWords = <String>[];

    for (final word in words) {
      // Normalize aggressively for substring matching and remove all spaces
      final normalized = _normalizeAggressive(word).replaceAll(' ', '');
      // Use minimum length of 3 for substring matching
      // We handle false positives via the allowlist instead of filtering by length
      if (normalized.length >= 3) {
        // Only add if not already in map (from _compilePatterns)
        if (!normalizedToOriginal.containsKey(normalized)) {
          normalizedToOriginal[normalized] = word;
        }
        normalizedWords.add(normalized);
      }
    }

    // Update the canonical mapping with any new entries
    _normalizedToCanonical[language] = normalizedToOriginal;

    if (normalizedWords.isEmpty) return;

    final escapedWords = normalizedWords.map(RegExp.escape);
    final pattern = escapedWords.join('|');

    _substringPatterns[language] = RegExp(
      pattern,
      caseSensitive: false,
      multiLine: true,
    );
  }

  /// Setup Firebase Remote Config
  Future<void> _setupRemoteConfig() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Set default values
      await _remoteConfig.setDefaults({
        'profanity_enabled': true,
        'profanity_active_languages': json.encode(['en']),
        'profanity_check_leet_speak': true,
        'profanity_real_time_validation': false,
        'profanity_debounce_ms': 500,
        'profanity_use_remote_lists': false,
        'profanity_remote_list_url': '',
        'profanity_ldnoobw_list': '', // Base64 encoded LDNOOBW list
        'profanity_list_version': '1.0.0',
      });
    } catch (e, stackTrace) {
      _log.error('Failed to setup remote config: $e', tag: 'ProfanityFilter', stackTrace: stackTrace);
    }
  }

  /// Load configuration from remote config
  Future<void> _loadRemoteConfig() async {
    try {
      await _remoteConfig.fetchAndActivate();

      final newConfig = ProfanityConfig(
        enabled: _remoteConfig.getBool('profanity_enabled'),
        activeLanguages: List<String>.from(
          json.decode(_remoteConfig.getString('profanity_active_languages')),
        ),
        checkLeetSpeak: _remoteConfig.getBool('profanity_check_leet_speak'),
        realTimeValidation: _remoteConfig.getBool('profanity_real_time_validation'),
        debounceMs: _remoteConfig.getInt('profanity_debounce_ms'),
        useRemoteLists: _remoteConfig.getBool('profanity_use_remote_lists'),
        remoteListUrl: _remoteConfig.getString('profanity_remote_list_url'),
      );

      // Check if configuration changed
      if (_config.activeLanguages != newConfig.activeLanguages ||
          _config.useRemoteLists != newConfig.useRemoteLists) {
        _config = newConfig;
        // Reload lists if languages changed or remote lists enabled
        if (newConfig.useRemoteLists) {
          await _loadRemoteLists();
        } else {
          await _loadBundledLists();
        }
      } else {
        _config = newConfig;
      }

      _log.debug('Loaded remote config for profanity filter', tag: 'ProfanityFilter');
    } catch (e, stackTrace) {
      _log.error('Failed to load remote config: $e', tag: 'ProfanityFilter', stackTrace: stackTrace);
    }
  }

  /// Load profanity lists from remote sources (e.g., LDNOOBW)
  Future<void> _loadRemoteLists() async {
    try {
      // Try to load LDNOOBW list from Remote Config
      final ldnoobwList = _remoteConfig.getString('profanity_ldnoobw_list');
      if (ldnoobwList.isNotEmpty) {
        await _loadLdnoobwList(ldnoobwList);
      } else {
        // Fallback to bundled lists
        await _loadBundledLists();
      }
    } catch (e, stackTrace) {
      _log.error('Failed to load remote lists: $e', tag: 'ProfanityFilter', stackTrace: stackTrace);
      // Fallback to bundled lists
      await _loadBundledLists();
    }
  }

  /// Load LDNOOBW list from Remote Config
  Future<void> _loadLdnoobwList(String base64List) async {
    try {
      // Validate base64 string before decoding
      if (!isValidBase64(base64List)) {
        _log.warning('Invalid base64 format for LDNOOBW list, skipping', tag: 'ProfanityFilter');
        return;
      }

      // Decode base64 list
      final decoded = utf8.decode(base64.decode(base64List));
      final words = <String>{};
      final severities = <String, String>{};

      for (final line in decoded.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        // Parse LDNOOBW format: word or word:severity
        final parts = trimmed.split(':');
        final word = parts[0].toLowerCase();
        final severity = parts.length > 1 ? parts[1] : 'medium';

        words.add(word);
        severities[word] = severity;
      }

      _profanityLists['en'] = words;
      _wordSeverities['en'] = severities;

      _compilePatterns('en');
      _compileSubstringPatterns('en');

      _log.info('Loaded ${words.length} words from LDNOOBW list', tag: 'ProfanityFilter');
    } catch (e, stackTrace) {
      _log.error('Failed to load LDNOOBW list: $e', tag: 'ProfanityFilter', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Load bundled LDNOOBW list from assets (base64 encoded)
  Future<void> _loadBundledLdnoobwList(String language) async {
    try {
      final fileName = 'assets/profanity/$language.txt.b64';
      final base64Content = await rootBundle.loadString(fileName);

      // Use the same parsing logic as Remote Config
      await _loadLdnoobwList(base64Content);

      _log.debug('Loaded bundled LDNOOBW list for $language', tag: 'ProfanityFilter');
    } catch (e, stackTrace) {
      _log.error('Failed to load bundled LDNOOBW list for $language: $e', tag: 'ProfanityFilter', stackTrace: stackTrace);
      // Try fallback to plain text file
      await _loadLanguageList(language);
    }
  }

  /// Apply the full normalization pipeline to text
  /// Aggressive normalization for substring matching (removes all non-letters)
  String _normalizeAggressive(String text, {bool skipRepeatedChars = false}) {
    return normalizeAggressive(
      text,
      checkLeetSpeak: _config.checkLeetSpeak,
      skipRepeatedChars: skipRepeatedChars,
    );
  } 

  /// Check if text contains profanity (standard word boundary matching)
  Future<ProfanityResult> checkProfanity(String text, {String? language, String? context}) async {
    return await ErrorHandler.handle<ProfanityResult>(
      operation: () async {
        if (!_config.enabled || text.trim().isEmpty) {
          return ProfanityResult.clean();
        }

        final languagesToCheck = language != null ? [language] : _config.activeLanguages;
        final normalizedInput = _normalizeAggressive(text);

        for (final lang in languagesToCheck) {
          final result = _checkLanguageProfanity(normalizedInput, lang, _compiledPatterns[lang], context);
          if (result != null) return result;
        }

        return ProfanityResult.clean();
      },
      fallback: ProfanityResult.clean(),
    );
  }

  /// Check if text contains profanity with substring matching (for usernames/display names)
  Future<ProfanityResult> checkProfanitySubstring(String text, {String? language, String? context}) async {
    return await ErrorHandler.handle<ProfanityResult>(
      operation: () async {
        if (!_config.enabled || text.trim().isEmpty) {
          return ProfanityResult.clean();
        }

        // Early check: if the entire text (lowercased, alphanumeric only) is in the allowlist, it's clean
        final cleanText = text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (falsePositiveAllowlist.contains(cleanText)) {
          return ProfanityResult.clean();
        }

        // Remove ALL spaces for substring matching in display names
        final normalizedText = _normalizeAggressive(text).replaceAll(' ', '');
        final languagesToCheck = language != null ? [language] : _config.activeLanguages;

        for (final lang in languagesToCheck) {
          final result = _checkLanguageProfanity(normalizedText, lang, _substringPatterns[lang], context, originalText: text);
          if (result != null) return result;
        }

        return ProfanityResult.clean();
      },
      fallback: ProfanityResult.clean(),
    );
  }

  /// Quick synchronous check (for real-time validation)
  ProfanityResult checkProfanitySync(String text, {String? language, String? context}) {
    if (!_config.enabled || text.trim().isEmpty) {
      return ProfanityResult.clean();
    }

    // Early check: if the entire text (lowercased, alphanumeric only) is in the allowlist, it's clean
    final cleanText = text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (falsePositiveAllowlist.contains(cleanText)) {
      return ProfanityResult.clean();
    }

    final languagesToCheck = language != null ? [language] : _config.activeLanguages;

    // For display names/usernames, use substring matching to catch embedded profanity
    if (context == 'display_name') {
      // Remove ALL spaces for substring matching
      final normalizedText = _normalizeAggressive(text).replaceAll(' ', '');
      for (final lang in languagesToCheck) {
        final result = _checkLanguageProfanity(normalizedText, lang, _substringPatterns[lang], context, originalText: text);
        if (result != null) return result;
      }
      return ProfanityResult.clean();
    }

    // Standard token-based check for general text (keeps spaces for word boundaries)
    final normalizedInput = _normalizeAggressive(text);
    for (final lang in languagesToCheck) {
      final result = _checkLanguageProfanity(normalizedInput, lang, _compiledPatterns[lang], context, originalText: text);
      if (result != null) return result;
    }

    return ProfanityResult.clean();
  }

  /// Force refresh configuration from remote
  Future<void> refreshConfig() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _loadRemoteConfig();
      },
    );
  }

  /// Check pattern matches and return profanity result if found
  ProfanityResult? _checkPatternMatches(
    Iterable<Match> matches, 
    String lang, 
    String? context, {
    String? text,
    String? originalText,
  }) {
    if (matches.isEmpty) return null;

    // Convert matches to a list and sort by length (longest first) for priority
    final matchList = matches.toList();
    matchList.sort((a, b) => b.group(0)!.length.compareTo(a.group(0)!.length));

    // Check each match to find one that passes all filters
    for (final match in matchList) {
      final longestNormalized = match.group(0)!;
      final matchStart = match.start;
      final matchEnd = match.end;
      
      final normalizedMap = _normalizedToCanonical[lang];
      final canonical = normalizedMap != null ? normalizedMap[longestNormalized] : null;
      
      if (canonical != null) {
        if (falsePositiveAllowlist.contains(canonical.toLowerCase())) {
          continue; // Try the next match
        }
        
        // For substring matching (display_name context), check if the match is part of a safe word
        if (context == 'display_name' && originalText != null) {
          // Check if any allowlisted word contains this profanity as a substring
          final lowerOriginal = originalText.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
          bool isPartOfSafeWord = false;
          for (final safeWord in falsePositiveAllowlist) {
            if (lowerOriginal.contains(safeWord)) {
              isPartOfSafeWord = true;
              break;
            }
          }
          if (isPartOfSafeWord) continue; // Try the next match
        }
        
        if (context != 'display_name' && text != null) {
          final isWordBoundary = _isWordBoundary(text, matchStart, matchEnd);
          if (!isWordBoundary) {
            continue; // Try the next match
          }
        }
        
        // All checks passed, return the profanity result
        final severityMap = _wordSeverities[lang];
        final severity = severityMap != null ? severityMap[canonical] ?? 'medium' : 'medium';
        return ProfanityResult.found(
          word: canonical,
          language: lang,
          severity: severity,
          context: context,
        );
      }
    }
    return null;
  }

  /// Check consonant skeleton matching
  ProfanityResult? _checkConsonantSkeleton(String normalizedText, String lang, String? context) {
    final consonantInput = _toConsonantSkeleton(normalizedText);
    
    // Early check: if the original normalized text is in the allowlist, skip consonant checking
    if (falsePositiveAllowlist.contains(normalizedText.toLowerCase())) {
      return null;
    }
    
    final consonantPattern = _consonantPatterns[lang];
    if (consonantPattern != null) {
      final matches = consonantPattern.allMatches(consonantInput);
      
      // Check all matches and find the best one (highest ratio)
      ProfanityResult? bestResult;
      double bestRatio = 0.0;
      
      for (final match in matches) {
        final skeleton = match.group(0)!;
        final langMap = _consonantToCanonical[lang];
        if (langMap != null) {
          final canonical = langMap[skeleton];
          
          if (canonical != null) {
            final ratio = skeleton.length / canonical.length;
            final minLen = skeleton.length < canonical.length ? skeleton.length : canonical.length;
            final maxLen = skeleton.length > canonical.length ? skeleton.length : canonical.length;
            
            // Accept matches if:
            // 1. Skeleton.length >= 4 and ratio >= 0.75 (standard threshold for missing vowels)
            // 2. OR (lengths are very close AND min length >= 3) for doubled/tripled consonants
            // Use 0.8 for 3-char skeletons to avoid false positives like "cnt"→"cunt"
            bool shouldAccept = (skeleton.length >= 4 && ratio >= 0.75) || 
                                ((maxLen - minLen <= 1 && minLen >= 3) && skeleton.length >= 4);
            
            if (shouldAccept) {
              if (falsePositiveAllowlist.contains(canonical.toLowerCase())) {
                continue;
              }
              
              // Keep the result with the best ratio
              if (ratio > bestRatio) {
                bestRatio = ratio;
                final severityMap = _wordSeverities[lang];
                final originalSeverity = severityMap != null ? severityMap[canonical] ?? 'medium' : 'medium';
                final downgradedSeverity = _downgradeSeverity(originalSeverity);
                bestResult = ProfanityResult.found(
                  word: canonical,
                  language: lang,
                  severity: downgradedSeverity,
                  context: context,
                );
              }
            }
          }
        }
      }
      
      // Also check if any known skeleton appears as a substring
      // This catches cases like "ssht" containing "sht"
      if (bestResult == null) {
        // Early exit: check if normalized text is in allowlist
        if (falsePositiveAllowlist.contains(normalizedText.toLowerCase())) {
          return null;
        }
        final langMap = _consonantToCanonical[lang];
        if (langMap != null) {
          // Find all matching skeletons and pick the best one based on ratio
          final matchingSkeletons = <String, double>{};
          for (final knownSkeleton in langMap.keys) {
            if (knownSkeleton.length >= 3 && consonantInput.contains(knownSkeleton)) {
              // Calculate how well the known skeleton matches the canonical word
              final canonical = langMap[knownSkeleton]!;
              final ratio = knownSkeleton.length / canonical.length;
              
              // For substring matches, require high ratio by default
              // Exception: if input skeleton is similar length to known skeleton (like "ssht" vs "sht" with ~1 char diff),
              // it suggests doubled consonants which are obfuscation attempts, so allow 0.75
              // But if input is much longer (like "cln nd pprprt cntnt" vs "cnt"),
              // it's likely a false positive from a longer text, so require 0.8
              final lengthDiff = (consonantInput.length - knownSkeleton.length).abs();
              bool isCloseLengthMatch = lengthDiff <= 1;
              bool meetsThreshold = isCloseLengthMatch ? (ratio >= 0.75) : (ratio >= 0.8);
              
              if (meetsThreshold) {
                matchingSkeletons[knownSkeleton] = ratio;
              }
            }
          }
          
          if (matchingSkeletons.isNotEmpty) {
            // Sort by ratio (descending) to prefer skeletons that are closest to their canonical words
            final sortedMatches = matchingSkeletons.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            final bestSkeletonEntry = sortedMatches.first;
            final knownSkeleton = bestSkeletonEntry.key;
            
            final canonical = langMap[knownSkeleton];
            
            if (!falsePositiveAllowlist.contains(canonical!.toLowerCase())) {
              final severityMap = _wordSeverities[lang];
              final originalSeverity = severityMap != null ? severityMap[canonical] ?? 'medium' : 'medium';
              final downgradedSeverity = _downgradeSeverity(originalSeverity);
              bestResult = ProfanityResult.found(
                word: canonical,
                language: lang,
                severity: downgradedSeverity,
                context: context,
              );
            }
          }
        }
      }
      
      if (bestResult != null) {
        return bestResult;
      }
    }
    return null;
  }

  /// Check profanity for a specific language using pattern and consonant matching
  ProfanityResult? _checkLanguageProfanity(
    String normalizedText, 
    String lang, 
    RegExp? pattern, 
    String? context, {
    String? originalText,
  }) {
    if (pattern != null) {
      final matches = pattern.allMatches(normalizedText);
      final result = _checkPatternMatches(matches, lang, context, text: normalizedText, originalText: originalText);
      if (result != null) return result;
    }
    return _checkConsonantSkeleton(normalizedText, lang, context);
  }

  /// Check if a string is valid base64
  /// Add custom profanity words (for admin/moderation)
  void addCustomWords(String language, Set<String> words) {
    final existing = _profanityLists[language] ?? {};
    _profanityLists[language] = existing.union(words);
    _compilePatterns(language);
    _compileSubstringPatterns(language);
  }

  /// Remove custom words
  void removeCustomWords(String language, Set<String> words) {
    final existing = _profanityLists[language];
    if (existing != null) {
      _profanityLists[language] = existing.difference(words);
      _compilePatterns(language);
      _compileSubstringPatterns(language);
    }
  }
}