// AdminDashboardViewModel tests
//
// Tests for the admin dashboard view model.

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:greenhive_app/features/admin/presentation/view_models/admin_dashboard_view_model.dart';
import 'package:greenhive_app/features/admin/presentation/state/admin_state.dart';
import 'package:greenhive_app/features/admin/services/admin_ticket_service.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';

@GenerateMocks([AdminTicketService, AppLogger])
import 'admin_dashboard_view_model_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAdminTicketService mockTicketService;
  late MockAppLogger mockLogger;
  late AdminDashboardViewModel viewModel;

  final testStats = const TicketStats(
    totalTickets: 100,
    openTickets: 30,
    inProgressTickets: 20,
    resolvedTickets: 40,
    closedTickets: 10,
    highPriorityTickets: 5,
    unassignedTickets: 3,
    ticketsToday: 8,
  );

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
      subject: 'Critical Bug',
      description: 'Description',
      deviceContext: testDeviceContext,
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
    ),
    SupportTicket(
      id: 'ticket-2',
      ticketNumber: 'TKT-002',
      userId: 'user-2',
      userEmail: 'user2@test.com',
      type: TicketType.feedback,
      category: TicketCategory.chat,
      priority: TicketPriority.medium,
      status: TicketStatus.inProgress,
      subject: 'Feature Request',
      description: 'Description',
      deviceContext: testDeviceContext,
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
    ),
  ];

  setUp(() {
    mockTicketService = MockAdminTicketService();
    mockLogger = MockAppLogger();

    viewModel = AdminDashboardViewModel(
      ticketService: mockTicketService,
      logger: mockLogger,
    );
  });

  group('AdminDashboardViewModel', () {
    group('initial state', () {
      test('should have default loading state', () {
        expect(viewModel.state.isLoading, true);
        expect(viewModel.state.stats, const TicketStats());
        expect(viewModel.state.recentTickets, isEmpty);
        expect(viewModel.state.error, isNull);
      });
    });

    group('initialize', () {
      test('should call loadData', () async {
        when(mockTicketService.getTicketStats())
            .thenAnswer((_) async => testStats);
        when(mockTicketService.getAllTickets(limit: 5))
            .thenAnswer((_) async => testTickets);

        await viewModel.initialize();

        verify(mockTicketService.getTicketStats()).called(1);
        verify(mockTicketService.getAllTickets(limit: 5)).called(1);
      });
    });

    group('loadData', () {
      test('should set loading state', () async {
        when(mockTicketService.getTicketStats())
            .thenAnswer((_) async => testStats);
        when(mockTicketService.getAllTickets(limit: 5))
            .thenAnswer((_) async => testTickets);

        final future = viewModel.loadData();
        expect(viewModel.state.isLoading, true);

        await future;
        expect(viewModel.state.isLoading, false);
      });

      test('should load stats and recent tickets', () async {
        when(mockTicketService.getTicketStats())
            .thenAnswer((_) async => testStats);
        when(mockTicketService.getAllTickets(limit: 5))
            .thenAnswer((_) async => testTickets);

        await viewModel.loadData();

        expect(viewModel.state.stats, testStats);
        expect(viewModel.state.recentTickets, testTickets);
        expect(viewModel.state.error, isNull);
      });

      test('should handle errors', () async {
        when(mockTicketService.getTicketStats())
            .thenThrow(Exception('Network error'));
        when(mockTicketService.getAllTickets(limit: 5))
            .thenThrow(Exception('Network error'));

        await viewModel.loadData();

        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, 'Failed to load dashboard data');
        verify(mockLogger.error(any, tag: 'AdminDashboardViewModel')).called(1);
      });
    });

    group('refresh', () {
      test('should reload data', () async {
        when(mockTicketService.getTicketStats())
            .thenAnswer((_) async => testStats);
        when(mockTicketService.getAllTickets(limit: 5))
            .thenAnswer((_) async => testTickets);

        await viewModel.refresh();

        verify(mockTicketService.getTicketStats()).called(1);
        verify(mockTicketService.getAllTickets(limit: 5)).called(1);
      });
    });
  });

  group('AdminDashboardState', () {
    test('should have default values', () {
      const state = AdminDashboardState();

      expect(state.isLoading, true);
      expect(state.stats, const TicketStats());
      expect(state.recentTickets, isEmpty);
      expect(state.error, isNull);
    });

    test('copyWith should update specified fields', () {
      const original = AdminDashboardState();
      final updated = original.copyWith(
        isLoading: false,
        stats: testStats,
        recentTickets: testTickets,
      );

      expect(updated.isLoading, false);
      expect(updated.stats, testStats);
      expect(updated.recentTickets, testTickets);
    });

    test('copyWith should preserve unspecified fields', () {
      final original = AdminDashboardState(
        isLoading: false,
        stats: testStats,
        recentTickets: testTickets,
      );
      final updated = original.copyWith(error: 'Error');

      expect(updated.isLoading, false);
      expect(updated.stats, testStats);
      expect(updated.recentTickets, testTickets);
      expect(updated.error, 'Error');
    });
  });

  group('TicketStats', () {
    test('should store all count fields', () {
      expect(testStats.totalTickets, 100);
      expect(testStats.openTickets, 30);
      expect(testStats.inProgressTickets, 20);
      expect(testStats.resolvedTickets, 40);
      expect(testStats.closedTickets, 10);
    });

    test('pendingTickets should sum open and in-progress', () {
      expect(testStats.pendingTickets, 50); // 30 + 20
    });

    test('completedTickets should sum resolved and closed', () {
      expect(testStats.completedTickets, 50); // 40 + 10
    });
  });
}
