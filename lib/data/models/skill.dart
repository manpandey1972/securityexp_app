import 'package:cloud_firestore/cloud_firestore.dart';

class Skill {
  final String id;
  final String name;
  final String category;
  final List<String> tags;

  Skill({
    required this.id,
    required this.name,
    required this.category,
    required this.tags,
  });

  /// Deserialize from a Firestore [DocumentSnapshot].
  factory Skill.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Skill.fromJson(data, id: doc.id);
  }

  /// Deserialize from a JSON map.
  factory Skill.fromJson(Map<String, dynamic> json, {String? id}) {
    return Skill(
      id: id ?? json['id'] as String? ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  /// @Deprecated('Use fromJson() instead')
  factory Skill.fromMap(Map<String, dynamic> map, String id) =>
      Skill.fromJson(map, id: id);

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'category': category, 'tags': tags};
  }

  /// @Deprecated('Use toJson() instead')
  Map<String, dynamic> toMap() => toJson();
}
