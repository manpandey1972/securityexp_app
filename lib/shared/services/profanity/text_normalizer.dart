// Text normalization utilities for profanity detection.
//
// Provides various text transformation methods to detect
// obfuscated profanity using leet-speak, homoglyphs, etc.

/// Remove punctuation and symbols between letters (e.g., f.u.c.k -> fuck)
String normalizePunctuation(String text) {
  return text.replaceAll(RegExp(r"[.\-_,;:!?()]"), '');
}

/// Remove zero-width and invisible Unicode characters
String removeZeroWidthAndInvisible(String text) {
  return text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u2060\u180E]'), '');
}

/// Normalize common Unicode homoglyphs to ASCII equivalents
String normalizeHomoglyphs(String text) {
  final homoglyphMap = <String, String>{
    // Cyrillic - visually equivalent to Latin
    '\u0430': 'a', // Cyrillic a
    '\u0435': 'e', // Cyrillic e
    '\u043E': 'o', // Cyrillic o
    '\u0440': 'p', // Cyrillic p
    '\u0441': 'c', // Cyrillic c
    '\u0445': 'x', // Cyrillic x
    '\u0456': 'i', // Ukrainian i
    '\u045B': 'b', // Serbian b
    // Greek - visually equivalent
    '\u03B1': 'a', // Greek alpha
    '\u03BF': 'o', // Greek omicron
    '\u03C1': 'p', // Greek rho
    '\u03C7': 'x', // Greek chi
    '\u03B5': 'e', // Greek epsilon
    '\u03B9': 'i', // Greek iota
  };
  
  String normalized = text;
  homoglyphMap.forEach((k, v) {
    normalized = normalized.replaceAll(RegExp(k), v);
  });
  return normalized;
}

/// Leet-speak character mapping
const Map<String, String> leetSpeakMap = {
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '8': 'b',
  '0': 'o',
  '@': 'a',
  '!': 'i',
  '\$': 's',
  '+': 't',
  '(': 'c',
  ')': 'c',
  '<': 'c',
  '|': 'i',
  '*': 'a',
  '^': 'a',
  '&': 'a',
  '?': 'q',
  '%': 'o',
  '#': 'h',
  '£': 'l',
  '€': 'e',
  '¢': 'c',
  '§': 's',
  '2': 'z',
  '6': 'g',
  '9': 'g',
  '¡': 'i',
  '™': 'tm',
  '÷': 'x',
  '×': 'x',
  'æ': 'ae',
  'œ': 'oe',
  'þ': 'p',
  'ð': 'd',
  'ß': 'ss',
  'ƒ': 'f',
  '®': 'r',
  '©': 'c',
  '°': 'o',
  '¿': 'q',
  '¼': '1/4',
  '½': '1/2',
  '¾': '3/4',
};

/// Normalize leet-speak in text
String normalizeLeetSpeak(String text, {bool enabled = true}) {
  if (!enabled) return text;

  String normalized = text.toLowerCase();
  leetSpeakMap.forEach((leet, normal) {
    final escapedLeet = RegExp.escape(leet);
    // Match the leet character, but not if it's part of a sequence of 2+ identical characters
    normalized = normalized.replaceAllMapped(
      RegExp('(?<!$escapedLeet)$escapedLeet(?!$escapedLeet)', caseSensitive: false),
      (match) => normal,
    );
  });
  return normalized;
}

/// Normalize repeated characters in text (e.g., fuuuuck -> fuck)
String normalizeRepeatedChars(String text) {
  return text.replaceAllMapped(
    RegExp(r'([a-zA-Z])\1{2,}', caseSensitive: false),
    (match) => match.group(1)!,
  );
}

/// Convert word to consonant skeleton (remove vowels)
String toConsonantSkeleton(String word) {
  return word.replaceAll(RegExp(r'[aeiou]'), '');
}

/// Check if a position in text is at a word boundary
bool isWordBoundary(String text, int start, int end) {
  final before = start == 0 || !RegExp(r'[a-zA-Z]').hasMatch(text[start - 1]);
  final after = end >= text.length || !RegExp(r'[a-zA-Z]').hasMatch(text[end]);
  return before && after;
}

/// Apply the full normalization pipeline to text
/// Aggressive normalization for substring matching (removes all non-letters)
String normalizeAggressive(String text, {
  bool skipRepeatedChars = false,
  bool checkLeetSpeak = true,
}) {
  String normalized = text;
  if (!skipRepeatedChars) {
    normalized = normalizeRepeatedChars(normalized);
  }
  normalized = normalizeHomoglyphs(normalized);
  normalized = normalizeLeetSpeak(normalized, enabled: checkLeetSpeak);
  normalized = removeZeroWidthAndInvisible(normalized);
  normalized = normalizePunctuation(normalized);
  // Replace non-letters with spaces (preserves word boundaries)
  normalized = normalized.replaceAll(RegExp(r'[^a-zA-Z]'), ' ');
  // Clean up multiple spaces
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.toLowerCase();
}

/// Check if a string is valid base64
bool isValidBase64(String str) {
  final base64Regex = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
  return base64Regex.hasMatch(str) && str.length % 4 == 0;
}

/// Downgrade severity for skeleton matches
String downgradeSeverity(String severity) {
  switch (severity) {
    case 'high':
      return 'medium';
    case 'medium':
      return 'low';
    case 'low':
      return 'low';
    default:
      return 'low';
  }
}
