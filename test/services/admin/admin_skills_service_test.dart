import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:securityexperts_app/core/auth/role_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/admin/data/repositories/admin_skills_repository.dart';
import 'package:securityexperts_app/features/admin/services/admin_skills_service.dart';

@GenerateMocks([
  AdminSkillsRepository,
  FirebaseAuth,
  User,
  RoleService,
  AppLogger,
])
import 'admin_skills_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdminSkillsService service;
  late MockAdminSkillsRepository mockRepository;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockRoleService mockRoleService;
  late MockAppLogger mockLogger;

  setUp(() {
    mockRepository = MockAdminSkillsRepository();
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

    service = AdminSkillsService(
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

  group('AdminSkillsService', () {
    group('SkillCategory model', () {
      test('should create SkillCategory with all fields', () {
        final category = SkillCategory(
          id: 'cat_1',
          name: 'Gardening',
          description: 'Garden related skills',
          icon: '🌱',
          order: 1,
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        );

        expect(category.id, 'cat_1');
        expect(category.name, 'Gardening');
        expect(category.description, 'Garden related skills');
        expect(category.icon, '🌱');
        expect(category.order, 1);
        expect(category.isActive, true);
      });

      test('should create SkillCategory with default values', () {
        final category = SkillCategory(
          id: 'cat_1',
          name: 'Test',
          order: 0,
        );

        expect(category.isActive, true);
        expect(category.description, isNull);
        expect(category.icon, isNull);
      });

      test('copyWith should create new instance with updated fields', () {
        final original = SkillCategory(
          id: 'cat_1',
          name: 'Original',
          order: 1,
        );

        final updated = original.copyWith(name: 'Updated', isActive: false);

        expect(updated.id, 'cat_1');
        expect(updated.name, 'Updated');
        expect(updated.isActive, false);
        expect(original.name, 'Original'); // Original unchanged
      });

      test('toFirestore should return correct map', () {
        final category = SkillCategory(
          id: 'cat_1',
          name: 'Gardening',
          description: 'Garden skills',
          icon: '🌱',
          order: 2,
          isActive: true,
        );

        final map = category.toFirestore();

        expect(map['name'], 'Gardening');
        expect(map['description'], 'Garden skills');
        expect(map['icon'], '🌱');
        expect(map['order'], 2);
        expect(map['isActive'], true);
        expect(map.containsKey('id'), false); // ID not in map
      });
    });

    group('AdminSkill model', () {
      test('should create AdminSkill with all fields', () {
        final skill = AdminSkill(
          id: 'skill_1',
          name: 'Composting',
          category: 'Gardening',
          tags: ['organic', 'waste'],
          description: 'Knowledge of composting techniques',
          isActive: true,
          usageCount: 50,
          createdBy: 'admin_1',
          createdAt: DateTime(2024, 1, 1),
        );

        expect(skill.id, 'skill_1');
        expect(skill.name, 'Composting');
        expect(skill.category, 'Gardening');
        expect(skill.tags, ['organic', 'waste']);
        expect(skill.isActive, true);
        expect(skill.usageCount, 50);
      });

      test('should create AdminSkill with default values', () {
        final skill = AdminSkill(
          id: 'skill_1',
          name: 'Test Skill',
          category: 'General',
          createdAt: DateTime.now(),
        );

        expect(skill.tags, isEmpty);
        expect(skill.description, isNull);
        expect(skill.isActive, true);
        expect(skill.usageCount, 0);
        expect(skill.createdBy, isNull);
      });

      test('copyWith should create new instance with updated fields', () {
        final original = AdminSkill(
          id: 'skill_1',
          name: 'Original',
          category: 'Cat1',
          createdAt: DateTime.now(),
        );

        final updated = original.copyWith(
          name: 'Updated',
          category: 'Cat2',
          isActive: false,
        );

        expect(updated.id, 'skill_1');
        expect(updated.name, 'Updated');
        expect(updated.category, 'Cat2');
        expect(updated.isActive, false);
        expect(original.name, 'Original'); // Original unchanged
      });

      test('toFirestore should return correct map', () {
        final skill = AdminSkill(
          id: 'skill_1',
          name: 'Composting',
          category: 'Gardening',
          tags: ['organic'],
          description: 'Composting techniques',
          isActive: true,
          usageCount: 10,
          createdBy: 'admin_1',
          createdAt: DateTime(2024, 1, 1),
        );

        final map = skill.toFirestore();

        expect(map['name'], 'Composting');
        expect(map['category'], 'Gardening');
        expect(map['tags'], ['organic']);
        expect(map['isActive'], true);
        expect(map.containsKey('id'), false); // ID not in map
      });
    });

    group('getCategories', () {
      test('should return categories from unique category names', () async {
        when(mockRepository.getUniqueCategories())
            .thenAnswer((_) async => ['Gardening', 'Cooking', 'Crafts']);

        final result = await service.getCategories();

        expect(result.length, 3);
        expect(result[0].name, 'Gardening');
        expect(result[1].name, 'Cooking');
        expect(result[2].name, 'Crafts');
      });

      test('should return empty list on error', () async {
        when(mockRepository.getUniqueCategories())
            .thenThrow(Exception('Query error'));

        final result = await service.getCategories();

        expect(result, isEmpty);
      });
    });

    group('getUniqueCategories', () {
      test('should return list of unique category names', () async {
        when(mockRepository.getUniqueCategories())
            .thenAnswer((_) async => ['Gardening', 'Cooking']);

        final result = await service.getUniqueCategories();

        expect(result, ['Gardening', 'Cooking']);
      });
    });

    group('getSkills', () {
      test('should return filtered skills', () async {
        final skills = [
          AdminSkill(
            id: 'skill_1',
            name: 'Composting',
            category: 'Gardening',
            isActive: true,
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        when(mockRepository.getSkills(
          category: anyNamed('category'),
          isActive: anyNamed('isActive'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => skills);

        final result = await service.getSkills(
          category: 'Gardening',
          isActive: true,
        );

        expect(result.length, 1);
        expect(result[0].id, 'skill_1');
        expect(result[0].name, 'Composting');
        verify(mockRoleService.hasPermission(AdminPermission.manageSkills)).called(1);
      });

      test('should apply client-side search filter', () async {
        final skills = [
          AdminSkill(
            id: 'skill_1',
            name: 'Composting',
            category: 'Gardening',
            description: 'Making compost from waste',
            createdAt: DateTime(2024, 1, 1),
          ),
          AdminSkill(
            id: 'skill_2',
            name: 'Pruning',
            category: 'Gardening',
            description: 'Trimming plants',
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        when(mockRepository.getSkills(
          category: anyNamed('category'),
          isActive: anyNamed('isActive'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => skills);

        final result = await service.getSkills(searchQuery: 'compost');

        expect(result.length, 1);
        expect(result[0].name, 'Composting');
      });

      test('should return empty list on error', () async {
        when(mockRepository.getSkills(
          category: anyNamed('category'),
          isActive: anyNamed('isActive'),
          limit: anyNamed('limit'),
        )).thenThrow(Exception('Query error'));

        final result = await service.getSkills();

        expect(result, isEmpty);
      });

      test('should throw when permission denied', () async {
        when(mockRoleService.hasPermission(AdminPermission.manageSkills))
            .thenAnswer((_) async => false);

        expect(() => service.getSkills(), throwsException);
      });
    });

    group('getSkill', () {
      test('should return skill by ID', () async {
        final skill = AdminSkill(
          id: 'skill_1',
          name: 'Composting',
          category: 'Gardening',
          createdAt: DateTime(2024, 1, 1),
        );

        when(mockRepository.getSkill('skill_1')).thenAnswer((_) async => skill);

        final result = await service.getSkill('skill_1');

        expect(result, isNotNull);
        expect(result!.id, 'skill_1');
      });

      test('should return null for non-existent skill', () async {
        when(mockRepository.getSkill('skill_999')).thenAnswer((_) async => null);

        final result = await service.getSkill('skill_999');

        expect(result, isNull);
      });
    });

    group('createSkill', () {
      test('should create skill and return document ID', () async {
        when(mockRepository.createSkill(
          name: anyNamed('name'),
          category: anyNamed('category'),
          description: anyNamed('description'),
          tags: anyNamed('tags'),
          isActive: anyNamed('isActive'),
          createdBy: anyNamed('createdBy'),
        )).thenAnswer((_) async => 'new_skill_id');

        final result = await service.createSkill(
          name: 'New Skill',
          category: 'Gardening',
          description: 'Test description',
          tags: ['tag1'],
          isActive: true,
        );

        expect(result, 'new_skill_id');
        verify(mockRepository.createSkill(
          name: 'New Skill',
          category: 'Gardening',
          description: 'Test description',
          tags: ['tag1'],
          isActive: true,
          createdBy: 'test_admin_id',
        )).called(1);
      });

      test('should return null on error', () async {
        when(mockRepository.createSkill(
          name: anyNamed('name'),
          category: anyNamed('category'),
          description: anyNamed('description'),
          tags: anyNamed('tags'),
          isActive: anyNamed('isActive'),
          createdBy: anyNamed('createdBy'),
        )).thenThrow(Exception('Write error'));

        final result = await service.createSkill(
          name: 'Test',
          category: 'Test',
        );

        expect(result, isNull);
      });
    });

    group('updateSkill', () {
      test('should update skill fields and return true', () async {
        when(mockRepository.updateSkill(
          any,
          name: anyNamed('name'),
          category: anyNamed('category'),
          description: anyNamed('description'),
          tags: anyNamed('tags'),
          isActive: anyNamed('isActive'),
        )).thenAnswer((_) async {});

        final result = await service.updateSkill(
          'skill_1',
          name: 'Updated Skill',
          category: 'Updated Category',
          isActive: false,
        );

        expect(result, true);
        verify(mockRepository.updateSkill(
          'skill_1',
          name: 'Updated Skill',
          category: 'Updated Category',
          isActive: false,
        )).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.updateSkill(
          any,
          name: anyNamed('name'),
          category: anyNamed('category'),
          description: anyNamed('description'),
          tags: anyNamed('tags'),
          isActive: anyNamed('isActive'),
        )).thenThrow(Exception('Update error'));

        final result = await service.updateSkill('skill_1', name: 'Test');

        expect(result, false);
      });
    });

    group('deleteSkill', () {
      test('should delete skill and return true', () async {
        when(mockRepository.deleteSkill('skill_1')).thenAnswer((_) async {});

        final result = await service.deleteSkill('skill_1');

        expect(result, true);
        verify(mockRepository.deleteSkill('skill_1')).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.deleteSkill('skill_1'))
            .thenThrow(Exception('Delete error'));

        final result = await service.deleteSkill('skill_1');

        expect(result, false);
      });
    });

    group('toggleActive', () {
      test('should toggle active status', () async {
        when(mockRepository.toggleActive('skill_1')).thenAnswer((_) async => false);

        final result = await service.toggleActive('skill_1');

        expect(result, true);
        verify(mockRepository.toggleActive('skill_1')).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.toggleActive('skill_999'))
            .thenThrow(Exception('Toggle error'));

        final result = await service.toggleActive('skill_999');

        expect(result, false);
      });
    });

    group('getStats', () {
      test('should return skill statistics', () async {
        final skills = [
          AdminSkill(
            id: 'skill_1',
            name: 'Skill 1',
            category: 'Cat1',
            isActive: true,
            usageCount: 100,
            createdAt: DateTime(2024, 1, 1),
          ),
          AdminSkill(
            id: 'skill_2',
            name: 'Skill 2',
            category: 'Cat2',
            isActive: false,
            usageCount: 50,
            createdAt: DateTime(2024, 1, 1),
          ),
          AdminSkill(
            id: 'skill_3',
            name: 'Skill 3',
            category: 'Cat1',
            isActive: true,
            usageCount: 30,
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        when(mockRepository.getAllSkillsForStats()).thenAnswer((_) async => skills);
        when(mockRepository.getUniqueCategories()).thenAnswer((_) async => ['Cat1', 'Cat2']);

        final result = await service.getStats();

        expect(result['totalSkills'], 3);
        expect(result['activeSkills'], 2);
        expect(result['inactiveSkills'], 1);
        expect(result['totalUsage'], 180);
        expect(result['totalCategories'], 2);
      });

      test('should return empty map on error', () async {
        when(mockRepository.getAllSkillsForStats())
            .thenThrow(Exception('Query error'));

        final result = await service.getStats();

        expect(result, isEmpty);
      });
    });
  });
}
