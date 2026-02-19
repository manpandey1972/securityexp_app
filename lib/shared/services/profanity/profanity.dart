// Profanity filter barrel export file.
//
// Import this file to access all profanity filter components.
// 
// The service contains these extracted modules:
// - profanity_models.dart: ProfanityConfig, ProfanityResult classes
// - text_normalizer.dart: Text normalization utilities for profanity detection
// - profanity_allowlist.dart: False positive allowlist words

// Export models (canonical source)
export 'profanity_models.dart';

// Export text normalization utilities
export 'text_normalizer.dart';

// Export allowlist
export 'profanity_allowlist.dart';

// Export the main service
export 'profanity_filter_service.dart';
