import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';

class CoursesProvider extends ChangeNotifier {
  static const _key = 'courses_by_semester';

  SharedPreferences? _prefs;

  // semesterId -> list of courses
  final Map<String, List<Course>> _bySemester = {};

  String? _selectedSemesterId;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _load();
  }

  void setSelectedSemester(String semesterId) {
    _selectedSemesterId = semesterId;
    notifyListeners();
  }

  String? get selectedSemesterId => _selectedSemesterId;

  /// ✅ current semester courses (what your UI expects)
  List<Course> get courses => coursesForSelectedSemester;

  List<Course> get coursesForSelectedSemester {
    final id = _selectedSemesterId;
    if (id == null) return const [];
    return List.unmodifiable(_bySemester[id] ?? const []);
  }

  Course? getById(String id) {
    for (final entry in _bySemester.entries) {
      final idx = entry.value.indexWhere((c) => c.id == id);
      if (idx != -1) return entry.value[idx];
    }
    return null;
  }

  List<Course> findByName(String name) {
    final wanted = name.trim().toLowerCase();
    final out = <Course>[];
    for (final entry in _bySemester.entries) {
      out.addAll(
        entry.value.where((c) => c.name.trim().toLowerCase() == wanted),
      );
    }
    return out;
  }

  Future<void> addCourse(Course course, {required String semesterId}) async {
    final list = _bySemester.putIfAbsent(semesterId, () => <Course>[]);
    list.add(course);
    await _save();
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    final id = _selectedSemesterId;
    if (id == null) return;
    final list = _bySemester[id];
    if (list == null || index < 0 || index >= list.length) return;

    list.removeAt(index);
    await _save();
    notifyListeners();
  }

  Future<void> updateCourse(Course updated) async {
    for (final entry in _bySemester.entries) {
      final idx = entry.value.indexWhere((c) => c.id == updated.id);
      if (idx != -1) {
        entry.value[idx] = updated;
        await _save();
        notifyListeners();
        return;
      }
    }
  }

  Future<void> _load() async {
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _bySemester.clear();

    for (final e in decoded.entries) {
      final listJson = (e.value as List).cast<Map<String, dynamic>>();
      _bySemester[e.key] = listJson.map(Course.fromJson).toList();
    }
  }

  Future<void> _save() async {
    final out = <String, dynamic>{};
    for (final e in _bySemester.entries) {
      out[e.key] = e.value.map((c) => c.toJson()).toList();
    }
    await _prefs?.setString(_key, jsonEncode(out));
  }
}
