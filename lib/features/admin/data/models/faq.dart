import 'package:cloud_firestore/cloud_firestore.dart';

/// FAQ category for organizing FAQs.
class FaqCategory {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FaqCategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.order = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory FaqCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FaqCategory(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      order: data['order'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      'order': order,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  FaqCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FaqCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// FAQ item with question and answer.
class Faq {
  final String id;
  final String question;
  final String answer;
  final String? categoryId;
  final String? categoryName;
  final List<String> tags;
  final int order;
  final bool isPublished;
  final int viewCount;
  final int helpfulCount;
  final int notHelpfulCount;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Faq({
    required this.id,
    required this.question,
    required this.answer,
    this.categoryId,
    this.categoryName,
    this.tags = const [],
    this.order = 0,
    this.isPublished = true,
    this.viewCount = 0,
    this.helpfulCount = 0,
    this.notHelpfulCount = 0,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Faq.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Faq(
      id: doc.id,
      question: data['question'] as String? ?? '',
      answer: data['answer'] as String? ?? '',
      categoryId: data['categoryId'] as String?,
      categoryName: data['categoryName'] as String?,
      tags: List<String>.from(data['tags'] as List<dynamic>? ?? []),
      order: data['order'] as int? ?? 0,
      isPublished: data['isPublished'] as bool? ?? true,
      viewCount: data['viewCount'] as int? ?? 0,
      helpfulCount: data['helpfulCount'] as int? ?? 0,
      notHelpfulCount: data['notHelpfulCount'] as int? ?? 0,
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'answer': answer,
      if (categoryId != null) 'categoryId': categoryId,
      if (categoryName != null) 'categoryName': categoryName,
      'tags': tags,
      'order': order,
      'isPublished': isPublished,
      'viewCount': viewCount,
      'helpfulCount': helpfulCount,
      'notHelpfulCount': notHelpfulCount,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  Faq copyWith({
    String? id,
    String? question,
    String? answer,
    String? categoryId,
    String? categoryName,
    List<String>? tags,
    int? order,
    bool? isPublished,
    int? viewCount,
    int? helpfulCount,
    int? notHelpfulCount,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Faq(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      tags: tags ?? this.tags,
      order: order ?? this.order,
      isPublished: isPublished ?? this.isPublished,
      viewCount: viewCount ?? this.viewCount,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      notHelpfulCount: notHelpfulCount ?? this.notHelpfulCount,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate helpfulness score as percentage.
  double get helpfulnessScore {
    final total = helpfulCount + notHelpfulCount;
    if (total == 0) return 0;
    return (helpfulCount / total) * 100;
  }
}
