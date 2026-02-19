// AdminUsersViewModel tests
//
// Tests for the admin users view model.

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_users_view_model.dart';
import 'package:securityexperts_app/features/admin/presentation/state/admin_state.dart';
import 'package:securityexperts_app/features/admin/services/admin_user_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

@GenerateMocks([AdminUserService, AppLogger])
import 'admin_users_view_model_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAdminUserService mockUserService;
  late MockAppLogger mockLogger;
  late AdminUsersViewModel viewModel;

  final now = DateTime.now();
  final testUsers = <AdminUser>[
    AdminUser(
      id: 'user-1',
      name: 'John Doe',
      email: 'john@test.com',
      phone: '+1234567890',
      roles: ['Expert'],
      createdAt: now,
    ),
    AdminUser(
      id: 'user-2',
      name: 'Jane Smith',
      email: 'jane@test.com',
      roles: ['Admin'],
      createdAt: now,
      isSuspended: true,
      suspendedReason: 'Policy violation',
    ),
    AdminUser(
      id: 'user-3',
      name: 'Bob Wilson',
      email: 'bob@test.com',
      roles: [],
      createdAt: now,
    ),
  ];

  final testStats = <String, int>{
    'total': 100,
    'experts': 30,
    'merchants': 20,
    'admins': 5,
    'suspended': 3,
  };

  setUp(() {
    mockUserService = MockAdminUserService();
    mockLogger = MockAppLogger();

    viewModel = AdminUsersViewModel(
      userService: mockUserService,
      logger: mockLogger,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('AdminUsersViewModel', () {
    group('initial state', () {
      test('should have default loading state', () {
        expect(viewModel.state.isLoading, true);
        expect(viewModel.state.users, isEmpty);
        expect(viewModel.state.stats, isEmpty);
        expect(viewModel.state.error, isNull);
      });

      test('should have default filters', () {
        expect(viewModel.state.filters.roleFilter, isNull);
        expect(viewModel.state.filters.suspendedFilter, isNull);
        expect(viewModel.state.filters.searchQuery, '');
      });
    });

    group('initialize', () {
      test('should call loadUsers and loadStats', () async {
        when(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).thenAnswer((_) async => testUsers);
        when(mockUserService.getStats())
            .thenAnswer((_) async => testStats);

        await viewModel.initialize();

        verify(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).called(1);
        verify(mockUserService.getStats()).called(1);
      });
    });

    group('loadUsers', () {
      test('should set loading state', () async {
        when(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).thenAnswer((_) async => testUsers);

        final future = viewModel.loadUsers();
        expect(viewModel.state.isLoading, true);

        await future;
        expect(viewModel.state.isLoading, false);
      });

      test('should load users into state', () async {
        when(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).thenAnswer((_) async => testUsers);

        await viewModel.loadUsers();

        expect(viewModel.state.users, testUsers);
        expect(viewModel.state.error, isNull);
      });

      test('should handle errors', () async {
        when(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).thenThrow(Exception('Network error'));

        await viewModel.loadUsers();

        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, 'Failed to load users');
        verify(mockLogger.error(any, tag: 'AdminUsersViewModel')).called(1);
      });
    });

    group('searchUsers', () {
      test('should load users when query is empty', () async {
        when(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).thenAnswer((_) async => testUsers);

        await viewModel.searchUsers('');

        verify(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).called(1);
      });

      test('should search users by query', () async {
        when(mockUserService.searchUsers('john'))
            .thenAnswer((_) async => [testUsers.first]);

        await viewModel.searchUsers('john');

        expect(viewModel.state.users.length, 1);
        expect(viewModel.state.users.first.name, 'John Doe');
        expect(viewModel.state.filters.searchQuery, 'john');
      });
    });

    group('setRoleFilter', () {
      test('should update role filter and reload', () async {
        when(mockUserService.getUsers(
          roleFilter: 'Expert',
          isSuspended: null,
        )).thenAnswer((_) async => [testUsers.first]);

        viewModel.setRoleFilter('Expert');

        // Allow async loadUsers to complete
        await Future.delayed(Duration.zero);

        expect(viewModel.state.filters.roleFilter, 'Expert');
        verify(mockUserService.getUsers(
          roleFilter: 'Expert',
          isSuspended: null,
        )).called(1);
      });

      test('should clear role filter when null', () async {
        when(mockUserService.getUsers(
          roleFilter: anyNamed('roleFilter'),
          isSuspended: anyNamed('isSuspended'),
        )).thenAnswer((_) async => testUsers);

        viewModel.setRoleFilter('Expert');
        await Future.delayed(Duration.zero);
        
        viewModel.setRoleFilter(null);
        await Future.delayed(Duration.zero);

        expect(viewModel.state.filters.roleFilter, isNull);
      });
    });

    group('setSuspendedFilter', () {
      test('should update suspended filter and reload', () async {
        when(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: true,
        )).thenAnswer((_) async => [testUsers[1]]);

        viewModel.setSuspendedFilter(true);
        await Future.delayed(Duration.zero);

        expect(viewModel.state.filters.suspendedFilter, true);
        verify(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: true,
        )).called(1);
      });
    });

    group('clearFilters', () {
      test('should reset all filters', () async {
        when(mockUserService.getUsers(
          roleFilter: anyNamed('roleFilter'),
          isSuspended: anyNamed('isSuspended'),
        )).thenAnswer((_) async => testUsers);

        viewModel.setRoleFilter('Expert');
        await Future.delayed(Duration.zero);

        viewModel.clearFilters();
        await Future.delayed(Duration.zero);

        expect(viewModel.state.filters.roleFilter, isNull);
        expect(viewModel.state.filters.suspendedFilter, isNull);
        expect(viewModel.state.filters.searchQuery, '');
      });
    });

    group('setSearchQuery', () {
      test('should update search query without reloading', () {
        viewModel.setSearchQuery('test');

        expect(viewModel.state.filters.searchQuery, 'test');
        // Should not trigger API call
        verifyNever(mockUserService.searchUsers(any));
      });
    });

    group('suspendUser', () {
      test('should suspend user and reload', () async {
        when(mockUserService.suspendUser('user-1', 'Test reason'))
            .thenAnswer((_) async => true);
        when(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).thenAnswer((_) async => testUsers);
        when(mockUserService.getStats())
            .thenAnswer((_) async => testStats);

        final result = await viewModel.suspendUser('user-1', 'Test reason');

        expect(result, true);
        verify(mockUserService.suspendUser('user-1', 'Test reason')).called(1);
      });

      test('should return false on error', () async {
        when(mockUserService.suspendUser('user-1', 'Test reason'))
            .thenThrow(Exception('Error'));

        final result = await viewModel.suspendUser('user-1', 'Test reason');

        expect(result, false);
        verify(mockLogger.error(any, tag: 'AdminUsersViewModel')).called(1);
      });
    });

    group('unsuspendUser', () {
      test('should unsuspend user and reload', () async {
        when(mockUserService.unsuspendUser('user-2'))
            .thenAnswer((_) async => true);
        when(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).thenAnswer((_) async => testUsers);
        when(mockUserService.getStats())
            .thenAnswer((_) async => testStats);

        final result = await viewModel.unsuspendUser('user-2');

        expect(result, true);
        verify(mockUserService.unsuspendUser('user-2')).called(1);
      });
    });

    group('updateRoles', () {
      test('should update user roles and reload', () async {
        when(mockUserService.updateRoles('user-1', ['Admin', 'Expert']))
            .thenAnswer((_) async => true);
        when(mockUserService.getUsers(
          roleFilter: null,
          isSuspended: null,
        )).thenAnswer((_) async => testUsers);
        when(mockUserService.getStats())
            .thenAnswer((_) async => testStats);

        final result = await viewModel.updateRoles('user-1', ['Admin', 'Expert']);

        expect(result, true);
        verify(mockUserService.updateRoles('user-1', ['Admin', 'Expert'])).called(1);
      });
    });
  });

  group('AdminUsersState', () {
    test('should have default values', () {
      const state = AdminUsersState();

      expect(state.isLoading, true);
      expect(state.isLoadingMore, false);
      expect(state.users, isEmpty);
      expect(state.stats, isEmpty);
      expect(state.error, isNull);
      expect(state.hasMore, true);
    });

    test('copyWith should update specified fields', () {
      const original = AdminUsersState();
      final updated = original.copyWith(
        isLoading: false,
        users: testUsers,
        stats: testStats,
      );

      expect(updated.isLoading, false);
      expect(updated.users, testUsers);
      expect(updated.stats, testStats);
    });

    test('copyWith clearError should clear error', () {
      const state = AdminUsersState(error: 'Error');
      final updated = state.copyWith(clearError: true);

      expect(updated.error, isNull);
    });

    test('filteredUsers should filter by search query', () {
      final state = AdminUsersState(
        isLoading: false,
        users: testUsers,
        filters: const AdminUserFilters(searchQuery: 'john'),
      );

      expect(state.filteredUsers.length, 1);
      expect(state.filteredUsers.first.name, 'John Doe');
    });

    test('filteredUsers should return all users when no search', () {
      final state = AdminUsersState(
        isLoading: false,
        users: testUsers,
      );

      expect(state.filteredUsers.length, 3);
    });
  });

  group('AdminUserFilters', () {
    test('should have default values', () {
      const filters = AdminUserFilters();

      expect(filters.roleFilter, isNull);
      expect(filters.suspendedFilter, isNull);
      expect(filters.searchQuery, '');
    });

    test('hasActiveFilters should return true when filters set', () {
      const filters1 = AdminUserFilters(roleFilter: 'Expert');
      const filters2 = AdminUserFilters(suspendedFilter: true);
      const filters3 = AdminUserFilters(searchQuery: 'test');
      const filters4 = AdminUserFilters();

      expect(filters1.hasActiveFilters, true);
      expect(filters2.hasActiveFilters, true);
      expect(filters3.hasActiveFilters, true);
      expect(filters4.hasActiveFilters, false);
    });

    test('activeFilterCount should count role and suspended filters', () {
      const filters1 = AdminUserFilters(roleFilter: 'Expert');
      const filters2 = AdminUserFilters(roleFilter: 'Expert', suspendedFilter: true);
      const filters3 = AdminUserFilters(searchQuery: 'test'); // searchQuery not counted

      expect(filters1.activeFilterCount, 1);
      expect(filters2.activeFilterCount, 2);
      expect(filters3.activeFilterCount, 0);
    });

    test('copyWith clearRole should clear role filter', () {
      const filters = AdminUserFilters(roleFilter: 'Expert');
      final updated = filters.copyWith(clearRole: true);

      expect(updated.roleFilter, isNull);
    });

    test('copyWith clearSuspended should clear suspended filter', () {
      const filters = AdminUserFilters(suspendedFilter: true);
      final updated = filters.copyWith(clearSuspended: true);

      expect(updated.suspendedFilter, isNull);
    });
  });
}
