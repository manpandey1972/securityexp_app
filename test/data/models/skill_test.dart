import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/data/models/skill.dart';

void main() {
  group('Skill Model', () {
    group('Constructor', () {
      test('should create Skill with all required fields', () {
        final skill = Skill(
          id: 'skill_1',
          name: 'Organic Farming',
          category: 'Agriculture',
          tags: ['organic', 'farming', 'sustainable'],
        );

        expect(skill.id, 'skill_1');
        expect(skill.name, 'Organic Farming');
        expect(skill.category, 'Agriculture');
        expect(skill.tags, ['organic', 'farming', 'sustainable']);
      });

      test('should create Skill with empty tags list', () {
        final skill = Skill(
          id: 'skill_2',
          name: 'General Gardening',
          category: 'Gardening',
          tags: [],
        );

        expect(skill.tags, isEmpty);
      });
    });

    group('fromMap', () {
      test('should create Skill from Map with all fields', () {
        final map = {
          'name': 'Hydroponics',
          'category': 'Urban Farming',
          'tags': ['indoor', 'water-based', 'technology'],
        };

        final skill = Skill.fromMap(map, 'skill_123');

        expect(skill.id, 'skill_123');
        expect(skill.name, 'Hydroponics');
        expect(skill.category, 'Urban Farming');
        expect(skill.tags, ['indoor', 'water-based', 'technology']);
      });

      test('should handle missing name field with empty string', () {
        final map = <String, dynamic>{
          'category': 'Agriculture',
          'tags': ['test'],
        };

        final skill = Skill.fromMap(map, 'skill_456');

        expect(skill.name, '');
      });

      test('should handle missing category field with empty string', () {
        final map = <String, dynamic>{
          'name': 'Test Skill',
          'tags': ['test'],
        };

        final skill = Skill.fromMap(map, 'skill_789');

        expect(skill.category, '');
      });

      test('should handle missing tags field with empty list', () {
        final map = <String, dynamic>{
          'name': 'Test Skill',
          'category': 'Test Category',
        };

        final skill = Skill.fromMap(map, 'skill_abc');

        expect(skill.tags, isEmpty);
      });

      test('should handle null tags field with empty list', () {
        final map = <String, dynamic>{
          'name': 'Test Skill',
          'category': 'Test Category',
          'tags': null,
        };

        final skill = Skill.fromMap(map, 'skill_def');

        expect(skill.tags, isEmpty);
      });

      test('should handle missing fields with defaults', () {
        final map = <String, dynamic>{};

        final skill = Skill.fromMap(map, 'skill_id_2');

        expect(skill.id, 'skill_id_2');
        expect(skill.name, '');
        expect(skill.category, '');
        expect(skill.tags, isEmpty);
      });

      test('should use provided id parameter instead of map data', () {
        final map = {
          'id': 'wrong_id',
          'name': 'Test Skill',
          'category': 'Test',
          'tags': <String>[],
        };

        final skill = Skill.fromMap(map, 'correct_id');

        expect(skill.id, 'correct_id');
      });
    });

    group('toMap', () {
      test('should convert Skill to Map correctly', () {
        final skill = Skill(
          id: 'skill_output',
          name: 'Composting',
          category: 'Sustainability',
          tags: ['compost', 'organic', 'waste'],
        );

        final map = skill.toMap();

        expect(map['id'], 'skill_output');
        expect(map['name'], 'Composting');
        expect(map['category'], 'Sustainability');
        expect(map['tags'], ['compost', 'organic', 'waste']);
      });

      test('should include empty tags list in Map', () {
        final skill = Skill(
          id: 'skill_no_tags',
          name: 'Basic Skill',
          category: 'General',
          tags: [],
        );

        final map = skill.toMap();

        expect(map['tags'], isEmpty);
        expect(map.containsKey('tags'), isTrue);
      });
    });

    group('JSON Roundtrip', () {
      test('should survive Map roundtrip', () {
        final original = Skill(
          id: 'roundtrip_skill',
          name: 'Soil Analysis',
          category: 'Science',
          tags: ['soil', 'testing', 'analysis'],
        );

        final map = original.toMap();
        final restored = Skill.fromMap(map, original.id);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.category, original.category);
        expect(restored.tags, original.tags);
      });
    });

    group('Edge Cases', () {
      test('should handle skill with special characters in name', () {
        final skill = Skill(
          id: 'special_skill',
          name: 'Plant Care & Maintenance',
          category: 'Care/Maintenance',
          tags: ['care', 'plant-care', 'maintenance_tips'],
        );

        final map = skill.toMap();
        final restored = Skill.fromMap(map, skill.id);

        expect(restored.name, 'Plant Care & Maintenance');
        expect(restored.category, 'Care/Maintenance');
      });

      test('should handle skill with unicode characters', () {
        final skill = Skill(
          id: 'unicode_skill',
          name: '植物护理',
          category: '园艺',
          tags: ['中文', '标签'],
        );

        final map = skill.toMap();
        final restored = Skill.fromMap(map, skill.id);

        expect(restored.name, '植物护理');
        expect(restored.category, '园艺');
        expect(restored.tags, ['中文', '标签']);
      });

      test('should handle skill with very long tag list', () {
        final tags = List.generate(100, (i) => 'tag_$i');
        final skill = Skill(
          id: 'many_tags_skill',
          name: 'Skill with Many Tags',
          category: 'Test',
          tags: tags,
        );

        expect(skill.tags.length, 100);
        expect(skill.tags.first, 'tag_0');
        expect(skill.tags.last, 'tag_99');
      });
    });
  });
}
