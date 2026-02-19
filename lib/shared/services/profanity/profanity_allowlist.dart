// Allowlist of common words that shouldn't be flagged as profanity.
//
// These are legitimate words that may contain substrings matching
// profanity patterns but are not themselves profane.

const Set<String> falsePositiveAllowlist = {
  // Words containing "ass"
  'hello', 'shell', 'class', 'assets', 'bass', 'grass', 'pass', 'mass',
  'classic', 'passive', 'compass', 'harass', 'morass', 'trespass',
  'assess', 'assessment', 'ассess', 'classroom', 'glassware', 'assassin',
  'ассist', 'assistance', 'massager', 'massage', 'embassy', 'rassle',
  'cassette', 'chassis', 'reassure', 'reassess', 'hassle', 'tassel',
  'vassal', 'lassie', 'lasso', 'surpass', 'amass', 'crass', 'brass',
  'associate', 'associated', 'association',
  
  // Words containing "anal"
  'analyze', 'analysis', 'analyst', 'analytic', 'analytics', 'analytical',
  'canal', 'banal', 'final', 'finale', 'finalize', 'penalize', 'penal',
  
  // Words containing "hell"
  'hell', 'hallo', 'hellish',
  
  // Words containing "mong"
  'mong', 'among', 'mongrel', 'mongoose', 'programmer', 'programming', 'samsung',
  
  // Words containing "tit"
  'title', 'subtitle', 'stitches', 'stitching', 'petition', 'repetition',
  'constitution', 'institute', 'constituted', 'entity', 'identity',
  'quantity', 'superstition', 'practitioner', 'competitive', 'stitute',
  
  // Words containing "cum"
  'document', 'cucumber', 'circumstance', 'accumulate', 'circumvent',
  'succumb', 'incumbent', 'documenting', 'documentary', 'circumference',
  
  // Words containing "cnt"
  'content', 'account', 'discount', 'count', 'country', 'encounter', 'concentration',
};

/// Check if a word is in the false positive allowlist
bool isAllowlisted(String word) {
  return falsePositiveAllowlist.contains(word.toLowerCase());
}

/// Check if text contains any allowlisted word
bool containsAllowlistedWord(String text) {
  final lowerText = text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  for (final safeWord in falsePositiveAllowlist) {
    if (lowerText.contains(safeWord)) {
      return true;
    }
  }
  return false;
}
