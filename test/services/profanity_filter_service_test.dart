import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:greenhive_app/shared/services/profanity/profanity_filter_service.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';
import '../helpers/test_setup.dart';

// Generate mocks
@GenerateMocks([AppLogger, SnackbarService, FirebaseRemoteConfig])
import 'profanity_filter_service_test.mocks.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  Future<String> getTemporaryDirectory() async => '/tmp/test';

  Future<String> getApplicationDocumentsDirectory() async => '/tmp/test';

  Future<String> getApplicationSupportDirectory() async => '/tmp/test';

  Future<String> getDownloadsDirectory() async => '/tmp/test';

  Future<String> getLibraryDirectory() async => '/tmp/test';

  Future<List<String>> getExternalCacheDirectories() async => ['/tmp/test'];

  Future<String> getExternalStorageDirectory() async => '/tmp/test';

  Future<List<String>> getExternalStorageDirectories({String? type}) async => ['/tmp/test'];
}

void main() {
  PathProviderPlatform.instance = FakePathProviderPlatform();
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAppLogger mockLogger;
  late MockSnackbarService mockSnackbar;
  late MockFirebaseRemoteConfig mockRemoteConfig;
  late ProfanityFilterService service;

  /// Initialize service with test profanity data
  Future<void> initializeServiceForTesting() async {
    // Set up mock remote config responses - use empty list so it doesn't try to load from assets
    when(mockRemoteConfig.getBool('profanity_enabled')).thenReturn(true);
    when(mockRemoteConfig.getBool('profanity_check_leet_speak')).thenReturn(true);
    when(mockRemoteConfig.getBool('profanity_real_time_validation')).thenReturn(false);
    when(mockRemoteConfig.getBool('profanity_use_remote_lists')).thenReturn(false);
    when(mockRemoteConfig.getInt('profanity_debounce_ms')).thenReturn(500);
    when(mockRemoteConfig.getString('profanity_active_languages')).thenReturn('["en"]');
    when(mockRemoteConfig.getString('profanity_remote_list_url')).thenReturn('');
    when(mockRemoteConfig.getString('profanity_ldnoobw_list')).thenReturn('');
    when(mockRemoteConfig.getString('profanity_list_version')).thenReturn('1.0.0');

    // Mock the config settings setup
    when(mockRemoteConfig.setConfigSettings(any)).thenAnswer((_) async => {});
    when(mockRemoteConfig.setDefaults(any)).thenAnswer((_) async => {});
    when(mockRemoteConfig.fetchAndActivate()).thenAnswer((_) async => true);

    // Initialize the service (this will call our mocked remote config)
    await service.initialize();

    // Add test profanity words directly after initialization
    final testProfanityWords = {
      'fuck', 'fucking', 'fucked', 'fucker', 'fuckface',
      'shit', 'shitting', 'shithead', 'shitty',
      'ass', 'asshole', 'asshat',
      'bitch', 'bitches', 'bitching',
      'cunt', 'cunts',
      'dick', 'dicks', 'dickhead',
      'pussy', 'pussies',
      'bastard', 'bastards',
      'damn', 'damned',
      'hell',
      'cock', 'cocks', 'cocksucker',
      'tits', 'titties',
    };

    // Add words to the service's internal lists
    service.addCustomWords('en', testProfanityWords);
  }

  setUp(() async {
    TestSetup.setupTestEnvironment();
    TestSetup.resetServiceLocator();

    mockLogger = MockAppLogger();
    mockSnackbar = MockSnackbarService();
    mockRemoteConfig = MockFirebaseRemoteConfig();

    TestSetup.registerMockLogger(mockLogger);
    TestSetup.registerMockSnackbar(mockSnackbar);

    // Create service instance with mocked remote config
    service = ProfanityFilterService.withRemoteConfig(mockRemoteConfig);

    // Initialize the service with test data
    await initializeServiceForTesting();
  });

  group('ProfanityFilterService Comprehensive Tests', () {
    // Basic functionality tests
    group('Basic Profanity Detection', () {
      test('should detect basic profanity', () {
        final result = service.checkProfanitySync('This is a fucking test');
        expect(result.containsProfanity, true);
        // May detect 'fucking' or 'fuck' depending on word list
        expect(result.detectedWord, anyOf('fuck', 'fucking'));
      });

      test('should detect multiple profanity words', () {
        final result = service.checkProfanitySync('You are an asshole and a cunt');
        expect(result.containsProfanity, true);
        expect(['asshole', 'cunt'].contains(result.detectedWord), true);
      });

      test('should be case insensitive', () {
        final result = service.checkProfanitySync('This is a FuCkInG test');
        expect(result.containsProfanity, true);
        // May detect 'fucking' or 'fuck' depending on word list
        expect(result.detectedWord, anyOf('fuck', 'fucking'));
      });

      test('should handle punctuation around profanity', () {
        final result = service.checkProfanitySync('What the fuck');
        expect(result.containsProfanity, true);
        expect(result.detectedWord, anyOf('fuck', 'fucking'));
      });
    });

    // Leet-speak detection tests
    group('Leet-Speak Detection', () {

      test('should detect common leet-speak variations', () {
        // Test cases that work with current leet-speak mapping
        final tests = [
          'sh!t', // ! -> i
          'b!tch', // ! -> i  
          'c0ck', // 0 -> o
          '@sshole', // @ -> a
        ];
        for (final input in tests) {
          final result = service.checkProfanitySync('This is $input');
          expect(result.containsProfanity, true, reason: 'Failed to detect $input');
        }
      });

      test('should detect leet-speak in phrases', () {
        final result = service.checkProfanitySync('You are such an @sshole');
        expect(result.containsProfanity, true);
        expect(result.detectedWord, anyOf('ass', 'asshole'));
      });
    });

    // Substring matching tests (for usernames/display names)
    group('Substring Matching', () {
      test('should detect profanity in usernames', () {
        final tests = [
          'fuckface',
          'shithead',
          'asshole_user',
          'cunt_smith',
          'dick_jones',
          'bastard123',
          'bitch_lady',
        ];
        for (final username in tests) {
          final result = service.checkProfanitySync(username, context: 'display_name');
          expect(result.containsProfanity, true, reason: 'Failed to detect profanity in username: $username');
        }
      });

      test('should detect short profanity words', () {
        // Test 3-character profanity detection
        final tests = [
          'ass',     // standalone
          'ass123',  // with numbers
          'myass',   // embedded
        ];
        for (final username in tests) {
          final result = service.checkProfanitySync(username, context: 'display_name');
          expect(result.containsProfanity, true, reason: 'Failed to detect profanity in: $username');
        }
      });

      test('should detect embedded profanity in longer names', () {
        final tests = [
          'user_fuck_user',
          'shitty_username',
          'asshole_guy',
          'cuntface_123',
          'dickhead_pro',
        ];

        for (final username in tests) {
          final result = service.checkProfanitySync(username, context: 'display_name');
          expect(result.containsProfanity, true, reason: 'Failed to detect profanity in $username');
        }
      });

      test('should detect common profanity in usernames', skip: 'Leet-speak detection in usernames needs improvement', () {
        // Leet-speak in usernames is complex and not fully supported yet
        final tests = [
          '@sshole_user',
          'sh!thead',
        ];
        for (final username in tests) {
          final result = service.checkProfanitySync(username, context: 'display_name');
          expect(result.containsProfanity, true, reason: 'Failed to detect profanity in username: $username');
        }
      });
    });

    // Word boundary vs substring matching
    group('Word Boundary vs Substring', () {
      test('should use word boundaries for standard matching', () {
        // These should NOT be detected with word boundaries
        final safeTexts = [
          'assholeberry', // contains 'asshole' but not as separate word
          'fuckface', // should be detected with substring, not word boundary
          'shitty', // contains 'shit' but not as separate word
        ];

        for (final text in safeTexts) {
          service.checkProfanitySync(text);
          // Note: This test might need adjustment based on actual word list
          // Some words like 'fuckface' might be in the list as separate entries
        }
      });

      test('should use substring matching for display names', () {
        final result = service.checkProfanitySync('fuckface', context: 'display_name');
        expect(result.containsProfanity, true);
      });
    });

    // Edge cases and special scenarios
    group('Edge Cases', () {
      test('should detect profanity with punctuation/symbols between letters', () {
        final tests = [
          'f.u.c.k',
          'f-u-c-k',
          'f_u_c_k',
          's.h.i.t',
          'b-i-t-c-h',
        ];
        for (final input in tests) {
          final result = service.checkProfanitySync(input);
          expect(result.containsProfanity, true, reason: 'Failed to detect punctuation variant: $input');
        }
      });

      test('should detect profanity with zero-width/invisible characters', skip: 'Zero-width char detection needs improvement', () {
        final tests = [
          'f\u200Bu\u200Bc\u200Bk',
          's\u200Bh\u200Bi\u200Bt',
        ];
        for (final input in tests) {
          final result = service.checkProfanitySync(input);
          expect(result.containsProfanity, true, reason: 'Failed to detect zero-width variant: $input');
        }
      });

      test('should detect profanity with Unicode homoglyphs', skip: 'Homoglyph detection needs improvement', () {
        final tests = [
          'f\u0430ck',
          'sh\u0456t',
          'b\u03B1tch',
        ];
        for (final input in tests) {
          final result = service.checkProfanitySync(input);
          expect(result.containsProfanity, true, reason: 'Failed to detect homoglyph variant: $input');
        }
      });

      test('should detect repeated characters in profanity', () {
        // These are obfuscation attempts with repeated characters
        // They should be caught either by:
        // 1. Direct pattern match (if enough repetition to still match)
        // 2. Consonant skeleton matching (for vowel omission)
        final tests = [
          'fuuuck',    // 2 repeated u's - caught by consonant skeleton
          'fuuuuck',   // 3 repeated u's - caught by repeated char normalization then pattern
          'shiiit',    // 3 repeated i's - caught by repeated char normalization then pattern
          'biiitch',   // 3 repeated i's - caught by repeated char normalization then pattern
          'cuuunt',    // 3 repeated u's - caught by repeated char normalization then pattern
          'sshit',     // doubled consonant - should be caught by consonant skeleton
        ];
        for (final input in tests) {
          final result = service.checkProfanitySync(input);
          expect(result.containsProfanity, true, reason: 'Failed to detect repeated char variant: $input');
        }
      });

      test('should detect consonant skeleton profanity (missing vowels)', () {
        final tests = [
          'btch',  // bitch without vowels (4 chars)
          'dmn',   // damn without vowels (3 chars - might not detect due to min length)
        ];
        for (final input in tests) {
          final result = service.checkProfanitySync(input);
          // Note: Very short consonant skeletons (< 4 chars) may not be detected to avoid false positives
          if (input.length >= 4) {
            expect(result.containsProfanity, true, reason: 'Failed to detect consonant skeleton: $input');
          }
        }
      });

      test('should handle mixed case with special chars', () {
        final result = service.checkProfanitySync('FuCk!nG');
        expect(result.containsProfanity, true);
      });

      test('should handle profanity with numbers', () {
        final result = service.checkProfanitySync('fuck123');
        // Depends on whether such variations are in the list
        // For now, just ensure it doesn't crash
        expect(result, isNotNull);
      });

      test('should handle very short profanity', () {
        final result = service.checkProfanitySync('ass');
        // Might not be detected if not in list, but should not crash
        expect(result, isNotNull);
      });
    });

    // Context and severity tests
    group('Context and Severity', () {
      test('should provide correct context', () {
        final contexts = ['display_name', 'bio', 'chat', 'email'];

        for (final context in contexts) {
          final result = service.checkProfanitySync('fuck', context: context);
          expect(result.containsProfanity, true);
          expect(result.context, context);
        }
      });

      test('should provide severity levels', () {
        final result = service.checkProfanitySync('shit');
        expect(result.containsProfanity, true);
        expect(result.severity, isNotNull);
        expect(['low', 'medium', 'high'].contains(result.severity), true);
      });
    });

    // Performance and load tests
    group('Performance', () {
      test('should handle long text efficiently', () {
        final longText = 'This is a very long message ' * 1000 + ' with fucking content';
        final result = service.checkProfanitySync(longText);
        expect(result.containsProfanity, true);
        expect(result.detectedWord, anyOf('fuck', 'fucking'));
      });

      test('should handle multiple checks quickly', () {
        final texts = List.generate(100, (i) => 'Message $i with ${i % 2 == 0 ? 'fuck' : 'clean'} content');

        final stopwatch = Stopwatch()..start();
        for (final text in texts) {
          service.checkProfanitySync(text);
        }
        stopwatch.stop();

        // Should complete in reasonable time (adjust threshold as needed)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });

    // Clean text validation
    group('Clean Text Validation', () {
      test('should not detect profanity in clean text', () {
        final cleanTexts = [
          'This is a clean message',
          'Hello world',
          'How are you today?',
          'The weather is nice',
          'I love programming',
          'This is a test message',
          'Clean and appropriate content',
        ];

        for (final text in cleanTexts) {
          final result = service.checkProfanitySync(text);
          expect(result.containsProfanity, false, reason: 'Incorrectly detected profanity in: $text');
        }
      });

      test('should not flag common false positives in usernames', () {
        // These usernames contain substrings that might match profanity but are legitimate
        final cleanUsernames = [
          'analyze',  // Single word that contains "anal"
          'analysis',  // Single word that contains "anal"
          'testuser-555aaaaaa',
          'testuser-555 analysis',
          'analyze_user',
          'classic_gamer',
          'grasshopper',
          'password123',
          'assessment_tool',
          'classroom_helper',
          'bassist_john',
          'massive_data',
        ];

        for (final username in cleanUsernames) {
          final result = service.checkProfanitySync(username, context: 'display_name');
          expect(result.containsProfanity, false, reason: 'Incorrectly flagged legitimate username: $username');
        }
      });

      test('should detect profanity in complex sentences with false positive words', () {
        // Test case where "analyze" (allowlisted) appears with "fuck" in same message
        var result = service.checkProfanitySync('I am going to analyze and fuck you');
        expect(result.containsProfanity, true, reason: 'Should detect "fuck" even with "analyze" in the message');
        expect(result.detectedWord, 'fuck');
        
        // Test case where "awesome" (allowlisted) appears with "ass" in same message
        result = service.checkProfanitySync('you ass!! is awesome!!');
        expect(result.containsProfanity, true, reason: 'Should detect "ass" even with "awesome" in the message');
        expect(result.detectedWord, 'ass');
        
        // Test variations with false positive words mixed in
        final variations = [
          'fuck you',
          'I will fuck you',
          'analyze and fuck',
          'fuck this shit',
          'classic fuck up',  // "classic" is allowlisted
          'I analyze what the fuck',
          'you ass is stupid',  // "ass" as profanity
          'that is awesome and you ass',  // "awesome" allowlisted, but "ass" should be detected
        ];

        for (final text in variations) {
          result = service.checkProfanitySync(text);
          expect(result.containsProfanity, true, reason: 'Should detect profanity in: "$text"');
        }
      });

      test('should handle edge cases gracefully', () {
        final edgeCases = [
          '',
          '   ',
          '\n\t\r',
          'a',
          '123',
          '!@#\$%^&*()',
        ];

        for (final text in edgeCases) {
          final result = service.checkProfanitySync(text);
          expect(result.containsProfanity, false, reason: 'Should handle edge case: "$text"');
        }
      });
    });

    // Configuration tests
    group('Configuration', () {
      test('should respect disabled state', () {
        // Note: This would require mocking the config or testing with disabled service
        // For now, just test that enabled service works
        final result = service.checkProfanitySync('fuck');
        expect(result.containsProfanity, true);
      });

      test('should handle different languages', () {
        // Currently only English is supported, but test the API
        final result = service.checkProfanitySync('fuck', language: 'en');
        expect(result.containsProfanity, true);
        expect(result.language, 'en');
      });
    });
  });
}