// Profanity filter configuration and result models.

/// Configuration for profanity filtering behavior.
class ProfanityConfig {
  final bool enabled;
  final List<String> activeLanguages;
  final bool checkLeetSpeak;
  final bool realTimeValidation;
  final int debounceMs;
  final Map<String, dynamic> severityLevels;
  final bool useRemoteLists;
  final String remoteListUrl;

  const ProfanityConfig({
    this.enabled = true,
    this.activeLanguages = const ['en'],
    this.checkLeetSpeak = true,
    this.realTimeValidation = false,
    this.debounceMs = 500,
    this.severityLevels = const {},
    this.useRemoteLists = false,
    this.remoteListUrl = '',
  });

  factory ProfanityConfig.fromJson(Map<String, dynamic> json) {
    return ProfanityConfig(
      enabled: json['enabled'] ?? true,
      activeLanguages: List<String>.from(json['activeLanguages'] ?? ['en']),
      checkLeetSpeak: json['checkLeetSpeak'] ?? true,
      realTimeValidation: json['realTimeValidation'] ?? false,
      debounceMs: json['debounceMs'] ?? 500,
      severityLevels: json['severityLevels'] ?? {},
      useRemoteLists: json['useRemoteLists'] ?? false,
      remoteListUrl: json['remoteListUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'activeLanguages': activeLanguages,
      'checkLeetSpeak': checkLeetSpeak,
      'realTimeValidation': realTimeValidation,
      'debounceMs': debounceMs,
      'severityLevels': severityLevels,
      'useRemoteLists': useRemoteLists,
      'remoteListUrl': remoteListUrl,
    };
  }

  ProfanityConfig copyWith({
    bool? enabled,
    List<String>? activeLanguages,
    bool? checkLeetSpeak,
    bool? realTimeValidation,
    int? debounceMs,
    Map<String, dynamic>? severityLevels,
    bool? useRemoteLists,
    String? remoteListUrl,
  }) {
    return ProfanityConfig(
      enabled: enabled ?? this.enabled,
      activeLanguages: activeLanguages ?? this.activeLanguages,
      checkLeetSpeak: checkLeetSpeak ?? this.checkLeetSpeak,
      realTimeValidation: realTimeValidation ?? this.realTimeValidation,
      debounceMs: debounceMs ?? this.debounceMs,
      severityLevels: severityLevels ?? this.severityLevels,
      useRemoteLists: useRemoteLists ?? this.useRemoteLists,
      remoteListUrl: remoteListUrl ?? this.remoteListUrl,
    );
  }
}

/// Result of profanity detection.
class ProfanityResult {
  final bool containsProfanity;
  final String? detectedWord;
  final String? language;
  final String? severity;
  final String? context;

  const ProfanityResult({
    required this.containsProfanity,
    this.detectedWord,
    this.language,
    this.severity,
    this.context,
  });

  factory ProfanityResult.clean() {
    return const ProfanityResult(containsProfanity: false);
  }

  factory ProfanityResult.found({
    String? word,
    String? language,
    String? severity,
    String? context,
  }) {
    return ProfanityResult(
      containsProfanity: true,
      detectedWord: word,
      language: language,
      severity: severity,
      context: context,
    );
  }

  @override
  String toString() {
    if (!containsProfanity) return 'ProfanityResult(clean)';
    return 'ProfanityResult(found: $detectedWord, lang: $language, severity: $severity)';
  }
}
