import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../models/saved_course.dart';
import '../data/saved_courses_store.dart';

class SavedCoursesProvider extends ChangeNotifier {
  final SavedCoursesStore _store = SavedCoursesStore();

  List<SavedCourse> _saved = <SavedCourse>[];
  bool _initialized = false;

  List<SavedCourse> get saved => List.unmodifiable(_saved);

  Future<void> init() async {
    if (_initialized) return;
    await _store.init();
    await reload();
    _initialized = true;
  }

  Future<void> reload() async {
    _saved = await _store.getAll();
    _saved.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    notifyListeners();
  }

  /// Option A rule: library grows ONLY when user saves a plan.
  Future<void> ingestFromSavedPlan(List<Course> activeCoursesUsedInPlan) async {
    for (final c in activeCoursesUsedInPlan) {
      await _store.upsert(
        SavedCourse(
          name: c.name,
          difficulty: c.difficulty,
          studyHours: c.studyHours,
        ),
      );
    }
    await reload();
  }

  Future<void> deleteSavedCourse(String id) async {
    await _store.delete(id);
    await reload();
  }

  Future<void> clearLibrary() async {
    await _store.clear();
    await reload();
  }
}
