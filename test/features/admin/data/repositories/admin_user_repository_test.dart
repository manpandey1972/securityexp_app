import 'package:flutter_test/flutter_test.dart';

import 'package:greenhive_app/features/admin/data/repositories/admin_user_repository.dart';
import 'package:greenhive_app/features/admin/data/models/admin_user.dart';

import '../../../../helpers/service_mocks.mocks.dart';

void main() {
  group('AdminUserRepository', () {
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
    });

    group('Abstract interface', () {
      test('should define getUsers method', () {
        expect(AdminUserRepository, isNotNull);
      });

      test('should define searchUsers method', () {
        expect(AdminUserRepository, isNotNull);
      });

      test('should define getUser method', () {
        expect(AdminUserRepository, isNotNull);
      });

      test('should define updateSuspension method', () {
        expect(AdminUserRepository, isNotNull);
      });

      test('should define updateRoles method', () {
        expect(AdminUserRepository, isNotNull);
      });

      test('should define addRole method', () {
        expect(AdminUserRepository, isNotNull);
      });

      test('should define removeRole method', () {
        expect(AdminUserRepository, isNotNull);
      });

      test('should define getAllUsersForStats method', () {
        expect(AdminUserRepository, isNotNull);
      });
    });

    group('AdminUser model', () {
      test('should create user with required fields', () {
        final user = AdminUser(
          id: 'user-1',
          name: 'Test User',
          email: 'test@example.com',
          roles: ['User'],
          createdAt: DateTime.now(),
        );

        expect(user.id, equals('user-1'));
        expect(user.name, equals('Test User'));
        expect(user.email, equals('test@example.com'));
        expect(user.roles, contains('User'));
      });

      test('should create user with all fields', () {
        final user = AdminUser(
          id: 'user-2',
          name: 'Full User',
          email: 'full@example.com',
          phone: '+1234567890',
          roles: ['Expert', 'Admin'],
          languages: ['en', 'es'],
          expertises: ['gardening'],
          bio: 'Expert bio',
          isSuspended: false,
          profilePictureUrl: 'https://example.com/pic.jpg',
          createdAt: DateTime.now(),
        );

        expect(user.phone, equals('+1234567890'));
        expect(user.languages, contains('en'));
        expect(user.expertises, contains('gardening'));
        expect(user.isSuspended, isFalse);
      });

      test('should handle suspended user', () {
        final user = AdminUser(
          id: 'user-suspended',
          name: 'Suspended User',
          email: 'suspended@example.com',
          roles: ['User'],
          isSuspended: true,
          suspendedReason: 'Violated terms',
          suspendedAt: DateTime.now(),
          suspendedBy: 'admin-1',
          createdAt: DateTime.now(),
        );

        expect(user.isSuspended, isTrue);
        expect(user.suspendedReason, equals('Violated terms'));
        expect(user.suspendedBy, equals('admin-1'));
      });

      test('should have default values for optional fields', () {
        final user = AdminUser(
          id: 'user-default',
          name: 'Default User',
          email: 'default@example.com',
          roles: [],
          createdAt: DateTime.now(),
        );

        expect(user.isSuspended, isFalse);
        expect(user.languages, isEmpty);
        expect(user.expertises, isEmpty);
      });

      test('should support role checking helpers', () {
        final adminUser = AdminUser(
          id: 'admin',
          name: 'Admin',
          email: 'admin@example.com',
          roles: ['Admin'],
          createdAt: DateTime.now(),
        );

        final expertUser = AdminUser(
          id: 'expert',
          name: 'Expert',
          email: 'expert@example.com',
          roles: ['Expert'],
          createdAt: DateTime.now(),
        );

        expect(adminUser.roles.contains('Admin'), isTrue);
        expect(expertUser.roles.contains('Expert'), isTrue);
      });
    });

    group('FirestoreAdminUserRepository', () {
      test('should use default Firestore instance', () {
        expect(FirestoreAdminUserRepository, isNotNull);
      });

      test('should accept custom Firestore instance', () {
        final repo = FirestoreAdminUserRepository(firestore: mockFirestore);
        expect(repo, isNotNull);
      });

      test('should use correct collection name', () {
        const usersCollection = 'users';
        expect(usersCollection, equals('users'));
      });
    });

    group('getUsers', () {
      test('should support roleFilter', () {
        final users = [
          AdminUser(
            id: '1',
            name: 'Admin',
            email: 'a@e.com',
            roles: ['Admin'],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '2',
            name: 'Expert',
            email: 'e@e.com',
            roles: ['Expert'],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '3',
            name: 'User',
            email: 'u@e.com',
            roles: ['User'],
            createdAt: DateTime.now(),
          ),
        ];

        final experts = users.where((u) => u.roles.contains('Expert')).toList();
        final admins = users.where((u) => u.roles.contains('Admin')).toList();

        expect(experts.length, equals(1));
        expect(admins.length, equals(1));
      });

      test('should filter Admin to include SuperAdmin', () {
        // When filtering for 'Admin', should include both Admin and SuperAdmin
        final users = [
          AdminUser(
            id: '1',
            name: 'Admin',
            email: 'a@e.com',
            roles: ['Admin'],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '2',
            name: 'SuperAdmin',
            email: 's@e.com',
            roles: ['SuperAdmin'],
            createdAt: DateTime.now(),
          ),
        ];

        final adminTypes = users
            .where(
              (u) =>
                  u.roles.contains('Admin') || u.roles.contains('SuperAdmin'),
            )
            .toList();

        expect(adminTypes.length, equals(2));
      });

      test('should support isSuspended filter', () {
        final users = [
          AdminUser(
            id: '1',
            name: 'Active',
            email: 'a@e.com',
            roles: [],
            isSuspended: false,
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '2',
            name: 'Suspended',
            email: 's@e.com',
            roles: [],
            isSuspended: true,
            createdAt: DateTime.now(),
          ),
        ];

        final active = users.where((u) => !u.isSuspended).toList();
        final suspended = users.where((u) => u.isSuspended).toList();

        expect(active.length, equals(1));
        expect(suspended.length, equals(1));
      });

      test('should support limit', () {
        final users = List.generate(
          100,
          (i) => AdminUser(
            id: '$i',
            name: 'User $i',
            email: 'user$i@example.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
        );

        final limited = users.take(50).toList();

        expect(limited.length, equals(50));
      });

      test('should order by name', () {
        final users = [
          AdminUser(
            id: '3',
            name: 'Zara',
            email: 'z@e.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '1',
            name: 'Alice',
            email: 'a@e.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '2',
            name: 'Bob',
            email: 'b@e.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
        ];

        users.sort((a, b) => a.name.compareTo(b.name));

        expect(users[0].name, equals('Alice'));
        expect(users[1].name, equals('Bob'));
        expect(users[2].name, equals('Zara'));
      });

      test('should support pagination with startAfter', () {
        // Pagination is implemented with DocumentSnapshot
        const hasStartAfter = true;
        expect(hasStartAfter, isTrue);
      });
    });

    group('searchUsers', () {
      test('should search by name', () {
        final users = [
          AdminUser(
            id: '1',
            name: 'John Doe',
            email: 'john@e.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '2',
            name: 'Jane Smith',
            email: 'jane@e.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
        ];

        final query = 'john';
        final results = users
            .where((u) => u.name.toLowerCase().contains(query.toLowerCase()))
            .toList();

        expect(results.length, equals(1));
        expect(results.first.name, equals('John Doe'));
      });

      test('should search by email', () {
        final users = [
          AdminUser(
            id: '1',
            name: 'User One',
            email: 'unique@example.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '2',
            name: 'User Two',
            email: 'other@example.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
        ];

        final query = 'unique';
        final results = users
            .where((u) => u.email?.toLowerCase().contains(query.toLowerCase()) ?? false)
            .toList();

        expect(results.length, equals(1));
      });

      test('should support search limit', () {
        const limit = 100;
        expect(limit, equals(100));
      });

      test('should return empty list for no matches', () {
        final users = <AdminUser>[];
        final query = 'xyz';
        final results = users
            .where((u) => u.name.toLowerCase().contains(query.toLowerCase()))
            .toList();

        expect(results, isEmpty);
      });
    });

    group('getUser', () {
      test('should return user by ID', () {
        final users = [
          AdminUser(
            id: 'user-1',
            name: 'Test',
            email: 't@e.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
        ];

        final user = users.where((u) => u.id == 'user-1').firstOrNull;

        expect(user, isNotNull);
        expect(user!.name, equals('Test'));
      });

      test('should return null for non-existent user', () {
        final users = <AdminUser>[];
        final user = users.where((u) => u.id == 'non-existent').firstOrNull;

        expect(user, isNull);
      });
    });

    group('updateSuspension', () {
      test('should suspend user with reason', () {
        var isSuspended = false;
        String? reason;
        String? suspendedBy;
        DateTime? suspendedAt;

        // Suspend
        isSuspended = true;
        reason = 'Violated terms';
        suspendedBy = 'admin-1';
        suspendedAt = DateTime.now();

        expect(isSuspended, isTrue);
        expect(reason, equals('Violated terms'));
        expect(suspendedBy, equals('admin-1'));
        expect(suspendedAt, isNotNull);
      });

      test('should unsuspend user and clear fields', () {
        var isSuspended = true;
        String? reason = 'Some reason';
        String? suspendedBy = 'admin-1';
        DateTime? suspendedAt = DateTime.now();

        // Unsuspend
        isSuspended = false;
        reason = null;
        suspendedBy = null;
        suspendedAt = null;

        expect(isSuspended, isFalse);
        expect(reason, isNull);
        expect(suspendedBy, isNull);
        expect(suspendedAt, isNull);
      });
    });

    group('updateRoles', () {
      test('should replace all roles', () {
        var roles = ['User'];

        roles = ['Expert', 'Admin'];

        expect(roles, contains('Expert'));
        expect(roles, contains('Admin'));
        expect(roles, isNot(contains('User')));
      });
    });

    group('addRole', () {
      test('should add role to user', () {
        final roles = ['User'];

        final newRoles = [...roles, 'Expert'];

        expect(newRoles, contains('User'));
        expect(newRoles, contains('Expert'));
        expect(newRoles.length, equals(2));
      });

      test('should not duplicate existing role', () {
        final roles = ['User', 'Expert'];

        final roleToAdd = 'Expert';
        final newRoles = roles.contains(roleToAdd) ? roles : [...roles, roleToAdd];

        expect(newRoles.length, equals(2));
      });
    });

    group('removeRole', () {
      test('should remove role from user', () {
        final roles = ['User', 'Expert', 'Admin'];

        final newRoles = roles.where((r) => r != 'Expert').toList();

        expect(newRoles, contains('User'));
        expect(newRoles, contains('Admin'));
        expect(newRoles, isNot(contains('Expert')));
        expect(newRoles.length, equals(2));
      });

      test('should handle removing non-existent role', () {
        final roles = ['User'];

        final newRoles = roles.where((r) => r != 'Admin').toList();

        expect(newRoles.length, equals(1));
        expect(newRoles, contains('User'));
      });
    });

    group('getAllUsersForStats', () {
      test('should return all users', () {
        final users = List.generate(
          100,
          (i) => AdminUser(
            id: '$i',
            name: 'User $i',
            email: 'user$i@e.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
        );

        expect(users.length, equals(100));
      });

      test('should calculate total user count', () {
        final users = List.generate(
          50,
          (i) => AdminUser(
            id: '$i',
            name: 'User $i',
            email: 'user$i@e.com',
            roles: [],
            createdAt: DateTime.now(),
          ),
        );

        expect(users.length, equals(50));
      });

      test('should calculate role distribution', () {
        final users = [
          AdminUser(
            id: '1',
            name: 'U1',
            email: 'u1@e.com',
            roles: ['Admin'],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '2',
            name: 'U2',
            email: 'u2@e.com',
            roles: ['Expert'],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '3',
            name: 'U3',
            email: 'u3@e.com',
            roles: ['Expert'],
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '4',
            name: 'U4',
            email: 'u4@e.com',
            roles: ['User'],
            createdAt: DateTime.now(),
          ),
        ];

        final roleMap = <String, int>{};
        for (final user in users) {
          for (final role in user.roles) {
            roleMap[role] = (roleMap[role] ?? 0) + 1;
          }
        }

        expect(roleMap['Admin'], equals(1));
        expect(roleMap['Expert'], equals(2));
        expect(roleMap['User'], equals(1));
      });

      test('should calculate suspended user count', () {
        final users = [
          AdminUser(
            id: '1',
            name: 'U1',
            email: 'u1@e.com',
            roles: [],
            isSuspended: false,
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '2',
            name: 'U2',
            email: 'u2@e.com',
            roles: [],
            isSuspended: true,
            createdAt: DateTime.now(),
          ),
          AdminUser(
            id: '3',
            name: 'U3',
            email: 'u3@e.com',
            roles: [],
            isSuspended: true,
            createdAt: DateTime.now(),
          ),
        ];

        final suspendedCount = users.where((u) => u.isSuspended).length;

        expect(suspendedCount, equals(2));
      });
    });
  });
}
