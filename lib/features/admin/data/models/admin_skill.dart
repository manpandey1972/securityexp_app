import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class for const DateTime default value in constructors.
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now();
}

/// Skill category model for admin panel.
///
/// Categories are used to organize skills into groups.
class SkillCategory {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final int order;
  final bool isActive;
  final DateTime createdAt;

  const SkillCategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    required this.order,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? const _DefaultDateTime();

  factory SkillCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SkillCategory(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      order: data['order'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'order': order,
      'isActive': isActive,
    };
  }

  SkillCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    int? order,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SkillCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Admin skill model with additional metadata.
///
/// Represents a skill that can be assigned to experts.
class AdminSkill {
  final String id;
  final String name;
  final String category;
  final List<String> tags;
  final String? description;
  final bool isActive;
  final int usageCount;
  final String? createdBy;
  final DateTime createdAt;

  const AdminSkill({
    required this.id,
    required this.name,
    required this.category,
    this.tags = const [],
    this.description,
    this.isActive = true,
    this.usageCount = 0,
    this.createdBy,
    required this.createdAt,
  });

  factory AdminSkill.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminSkill(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      tags: List<String>.from(data['tags'] as List<dynamic>? ?? []),
      description: data['description'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      usageCount: data['usageCount'] as int? ?? 0,
      createdBy: data['createdBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'tags': tags,
      'description': description,
      'isActive': isActive,
      'usageCount': usageCount,
    };
  }

  AdminSkill copyWith({
    String? id,
    String? name,
    String? category,
    List<String>? tags,
    String? description,
    bool? isActive,
    int? usageCount,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return AdminSkill(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      usageCount: usageCount ?? this.usageCount,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
