import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_course.dart';

//Local storage
class SavedCoursesStore {
  static const String _key = 'saved_courses_library';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _safePrefs {
    final p = _prefs;
    if (p == null)
      throw Exception('SavedCoursesStore not initialized. Call init() first.');
    return p;
  }

  Future<List<SavedCourse>> getAll() async {
    final raw = _safePrefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];

    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SavedCourse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsert(SavedCourse course) async {
    final all = await getAll();
    final idx = all.indexWhere((c) => c.id == course.id);

    if (idx >= 0) {
      final existing = all[idx];
      all[idx] = existing.copyWith(
        name: course.name,
        difficulty: course.difficulty,
        studyHours: course.studyHours,
        timesUsed: existing.timesUsed + 1,
        lastUsedAt: DateTime.now(),
        createdAt: existing.createdAt,
      );
    } else {
      all.add(course);
    }

    await _saveAll(all);
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((c) => c.id == id);
    await _saveAll(all);
  }

  Future<void> clear() async {
    await _safePrefs.remove(_key);
  }

  Future<void> _saveAll(List<SavedCourse> all) async {
    final raw = jsonEncode(all.map((c) => c.toJson()).toList());
    await _safePrefs.setString(_key, raw);
  }
}
