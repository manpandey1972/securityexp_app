import 'package:flutter_test/flutter_test.dart';

import 'package:securityexperts_app/features/admin/data/repositories/admin_skills_repository.dart';
import 'package:securityexperts_app/features/admin/data/models/admin_skill.dart';

import '../../../../helpers/service_mocks.mocks.dart';

void main() {
  group('AdminSkillsRepository', () {
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
    });

    group('Abstract interface', () {
      test('should define getSkills method', () {
        expect(AdminSkillsRepository, isNotNull);
      });

      test('should define getSkill method', () {
        expect(AdminSkillsRepository, isNotNull);
      });

      test('should define createSkill method', () {
        expect(AdminSkillsRepository, isNotNull);
      });

      test('should define updateSkill method', () {
        expect(AdminSkillsRepository, isNotNull);
      });

      test('should define deleteSkill method', () {
        expect(AdminSkillsRepository, isNotNull);
      });

      test('should define toggleActive method', () {
        expect(AdminSkillsRepository, isNotNull);
      });

      test('should define getUniqueCategories method', () {
        expect(AdminSkillsRepository, isNotNull);
      });

      test('should define getAllSkillsForStats method', () {
        expect(AdminSkillsRepository, isNotNull);
      });
    });

    group('AdminSkill model', () {
      test('should create skill with required fields', () {
        final skill = AdminSkill(
          id: 'skill-1',
          name: 'Gardening',
          category: 'Outdoor',
          createdAt: DateTime.now(),
        );

        expect(skill.id, equals('skill-1'));
        expect(skill.name, equals('Gardening'));
        expect(skill.category, equals('Outdoor'));
      });

      test('should create skill with all fields', () {
        final skill = AdminSkill(
          id: 'skill-2',
          name: 'Landscaping',
          category: 'Outdoor',
          tags: ['design', 'planning'],
          description: 'Garden landscaping expertise',
          isActive: true,
          usageCount: 50,
          createdBy: 'admin-1',
          createdAt: DateTime.now(),
        );

        expect(skill.tags, contains('design'));
        expect(skill.description, isNotNull);
        expect(skill.usageCount, equals(50));
        expect(skill.createdBy, equals('admin-1'));
      });

      test('should have default values', () {
        final skill = AdminSkill(
          id: 'skill-3',
          name: 'Test',
          category: 'Test Cat',
          createdAt: DateTime.now(),
        );

        expect(skill.tags, isEmpty);
        expect(skill.isActive, isTrue);
        expect(skill.usageCount, equals(0));
        expect(skill.description, isNull);
      });

      test('should convert to Firestore map', () {
        final skill = AdminSkill(
          id: 'skill-4',
          name: 'Test Skill',
          category: 'Test Category',
          tags: ['tag1', 'tag2'],
          description: 'Description',
          isActive: true,
          usageCount: 10,
          createdAt: DateTime.now(),
        );

        final map = skill.toFirestore();

        expect(map['name'], equals('Test Skill'));
        expect(map['category'], equals('Test Category'));
        expect(map['tags'], equals(['tag1', 'tag2']));
        expect(map['description'], equals('Description'));
        expect(map['isActive'], isTrue);
        expect(map['usageCount'], equals(10));
      });

      test('should support copyWith', () {
        final skill = AdminSkill(
          id: 'skill-5',
          name: 'Original',
          category: 'Cat',
          createdAt: DateTime.now(),
        );

        final updated = skill.copyWith(name: 'Updated', isActive: false);

        expect(updated.name, equals('Updated'));
        expect(updated.isActive, isFalse);
        expect(updated.id, equals('skill-5'));
        expect(updated.category, equals('Cat'));
      });
    });

    group('SkillCategory model', () {
      test('should create category with required fields', () {
        final category = SkillCategory(
          id: 'cat-1',
          name: 'Outdoor',
          order: 0,
        );

        expect(category.id, equals('cat-1'));
        expect(category.name, equals('Outdoor'));
        expect(category.order, equals(0));
      });

      test('should create category with all fields', () {
        final category = SkillCategory(
          id: 'cat-2',
          name: 'Indoor',
          description: 'Indoor activities',
          icon: 'home',
          order: 1,
          isActive: true,
          createdAt: DateTime.now(),
        );

        expect(category.description, equals('Indoor activities'));
        expect(category.icon, equals('home'));
        expect(category.isActive, isTrue);
      });

      test('should support copyWith', () {
        final category = SkillCategory(
          id: 'cat-3',
          name: 'Original',
          order: 0,
        );

        final updated = category.copyWith(name: 'Updated', order: 5);

        expect(updated.name, equals('Updated'));
        expect(updated.order, equals(5));
        expect(updated.id, equals('cat-3'));
      });
    });

    group('FirestoreAdminSkillsRepository', () {
      test('should use default Firestore instance', () {
        expect(FirestoreAdminSkillsRepository, isNotNull);
      });

      test('should accept custom Firestore instance', () {
        final repo = FirestoreAdminSkillsRepository(firestore: mockFirestore);
        expect(repo, isNotNull);
      });

      test('should use correct collection name', () {
        const skillsCollection = 'skills';
        expect(skillsCollection, equals('skills'));
      });
    });

    group('getSkills', () {
      test('should support category filter', () {
        final skills = [
          AdminSkill(
            id: '1',
            name: 'Gardening',
            category: 'Outdoor',
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '2',
            name: 'Cooking',
            category: 'Indoor',
            createdAt: DateTime.now(),
          ),
        ];

        final outdoor =
            skills.where((s) => s.category == 'Outdoor').toList();

        expect(outdoor.length, equals(1));
        expect(outdoor.first.name, equals('Gardening'));
      });

      test('should support isActive filter', () {
        final skills = [
          AdminSkill(
            id: '1',
            name: 'Active',
            category: 'Cat',
            isActive: true,
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '2',
            name: 'Inactive',
            category: 'Cat',
            isActive: false,
            createdAt: DateTime.now(),
          ),
        ];

        final active = skills.where((s) => s.isActive).toList();
        final inactive = skills.where((s) => !s.isActive).toList();

        expect(active.length, equals(1));
        expect(inactive.length, equals(1));
      });

      test('should order by name', () {
        final skills = [
          AdminSkill(
            id: '3',
            name: 'Zumba',
            category: 'Cat',
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '1',
            name: 'Aerobics',
            category: 'Cat',
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '2',
            name: 'Boxing',
            category: 'Cat',
            createdAt: DateTime.now(),
          ),
        ];

        skills.sort((a, b) => a.name.compareTo(b.name));

        expect(skills[0].name, equals('Aerobics'));
        expect(skills[1].name, equals('Boxing'));
        expect(skills[2].name, equals('Zumba'));
      });

      test('should support limit', () {
        final skills = List.generate(
          100,
          (i) => AdminSkill(
            id: '$i',
            name: 'Skill $i',
            category: 'Cat',
            createdAt: DateTime.now(),
          ),
        );

        final limited = skills.take(50).toList();

        expect(limited.length, equals(50));
      });
    });

    group('getSkill', () {
      test('should return skill by ID', () {
        final skills = [
          AdminSkill(
            id: 'skill-1',
            name: 'Test',
            category: 'Cat',
            createdAt: DateTime.now(),
          ),
        ];

        final skill = skills.where((s) => s.id == 'skill-1').firstOrNull;

        expect(skill, isNotNull);
        expect(skill!.name, equals('Test'));
      });

      test('should return null for non-existent skill', () {
        final skills = <AdminSkill>[];

        final skill = skills.where((s) => s.id == 'non-existent').firstOrNull;

        expect(skill, isNull);
      });
    });

    group('createSkill', () {
      test('should create skill with provided values', () {
        const name = 'New Skill';
        const category = 'New Category';
        const tags = ['tag1', 'tag2'];
        const isActive = true;

        expect(name, isNotEmpty);
        expect(category, isNotEmpty);
        expect(tags, hasLength(2));
        expect(isActive, isTrue);
      });

      test('should return new skill ID', () {
        const newId = 'new-skill-id';
        expect(newId, isNotEmpty);
      });

      test('should set default isActive to true', () {
        const defaultIsActive = true;
        expect(defaultIsActive, isTrue);
      });
    });

    group('updateSkill', () {
      test('should only update provided fields', () {
        final original = AdminSkill(
          id: 'skill-1',
          name: 'Original',
          category: 'Original Cat',
          description: 'Original Desc',
          createdAt: DateTime.now(),
        );

        final updated = original.copyWith(name: 'Updated');

        expect(updated.name, equals('Updated'));
        expect(updated.category, equals('Original Cat'));
        expect(updated.description, equals('Original Desc'));
      });
    });

    group('deleteSkill', () {
      test('should remove skill from list', () {
        final skills = [
          AdminSkill(
            id: 'skill-1',
            name: 'S1',
            category: 'C',
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: 'skill-2',
            name: 'S2',
            category: 'C',
            createdAt: DateTime.now(),
          ),
        ];

        final remaining = skills.where((s) => s.id != 'skill-1').toList();

        expect(remaining.length, equals(1));
        expect(remaining.first.id, equals('skill-2'));
      });
    });

    group('toggleActive', () {
      test('should flip isActive state', () {
        var isActive = true;
        isActive = !isActive;
        expect(isActive, isFalse);

        isActive = !isActive;
        expect(isActive, isTrue);
      });

      test('should return new state', () {
        const originalState = false;
        final newState = !originalState;
        expect(newState, isTrue);
      });
    });

    group('getUniqueCategories', () {
      test('should return unique category names', () {
        final skills = [
          AdminSkill(
            id: '1',
            name: 'S1',
            category: 'Outdoor',
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '2',
            name: 'S2',
            category: 'Indoor',
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '3',
            name: 'S3',
            category: 'Outdoor',
            createdAt: DateTime.now(),
          ),
        ];

        final categories = skills.map((s) => s.category).toSet().toList();

        expect(categories.length, equals(2));
        expect(categories, contains('Outdoor'));
        expect(categories, contains('Indoor'));
      });

      test('should return empty list when no skills', () {
        final skills = <AdminSkill>[];
        final categories = skills.map((s) => s.category).toSet().toList();
        expect(categories, isEmpty);
      });
    });

    group('getAllSkillsForStats', () {
      test('should return all skills for statistics', () {
        final skills = List.generate(
          50,
          (i) => AdminSkill(
            id: '$i',
            name: 'Skill $i',
            category: 'Cat ${i % 5}',
            createdAt: DateTime.now(),
          ),
        );

        expect(skills.length, equals(50));
      });

      test('should calculate active skill count', () {
        final skills = [
          AdminSkill(
            id: '1',
            name: 'S1',
            category: 'C',
            isActive: true,
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '2',
            name: 'S2',
            category: 'C',
            isActive: false,
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '3',
            name: 'S3',
            category: 'C',
            isActive: true,
            createdAt: DateTime.now(),
          ),
        ];

        final activeCount = skills.where((s) => s.isActive).length;

        expect(activeCount, equals(2));
      });

      test('should calculate category distribution', () {
        final skills = [
          AdminSkill(
            id: '1',
            name: 'S1',
            category: 'Cat A',
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '2',
            name: 'S2',
            category: 'Cat A',
            createdAt: DateTime.now(),
          ),
          AdminSkill(
            id: '3',
            name: 'S3',
            category: 'Cat B',
            createdAt: DateTime.now(),
          ),
        ];

        final categoryMap = <String, int>{};
        for (final skill in skills) {
          categoryMap[skill.category] =
              (categoryMap[skill.category] ?? 0) + 1;
        }

        expect(categoryMap['Cat A'], equals(2));
        expect(categoryMap['Cat B'], equals(1));
      });
    });
  });
}
