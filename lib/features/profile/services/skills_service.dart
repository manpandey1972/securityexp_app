import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:greenhive_app/data/models/skill.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';

class SkillsService {
  static const String _skillsCacheKey = 'cached_skills';
  static const String _skillsCacheVersionKey = 'skills_cache_version';
  final FirebaseFirestore _firestore = FirestoreInstance().db;
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'SkillsService';

  // Fetch skills from Firestore and cache locally
  Future<List<Skill>> getAllSkills() async {
    return await ErrorHandler.handle<List<Skill>>(
      operation: () async {
        // Try to load from local cache first
        final cached = await _getFromCache();
        if (cached.isNotEmpty) {
          _log.info('Loaded ${cached.length} skills from cache', tag: _tag);
          return cached;
            }

            // If not cached, fetch from Firestore
            _log.debug('Fetching skills from Firestore...', tag: _tag);
            final snapshot = await _firestore
                .collection('skills')
                .orderBy('category')
                .orderBy('name')
                .get();

            final skills = snapshot.docs
                .map((doc) => Skill.fromFirestore(doc))
                .toList();

            // Cache locally
            await _saveToCache(skills);
            _log.info('Cached ${skills.length} skills locally', tag: _tag);
            return skills;
          },
          fallback: <Skill>[],
          onError: (error) =>
              _log.error('Error fetching skills: $error', tag: _tag),
        );
  }

  // Cache skills locally
  Future<void> _saveToCache(List<Skill> skills) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = skills
            .map(
              (s) => jsonEncode({
                'id': s.id,
                'name': s.name,
                'category': s.category,
                'tags': s.tags,
              }),
            )
            .toList();
        await prefs.setStringList(_skillsCacheKey, jsonList);
        // Store cache version for future cache invalidation
        await prefs.setInt(
          _skillsCacheVersionKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      },
    );
  }

  // Retrieve from cache
  Future<List<Skill>> _getFromCache() async {
    return await ErrorHandler.handle<List<Skill>>(
      operation: () async {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList(_skillsCacheKey) ?? [];

        if (cached.isEmpty) {
          return [];
        }

            return cached.map((json) {
              final data = jsonDecode(json);
              return Skill(
                id: data['id'],
                name: data['name'],
                category: data['category'],
                tags: List<String>.from(data['tags']),
              );
            }).toList();
          },
          fallback: <Skill>[],
        );
  }

  // Clear cache
  Future<void> clearCache() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_skillsCacheKey);
        await prefs.remove(_skillsCacheVersionKey);
        _log.info('Skills cache cleared', tag: _tag);
      },
    );
  }

  // Search skills
  List<Skill> searchSkills(String query, List<Skill> allSkills) {
    if (query.isEmpty) return allSkills;

    final q = query.toLowerCase().trim();
    return allSkills.where((skill) {
      return skill.name.toLowerCase().contains(q) ||
          skill.category.toLowerCase().contains(q) ||
          skill.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();
  }

  // Group skills by category
  Map<String, List<Skill>> groupByCategory(List<Skill> skills) {
    final grouped = <String, List<Skill>>{};
    for (var skill in skills) {
      grouped.putIfAbsent(skill.category, () => []).add(skill);
    }
    // Sort categories alphabetically
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (var key in sortedKeys) key: grouped[key]!};
  }

  // Get selected skill details
  Future<List<Skill>> getSelectedSkills(List<String> skillIds) async {
    return await ErrorHandler.handle<List<Skill>>(
      operation: () async {
        if (skillIds.isEmpty) return [];

        final allSkills = await getAllSkills();
        return allSkills
            .where((skill) => skillIds.contains(skill.id))
            .toList();
      },
          fallback: <Skill>[],
          onError: (error) =>
              _log.error('Error fetching selected skills: $error', tag: _tag),
        );
  }
}
