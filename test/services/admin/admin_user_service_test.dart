import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:securityexperts_app/core/auth/role_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/admin/data/repositories/admin_user_repository.dart';
import 'package:securityexperts_app/features/admin/services/admin_user_service.dart';

@GenerateMocks([
  AdminUserRepository,
  FirebaseAuth,
  User,
  RoleService,
  AppLogger,
])
import 'admin_user_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdminUserService service;
  late MockAdminUserRepository mockRepository;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockRoleService mockRoleService;
  late MockAppLogger mockLogger;

  setUp(() {
    mockRepository = MockAdminUserRepository();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockRoleService = MockRoleService();
    mockLogger = MockAppLogger();

    // Setup auth
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_admin_id');

    // Setup default permission - allow all by default for most tests
    when(mockRoleService.hasPermission(any)).thenAnswer((_) async => true);

    // Register mocks in service locator
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockLogger);

    if (sl.isRegistered<RoleService>()) {
      sl.unregister<RoleService>();
    }
    sl.registerSingleton<RoleService>(mockRoleService);

    service = AdminUserService(
      repository: mockRepository,
      auth: mockAuth,
      roleService: mockRoleService,
      logger: mockLogger,
    );
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    if (sl.isRegistered<RoleService>()) {
      sl.unregister<RoleService>();
    }
  });

  group('AdminUserService', () {
    group('AdminUser model', () {
      test('should create AdminUser with all fields', () {
        final user = AdminUser(
          id: 'user_1',
          name: 'John Doe',
          email: 'john@example.com',
          phone: '+1234567890',
          roles: ['Consumer', 'Expert'],
          languages: ['English', 'Spanish'],
          expertises: ['Gardening'],
          isSuspended: false,
          createdAt: DateTime(2024, 1, 1),
          lastLogin: DateTime(2024, 6, 1),
        );

        expect(user.id, 'user_1');
        expect(user.name, 'John Doe');
        expect(user.email, 'john@example.com');
        expect(user.roles, ['Consumer', 'Expert']);
        expect(user.isExpert, true);
        expect(user.isAdmin, false);
      });

      test('should create AdminUser with default values', () {
        final user = AdminUser(
          id: 'user_1',
          name: 'Test User',
          createdAt: DateTime.now(),
        );

        expect(user.roles, isEmpty);
        expect(user.languages, isEmpty);
        expect(user.isSuspended, false);
        expect(user.notificationsEnabled, true);
      });

      test('isExpert should return true when roles contain Expert', () {
        final user = AdminUser(
          id: 'user_1',
          name: 'Expert User',
          roles: ['Consumer', 'Expert'],
          createdAt: DateTime.now(),
        );

        expect(user.isExpert, true);
      });

      test('isExpert should return false when roles do not contain Expert', () {
        final user = AdminUser(
          id: 'user_1',
          name: 'Regular User',
          roles: ['Consumer'],
          createdAt: DateTime.now(),
        );

        expect(user.isExpert, false);
      });

      test('isAdmin should return true for Admin role', () {
        final user = AdminUser(
          id: 'user_1',
          name: 'Admin User',
          roles: ['Admin'],
          createdAt: DateTime.now(),
        );

        expect(user.isAdmin, true);
      });

      test('isAdmin should return true for SuperAdmin role', () {
        final user = AdminUser(
          id: 'user_1',
          name: 'Super Admin',
          roles: ['SuperAdmin'],
          createdAt: DateTime.now(),
        );

        expect(user.isAdmin, true);
        expect(user.isSuperAdmin, true);
      });

      test('isSupport should return true for Support or Admin', () {
        final supportUser = AdminUser(
          id: 'user_1',
          name: 'Support User',
          roles: ['Support'],
          createdAt: DateTime.now(),
        );

        final adminUser = AdminUser(
          id: 'user_2',
          name: 'Admin User',
          roles: ['Admin'],
          createdAt: DateTime.now(),
        );

        expect(supportUser.isSupport, true);
        expect(adminUser.isSupport, true);
      });

      test('copyWith should create new instance with updated fields', () {
        final original = AdminUser(
          id: 'user_1',
          name: 'Original',
          email: 'original@test.com',
          roles: ['Consumer'],
          createdAt: DateTime.now(),
        );

        final updated = original.copyWith(
          name: 'Updated',
          roles: ['Consumer', 'Expert'],
          isSuspended: true,
        );

        expect(updated.id, 'user_1');
        expect(updated.name, 'Updated');
        expect(updated.email, 'original@test.com'); // Unchanged
        expect(updated.roles, ['Consumer', 'Expert']);
        expect(updated.isSuspended, true);
        expect(original.name, 'Original'); // Original unchanged
      });
    });

    group('getUsers', () {
      test('should return list of users', () async {
        final users = [
          AdminUser(
            id: 'user_1',
            name: 'John Doe',
            email: 'john@example.com',
            roles: ['Consumer'],
            createdAt: DateTime(2024, 1, 1),
          ),
          AdminUser(
            id: 'user_2',
            name: 'Jane Doe',
            email: 'jane@example.com',
            roles: ['Consumer', 'Expert'],
            createdAt: DateTime(2024, 1, 2),
          ),
        ];

        when(mockRepository.getUsers(
          roleFilter: anyNamed('roleFilter'),
          isSuspended: anyNamed('isSuspended'),
          limit: anyNamed('limit'),
          startAfter: anyNamed('startAfter'),
        )).thenAnswer((_) async => users);

        final result = await service.getUsers();

        expect(result.length, 2);
        expect(result[0].id, 'user_1');
        expect(result[0].name, 'John Doe');
        expect(result[1].id, 'user_2');
        expect(result[1].name, 'Jane Doe');
        verify(mockRoleService.hasPermission(AdminPermission.viewUsers)).called(1);
      });

      test('should apply client-side search filter', () async {
        final users = [
          AdminUser(
            id: 'user_1',
            name: 'John Doe',
            email: 'john@example.com',
            createdAt: DateTime(2024, 1, 1),
          ),
          AdminUser(
            id: 'user_2',
            name: 'Jane Smith',
            email: 'jane@example.com',
            createdAt: DateTime(2024, 1, 2),
          ),
        ];

        when(mockRepository.getUsers(
          roleFilter: anyNamed('roleFilter'),
          isSuspended: anyNamed('isSuspended'),
          limit: anyNamed('limit'),
          startAfter: anyNamed('startAfter'),
        )).thenAnswer((_) async => users);

        final result = await service.getUsers(searchQuery: 'john');

        expect(result.length, 1);
        expect(result[0].name, 'John Doe');
      });

      test('should filter by role', () async {
        final users = [
          AdminUser(
            id: 'user_1',
            name: 'Expert User',
            roles: ['Expert'],
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        when(mockRepository.getUsers(
          roleFilter: 'Expert',
          isSuspended: anyNamed('isSuspended'),
          limit: anyNamed('limit'),
          startAfter: anyNamed('startAfter'),
        )).thenAnswer((_) async => users);

        final result = await service.getUsers(roleFilter: 'Expert');

        expect(result.length, 1);
        expect(result[0].roles, contains('Expert'));
      });

      test('should filter by isExpert', () async {
        final users = [
          AdminUser(
            id: 'user_1',
            name: 'Expert User',
            roles: ['Consumer', 'Expert'],
            createdAt: DateTime(2024, 1, 1),
          ),
          AdminUser(
            id: 'user_2',
            name: 'Regular User',
            roles: ['Consumer'],
            createdAt: DateTime(2024, 1, 2),
          ),
        ];

        when(mockRepository.getUsers(
          roleFilter: anyNamed('roleFilter'),
          isSuspended: anyNamed('isSuspended'),
          limit: anyNamed('limit'),
          startAfter: anyNamed('startAfter'),
        )).thenAnswer((_) async => users);

        final result = await service.getUsers(isExpert: true);

        expect(result.length, 1);
        expect(result[0].isExpert, true);
      });

      test('should return empty list on error', () async {
        when(mockRepository.getUsers(
          roleFilter: anyNamed('roleFilter'),
          isSuspended: anyNamed('isSuspended'),
          limit: anyNamed('limit'),
          startAfter: anyNamed('startAfter'),
        )).thenThrow(Exception('Query error'));

        final result = await service.getUsers();

        expect(result, isEmpty);
      });

      test('should throw when permission denied', () async {
        when(mockRoleService.hasPermission(AdminPermission.viewUsers))
            .thenAnswer((_) async => false);

        expect(() => service.getUsers(), throwsException);
      });
    });

    group('getUser', () {
      test('should return user by ID', () async {
        final user = AdminUser(
          id: 'user_1',
          name: 'John Doe',
          email: 'john@example.com',
          createdAt: DateTime(2024, 1, 1),
        );

        when(mockRepository.getUser('user_1')).thenAnswer((_) async => user);

        final result = await service.getUser('user_1');

        expect(result, isNotNull);
        expect(result!.id, 'user_1');
        expect(result.name, 'John Doe');
      });

      test('should return null for non-existent user', () async {
        when(mockRepository.getUser('user_999')).thenAnswer((_) async => null);

        final result = await service.getUser('user_999');

        expect(result, isNull);
      });
    });

    group('suspendUser', () {
      test('should suspend user and return true', () async {
        when(mockRepository.updateSuspension(
          userId: anyNamed('userId'),
          isSuspended: anyNamed('isSuspended'),
          reason: anyNamed('reason'),
          suspendedBy: anyNamed('suspendedBy'),
        )).thenAnswer((_) async {});

        final result = await service.suspendUser(
          'user_1',
          'Violation of terms',
        );

        expect(result, true);
        verify(mockRepository.updateSuspension(
          userId: 'user_1',
          isSuspended: true,
          reason: 'Violation of terms',
          suspendedBy: 'test_admin_id',
        )).called(1);
        verify(mockLogger.info(any, tag: 'AdminUserService')).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.updateSuspension(
          userId: anyNamed('userId'),
          isSuspended: anyNamed('isSuspended'),
          reason: anyNamed('reason'),
          suspendedBy: anyNamed('suspendedBy'),
        )).thenThrow(Exception('Update error'));

        final result = await service.suspendUser('user_1', 'Test reason');

        expect(result, false);
      });
    });

    group('unsuspendUser', () {
      test('should unsuspend user and return true', () async {
        when(mockRepository.updateSuspension(
          userId: anyNamed('userId'),
          isSuspended: anyNamed('isSuspended'),
          reason: anyNamed('reason'),
          suspendedBy: anyNamed('suspendedBy'),
        )).thenAnswer((_) async {});

        final result = await service.unsuspendUser('user_1');

        expect(result, true);
        verify(mockRepository.updateSuspension(
          userId: 'user_1',
          isSuspended: false,
        )).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.updateSuspension(
          userId: anyNamed('userId'),
          isSuspended: anyNamed('isSuspended'),
          reason: anyNamed('reason'),
          suspendedBy: anyNamed('suspendedBy'),
        )).thenThrow(Exception('Update error'));

        final result = await service.unsuspendUser('user_1');

        expect(result, false);
      });
    });

    group('updateRoles', () {
      test('should update user roles and return true', () async {
        when(mockRepository.updateRoles(any, any)).thenAnswer((_) async {});

        final result = await service.updateRoles(
          'user_1',
          ['Consumer', 'Expert'],
        );

        expect(result, true);
        verify(mockRepository.updateRoles('user_1', ['Consumer', 'Expert']))
            .called(1);
        verify(mockLogger.info(any, tag: 'AdminUserService')).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.updateRoles(any, any))
            .thenThrow(Exception('Update error'));

        final result = await service.updateRoles('user_1', ['Consumer']);

        expect(result, false);
      });
    });

    group('addRole', () {
      test('should add role to user and return true', () async {
        when(mockRepository.addRole(any, any)).thenAnswer((_) async {});

        final result = await service.addRole('user_1', 'Expert');

        expect(result, true);
        verify(mockRepository.addRole('user_1', 'Expert')).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.addRole(any, any))
            .thenThrow(Exception('Update error'));

        final result = await service.addRole('user_1', 'Expert');

        expect(result, false);
      });
    });

    group('removeRole', () {
      test('should remove role from user and return true', () async {
        when(mockRepository.removeRole(any, any)).thenAnswer((_) async {});

        final result = await service.removeRole('user_1', 'Expert');

        expect(result, true);
        verify(mockRepository.removeRole('user_1', 'Expert')).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.removeRole(any, any))
            .thenThrow(Exception('Update error'));

        final result = await service.removeRole('user_1', 'Expert');

        expect(result, false);
      });
    });

    group('getStats', () {
      test('should return user statistics', () async {
        final users = [
          AdminUser(
            id: 'user_1',
            name: 'User 1',
            roles: ['Consumer'],
            isSuspended: false,
            createdAt: DateTime(2024, 1, 1),
          ),
          AdminUser(
            id: 'user_2',
            name: 'User 2',
            roles: ['Consumer', 'Expert'],
            isSuspended: false,
            createdAt: DateTime(2024, 1, 2),
          ),
          AdminUser(
            id: 'user_3',
            name: 'User 3',
            roles: ['Consumer'],
            isSuspended: true,
            createdAt: DateTime(2024, 1, 3),
          ),
        ];

        when(mockRepository.getAllUsersForStats()).thenAnswer((_) async => users);

        final result = await service.getStats();

        expect(result['totalUsers'], 3);
        expect(result['totalExperts'], 1);
        expect(result['suspendedUsers'], 1);
      });

      test('should return empty map on error', () async {
        when(mockRepository.getAllUsersForStats())
            .thenThrow(Exception('Query error'));

        final result = await service.getStats();

        expect(result, isEmpty);
      });
    });
  });
}
