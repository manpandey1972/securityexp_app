import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/features/admin/data/models/admin_skill.dart';

/// Repository for admin skills data operations.
///
/// This repository handles all Firestore operations for skill management.
/// Business logic and permission checks are handled by [AdminSkillsService].
abstract class AdminSkillsRepository {
  /// Get all skills with optional filters.
  Future<List<AdminSkill>> getSkills({
    String? category,
    bool? isActive,
    int limit = 1000,
  });

  /// Get a single skill by ID.
  Future<AdminSkill?> getSkill(String skillId);

  /// Create a new skill and return its ID.
  Future<String> createSkill({
    required String name,
    required String category,
    String? description,
    List<String> tags = const [],
    bool isActive = true,
    String? createdBy,
  });

  /// Update a skill.
  Future<void> updateSkill(
    String skillId, {
    String? name,
    String? category,
    String? description,
    List<String>? tags,
    bool? isActive,
  });

  /// Delete a skill.
  Future<void> deleteSkill(String skillId);

  /// Toggle skill active status and return new status.
  Future<bool> toggleActive(String skillId);

  /// Get all unique category names from skills.
  Future<List<String>> getUniqueCategories();

  /// Get all skills for statistics calculation.
  Future<List<AdminSkill>> getAllSkillsForStats();
}

/// Firestore implementation of [AdminSkillsRepository].
class FirestoreAdminSkillsRepository implements AdminSkillsRepository {
  final FirebaseFirestore _firestore;

  static const String _skillsCollection = 'skills';

  FirestoreAdminSkillsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreInstance().db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_skillsCollection);

  @override
  Future<List<AdminSkill>> getSkills({
    String? category,
    bool? isActive,
    int limit = 1000,
  }) async {
    Query query = _collection;

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    query = query.orderBy('name').limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => AdminSkill.fromFirestore(doc)).toList();
  }

  @override
  Future<AdminSkill?> getSkill(String skillId) async {
    final doc = await _collection.doc(skillId).get();
    if (!doc.exists) return null;
    return AdminSkill.fromFirestore(doc);
  }

  @override
  Future<String> createSkill({
    required String name,
    required String category,
    String? description,
    List<String> tags = const [],
    bool isActive = true,
    String? createdBy,
  }) async {
    final docRef = await _collection.add({
      'name': name,
      'category': category,
      'description': description,
      'tags': tags,
      'isActive': isActive,
      'usageCount': 0,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  @override
  Future<void> updateSkill(
    String skillId, {
    String? name,
    String? category,
    String? description,
    List<String>? tags,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (category != null) updates['category'] = category;
    if (description != null) updates['description'] = description;
    if (tags != null) updates['tags'] = tags;
    if (isActive != null) updates['isActive'] = isActive;

    await _collection.doc(skillId).update(updates);
  }

  @override
  Future<void> deleteSkill(String skillId) async {
    await _collection.doc(skillId).delete();
  }

  @override
  Future<bool> toggleActive(String skillId) async {
    final doc = await _collection.doc(skillId).get();
    if (!doc.exists) {
      throw Exception('Skill not found: $skillId');
    }

    final currentActive = doc.data()?['isActive'] as bool? ?? true;
    final newActive = !currentActive;

    await _collection.doc(skillId).update({
      'isActive': newActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return newActive;
  }

  @override
  Future<List<String>> getUniqueCategories() async {
    final snapshot = await _collection.get();
    final categories = <String>{};
    for (final doc in snapshot.docs) {
      final category = doc.data()['category'] as String?;
      if (category != null && category.isNotEmpty) {
        categories.add(category);
      }
    }
    return categories.toList()..sort();
  }

  @override
  Future<List<AdminSkill>> getAllSkillsForStats() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => AdminSkill.fromFirestore(doc)).toList();
  }
}
