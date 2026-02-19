import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Manages agricultural skills data for the GreenHive application.
/// 
/// Skills are loaded from a JSON file (assets/data/skills.json) rather than
/// being hardcoded, making it easier to update and maintain the skills database.
class SkillsInitializer {
  static const String _skillsAssetPath = 'assets/data/skills.json';
  
  /// Initialize skills collection in Firestore by loading from JSON asset.
  /// Run this once to populate the skills database.
  static Future<void> initializeSkills() async {
    final firestore = FirestoreInstance().db;
    final logger = sl<AppLogger>();

    try {
      final skills = await loadSkillsFromAsset();

      WriteBatch batch = firestore.batch();
      int count = 0;

      for (var skill in skills) {
        final docRef = firestore.collection('skills').doc();
        batch.set(docRef, skill);
        count++;

        // Firestore batch limit is 500
        if (count % 490 == 0) {
          await batch.commit();
          batch = firestore.batch();
        }
      }

      // Commit remaining
      if (count % 490 != 0) {
        await batch.commit();
      }

      logger.info('Successfully initialized $count skills', tag: 'SkillsInitializer');
    } catch (e, stackTrace) {
      logger.error(
        'Failed to initialize skills',
        error: e,
        stackTrace: stackTrace,
        tag: 'SkillsInitializer',
      );
      rethrow;
    }
  }

  /// Loads skills data from the JSON asset file.
  /// 
  /// Returns a list of skill maps with the following structure:
  /// ```dart
  /// {
  ///   'name': 'Crop Consultant',
  ///   'category': 'Crop Production & Cultivation',
  ///   'tags': ['crops', 'consulting', 'farming'],
  /// }
  /// ```
  static Future<List<Map<String, dynamic>>> loadSkillsFromAsset() async {
    final String jsonString = await rootBundle.loadString(_skillsAssetPath);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    
    return jsonList.map((item) {
      final Map<String, dynamic> skill = Map<String, dynamic>.from(item as Map);
      // Ensure tags is a List<String>
      if (skill['tags'] != null) {
        skill['tags'] = List<String>.from(skill['tags'] as List);
      }
      return skill;
    }).toList();
  }

  /// Gets all unique categories from the skills data.
  static Future<List<String>> getCategories() async {
    final skills = await loadSkillsFromAsset();
    final categories = skills
        .map((skill) => skill['category'] as String)
        .toSet()
        .toList()
      ..sort();
    return categories;
  }

  /// Gets skills filtered by category.
  static Future<List<Map<String, dynamic>>> getSkillsByCategory(String category) async {
    final skills = await loadSkillsFromAsset();
    return skills
        .where((skill) => skill['category'] == category)
        .toList();
  }

  /// Searches skills by name or tags.
  static Future<List<Map<String, dynamic>>> searchSkills(String query) async {
    final skills = await loadSkillsFromAsset();
    final lowerQuery = query.toLowerCase();
    
    return skills.where((skill) {
      final name = (skill['name'] as String).toLowerCase();
      final tags = skill['tags'] as List<String>;
      
      return name.contains(lowerQuery) ||
          tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }
}
