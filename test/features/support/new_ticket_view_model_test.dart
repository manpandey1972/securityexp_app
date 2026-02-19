import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';
import 'package:securityexperts_app/features/support/presentation/view_models/new_ticket_view_model.dart';
import 'package:securityexperts_app/features/support/services/support_service.dart';
import 'package:securityexperts_app/features/support/services/support_analytics.dart';

import 'new_ticket_view_model_test.mocks.dart';

@GenerateMocks([SupportService, AppLogger, SupportAnalytics])
void main() {
  late NewTicketViewModel viewModel;
  late MockSupportService mockSupportService;
  late MockAppLogger mockAppLogger;
  late MockSupportAnalytics mockSupportAnalytics;

  setUp(() {
    mockSupportService = MockSupportService();
    mockAppLogger = MockAppLogger();
    mockSupportAnalytics = MockSupportAnalytics();

    // Register dependencies in service locator
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);

    if (sl.isRegistered<SupportAnalytics>()) {
      sl.unregister<SupportAnalytics>();
    }
    sl.registerSingleton<SupportAnalytics>(mockSupportAnalytics);

    viewModel = NewTicketViewModel(supportService: mockSupportService);
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    if (sl.isRegistered<SupportAnalytics>()) {
      sl.unregister<SupportAnalytics>();
    }
  });

  group('NewTicketViewModel - Initial State', () {
    test('should have initial state with null type', () {
      expect(viewModel.state.type, isNull);
      expect(viewModel.state.category, isNull);
      expect(viewModel.state.subject, equals(''));
      expect(viewModel.state.description, equals(''));
      expect(viewModel.state.attachments, isEmpty);
      expect(viewModel.state.isSubmitting, isFalse);
      expect(viewModel.state.error, isNull);
    });

    test('isValid should be false initially', () {
      expect(viewModel.state.isValid, isFalse);
    });
  });

  group('NewTicketViewModel - setType', () {
    test('should update ticket type', () {
      viewModel.setType(TicketType.bug);
      expect(viewModel.state.type, equals(TicketType.bug));
    });

    test('should auto-set category to performance for bug type', () {
      viewModel.setType(TicketType.bug);
      expect(viewModel.state.category, equals(TicketCategory.performance));
    });

    test('should auto-set category to other for payment type', () {
      viewModel.setType(TicketType.payment);
      expect(viewModel.state.category, equals(TicketCategory.other));
    });

    test('should auto-set category to profile for account type', () {
      viewModel.setType(TicketType.account);
      expect(viewModel.state.category, equals(TicketCategory.profile));
    });
  });

  group('NewTicketViewModel - setCategory', () {
    test('should update category', () {
      viewModel.setCategory(TicketCategory.chat);
      expect(viewModel.state.category, equals(TicketCategory.chat));
    });
  });

  group('NewTicketViewModel - setSubject', () {
    test('should update subject', () {
      viewModel.setSubject('My Issue');
      expect(viewModel.state.subject, equals('My Issue'));
    });
  });

  group('NewTicketViewModel - setDescription', () {
    test('should update description', () {
      viewModel.setDescription('Detailed description of the issue');
      expect(viewModel.state.description, equals('Detailed description of the issue'));
    });
  });

  group('NewTicketViewModel - validate', () {
    test('should fail validation when type is null', () {
      viewModel.setSubject('Subject');
      viewModel.setDescription('Description');
      viewModel.setCategory(TicketCategory.chat);

      final result = viewModel.validate();

      expect(result, isFalse);
      expect(viewModel.state.error, contains('type'));
    });

    test('should fail validation when category is null', () {
      viewModel.setType(TicketType.support);
      viewModel.setSubject('Subject');
      viewModel.setDescription('Description');

      // Clear the auto-set category
      viewModel.setCategory(null);

      final result = viewModel.validate();

      expect(result, isFalse);
      expect(viewModel.state.error, contains('category'));
    });

    test('should fail validation when subject is empty', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setDescription('Description');

      final result = viewModel.validate();

      expect(result, isFalse);
      expect(viewModel.state.error, contains('subject'));
    });

    test('should fail validation when description is empty', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setSubject('Subject');

      final result = viewModel.validate();

      expect(result, isFalse);
      expect(viewModel.state.error, contains('describe'));
    });

    test('should pass validation with all required fields', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setSubject('Subject');
      viewModel.setDescription('Description');

      final result = viewModel.validate();

      expect(result, isTrue);
      expect(viewModel.state.error, isNull);
    });

    test('should fail validation for PII in subject (phone number)', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setSubject('Call me at 555-123-4567');
      viewModel.setDescription('Description');

      final result = viewModel.validate();

      expect(result, isFalse);
    });

    test('should fail validation for PII in description (email)', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setSubject('Subject');
      viewModel.setDescription('Email me at test@example.com');

      final result = viewModel.validate();

      expect(result, isFalse);
    });

    test('should fail validation when subject is too long', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setSubject('A' * 101); // > 100 characters
      viewModel.setDescription('Description');

      final result = viewModel.validate();

      expect(result, isFalse);
      expect(viewModel.state.error, contains('too long'));
    });
  });

  group('NewTicketViewModel - removeAttachment', () {
    test('should not throw when removing from empty list', () {
      expect(() => viewModel.removeAttachment(0), returnsNormally);
    });

    test('should not throw for negative index', () {
      expect(() => viewModel.removeAttachment(-1), returnsNormally);
    });
  });

  group('NewTicketViewModel - reset', () {
    test('should reset to initial state', () {
      viewModel.setType(TicketType.bug);
      viewModel.setSubject('Subject');
      viewModel.setDescription('Description');

      viewModel.reset();

      expect(viewModel.state.type, isNull);
      expect(viewModel.state.subject, equals(''));
      expect(viewModel.state.description, equals(''));
    });
  });

  group('NewTicketViewModel - clearError', () {
    test('should clear error message', () {
      // Trigger validation to create an error
      viewModel.validate();
      expect(viewModel.state.error, isNotNull);

      viewModel.clearError();
      expect(viewModel.state.error, isNull);
    });
  });

  group('NewTicketState - isValid', () {
    test('should return true when all fields are valid', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setSubject('Valid subject');
      viewModel.setDescription('Valid description');

      expect(viewModel.state.isValid, isTrue);
    });

    test('should return false when type is missing', () {
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setSubject('Valid subject');
      viewModel.setDescription('Valid description');

      expect(viewModel.state.isValid, isFalse);
    });

    test('should return false when category is missing', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(null);
      viewModel.setSubject('Valid subject');
      viewModel.setDescription('Valid description');

      expect(viewModel.state.isValid, isFalse);
    });

    test('should return false when subject is empty', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setDescription('Valid description');

      expect(viewModel.state.isValid, isFalse);
    });

    test('should return false when description is empty', () {
      viewModel.setType(TicketType.support);
      viewModel.setCategory(TicketCategory.chat);
      viewModel.setSubject('Valid subject');

      expect(viewModel.state.isValid, isFalse);
    });
  });
}
