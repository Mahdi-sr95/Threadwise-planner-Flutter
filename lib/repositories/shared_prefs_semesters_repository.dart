import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/semester.dart';
import 'semesters_repository.dart';

class SharedPrefsSemestersRepository implements SemestersRepository {
  static const _keySemesters = 'semesters';
  static const _keySelected = 'selected_semester_id';

  SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _safePrefs {
    final p = _prefs;
    if (p == null) {
      throw Exception(
        'SemestersRepository not initialized. Call init() first.',
      );
    }
    return p;
  }

  @override
  Future<List<Semester>> getAll() async {
    final s = _safePrefs.getString(_keySemesters);
    if (s == null) return [];
    final list = (jsonDecode(s) as List).cast<dynamic>();
    return list
        .map((e) => Semester.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> _saveAll(List<Semester> semesters) async {
    final jsonList = semesters.map((s) => s.toJson()).toList();
    await _safePrefs.setString(_keySemesters, jsonEncode(jsonList));
  }

  @override
  Future<void> save(Semester semester) async {
    final all = await getAll();
    final idx = all.indexWhere((s) => s.id == semester.id);
    if (idx >= 0) {
      all[idx] = semester;
    } else {
      all.add(semester);
    }
    await _saveAll(all);
  }

  @override
  Future<void> deleteById(String id) async {
    final all = await getAll();
    all.removeWhere((s) => s.id == id);
    await _saveAll(all);
  }

  @override
  Future<void> deleteAll() async {
    await _safePrefs.remove(_keySemesters);
    await _safePrefs.remove(_keySelected);
  }

  @override
  Future<String?> getSelectedSemesterId() async {
    return _safePrefs.getString(_keySelected);
  }

  @override
  Future<void> setSelectedSemesterId(String id) async {
    await _safePrefs.setString(_keySelected, id);
  }
}
