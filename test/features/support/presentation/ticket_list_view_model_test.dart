// TicketListViewModel tests
//
// Tests for the ticket list view model which manages support ticket list.

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:securityexperts_app/features/support/presentation/view_models/ticket_list_view_model.dart';
import 'package:securityexperts_app/features/support/presentation/state/ticket_list_state.dart';
import 'package:securityexperts_app/features/support/services/support_analytics.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

import '../../../helpers/service_mocks.mocks.dart';

@GenerateMocks([SupportAnalytics])
import 'ticket_list_view_model_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupportService mockSupportService;
  late MockSupportAnalytics mockAnalytics;
  late MockAppLogger mockAppLogger;
  late TicketListViewModel viewModel;

  final now = DateTime.now();
  final testDeviceContext = const DeviceContext(
    platform: 'iOS',
    osVersion: '17.0',
    appVersion: '1.0.0',
    buildNumber: '1',
    locale: 'en_US',
    timezone: 'America/New_York',
  );
  final testTickets = <SupportTicket>[
    SupportTicket(
      id: 'ticket-1',
      ticketNumber: 'TKT-001',
      userId: 'user-1',
      userEmail: 'user@test.com',
      type: TicketType.bug,
      category: TicketCategory.calling,
      priority: TicketPriority.high,
      status: TicketStatus.open,
      subject: 'Test Bug',
      description: 'Description',
      deviceContext: testDeviceContext,
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
    ),
    SupportTicket(
      id: 'ticket-2',
      ticketNumber: 'TKT-002',
      userId: 'user-1',
      userEmail: 'user@test.com',
      type: TicketType.feedback,
      category: TicketCategory.chat,
      priority: TicketPriority.low,
      status: TicketStatus.resolved,
      subject: 'Test Feedback',
      description: 'Description',
      deviceContext: testDeviceContext,
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
    ),
  ];

  setUp(() {
    mockSupportService = MockSupportService();
    mockAnalytics = MockSupportAnalytics();
    mockAppLogger = MockAppLogger();

    // Register mocks
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);

    if (sl.isRegistered<SupportAnalytics>()) {
      sl.unregister<SupportAnalytics>();
    }
    sl.registerSingleton<SupportAnalytics>(mockAnalytics);

    viewModel = TicketListViewModel(supportService: mockSupportService);
  });

  tearDown(() {
    viewModel.dispose();
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    if (sl.isRegistered<SupportAnalytics>()) {
      sl.unregister<SupportAnalytics>();
    }
  });

  group('TicketListViewModel', () {
    group('initial state', () {
      test('should start with initial state from factory', () {
        final state = viewModel.state;

        expect(state.tickets, isEmpty);
        expect(state.allTickets, isEmpty);
        expect(state.statusFilter, isNull);
        expect(state.error, isNull);
      });
    });

    group('initialize', () {
      test('should subscribe to ticket streams', () {
        when(mockSupportService.watchUserTickets(statusFilter: null))
            .thenAnswer((_) => Stream.value(testTickets));
        when(mockSupportService.watchUserTickets(statusFilter: anyNamed('statusFilter')))
            .thenAnswer((_) => Stream.value(testTickets));
        when(mockSupportService.getUnreadTicketCount())
            .thenAnswer((_) async => 5);

        viewModel.initialize();

        // Initialize subscribes to both all tickets and filtered tickets stream
        verify(mockSupportService.watchUserTickets(statusFilter: null)).called(greaterThanOrEqualTo(1));
      });
    });

    group('setStatusFilter', () {
      test('should update status filter', () {
        when(mockSupportService.watchUserTickets(statusFilter: TicketStatus.open))
            .thenAnswer((_) => Stream.value([testTickets.first]));
        when(mockAnalytics.trackTicketFiltered(statusFilter: TicketStatus.open))
            .thenAnswer((_) async {});

        viewModel.setStatusFilter(TicketStatus.open);

        expect(viewModel.state.statusFilter, TicketStatus.open);
        expect(viewModel.state.isLoading, true);
        verify(mockAnalytics.trackTicketFiltered(statusFilter: TicketStatus.open)).called(1);
      });

      test('should not update if same filter', () {
        when(mockSupportService.watchUserTickets(statusFilter: TicketStatus.open))
            .thenAnswer((_) => Stream.value([testTickets.first]));
        when(mockAnalytics.trackTicketFiltered(statusFilter: TicketStatus.open))
            .thenAnswer((_) async {});

        viewModel.setStatusFilter(TicketStatus.open);
        viewModel.setStatusFilter(TicketStatus.open); // Same filter

        // Analytics should only be called once
        verify(mockAnalytics.trackTicketFiltered(statusFilter: TicketStatus.open)).called(1);
      });
    });

    group('clearStatusFilter', () {
      test('should clear status filter to null', () {
        when(mockSupportService.watchUserTickets(statusFilter: anyNamed('statusFilter')))
            .thenAnswer((_) => Stream.value(testTickets));
        when(mockAnalytics.trackTicketFiltered(statusFilter: anyNamed('statusFilter')))
            .thenAnswer((_) async {});

        viewModel.setStatusFilter(TicketStatus.open);
        viewModel.clearStatusFilter();

        expect(viewModel.state.statusFilter, isNull);
      });
    });

    group('getFilteredTickets', () {
      test('should return all tickets when no type filter', () async {
        when(mockSupportService.watchUserTickets(statusFilter: null))
            .thenAnswer((_) => Stream.value(testTickets));
        when(mockSupportService.getUnreadTicketCount())
            .thenAnswer((_) async => 0);

        viewModel.initialize();
        await Future.delayed(Duration.zero); // Allow stream to emit

        final filtered = viewModel.getFilteredTickets();
        expect(filtered, testTickets);
      });

      test('should filter by type when provided', () async {
        when(mockSupportService.watchUserTickets(statusFilter: null))
            .thenAnswer((_) => Stream.value(testTickets));
        when(mockSupportService.getUnreadTicketCount())
            .thenAnswer((_) async => 0);

        viewModel.initialize();
        await Future.delayed(Duration.zero);

        final filtered = viewModel.getFilteredTickets(typeFilter: TicketType.bug);
        expect(filtered.length, 1);
        expect(filtered.first.type, TicketType.bug);
      });
    });

    group('dispose', () {
      test('should have dispose method', () {
        // dispose is called in tearDown, just verify the method exists
        expect(viewModel.dispose, isNotNull);
      });
    });
  });

  group('TicketListState', () {
    test('initial factory should return loading state', () {
      final state = TicketListState.initial();

      expect(state.isLoading, true);
      expect(state.tickets, isEmpty);
      expect(state.allTickets, isEmpty);
      expect(state.statusFilter, isNull);
      expect(state.error, isNull);
      expect(state.unreadCount, 0);
    });

    test('copyWith should preserve unchanged values', () {
      final original = TicketListState.initial();
      final updated = original.copyWith(
        tickets: testTickets,
        isLoading: false,
      );

      expect(updated.tickets, testTickets);
      expect(updated.isLoading, false);
      expect(updated.statusFilter, isNull);
    });

    test('copyWith clearError should clear error', () {
      final state = TicketListState.initial().copyWith(error: 'Error');
      final updated = state.copyWith(clearError: true);

      expect(updated.error, isNull);
    });

    test('copyWith clearStatusFilter should clear status filter', () {
      final state = TicketListState.initial().copyWith(
        statusFilter: TicketStatus.open,
      );
      final updated = state.copyWith(clearStatusFilter: true);

      expect(updated.statusFilter, isNull);
    });

    test('openCount should return open tickets count', () {
      final state = TicketListState.initial().copyWith(allTickets: testTickets);
      expect(state.openCount, 1);
    });

    test('resolvedCount should return resolved tickets count', () {
      final state = TicketListState.initial().copyWith(allTickets: testTickets);
      expect(state.resolvedCount, 1);
    });

    test('inProgressCount should return in-progress tickets count', () {
      final state = TicketListState.initial().copyWith(allTickets: testTickets);
      expect(state.inProgressCount, 0);
    });

    test('hasTickets should return true when tickets exist', () {
      final state = TicketListState.initial().copyWith(tickets: testTickets);
      expect(state.hasTickets, true);
    });

    test('hasError should return true when error exists', () {
      final state = TicketListState.initial().copyWith(error: 'Error');
      expect(state.hasError, true);
    });
  });
}
