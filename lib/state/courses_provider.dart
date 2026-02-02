import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../repositories/shared_prefs_course_repository.dart';

/// Provider for managing courses with local persistence (SharedPreferences JSON).
class CoursesProvider extends ChangeNotifier {
  final SharedPrefsCourseRepository _repository = SharedPrefsCourseRepository();

  List<Course> _courses = <Course>[];
  bool _initialized = false;

  List<Course> get courses => List.unmodifiable(_courses);

  Future<void> init() async {
    if (_initialized) return;
    await _repository.init();
    await _loadCourses();
    _initialized = true;
  }

  Future<void> _loadCourses() async {
    _courses = await _repository.getAllCourses();
    notifyListeners();
  }

  Course? getById(String id) {
    try {
      return _courses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCourse(Course course) async {
    await _repository.saveCourse(course);
    await _loadCourses();
  }

  Future<void> updateCourse(Course course) async {
    await _repository.updateCourse(course); // saveCourse would also work
    await _loadCourses();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _courses.length) return;
    final courseId = _courses[index].id;
    await _repository.deleteCourse(courseId);
    await _loadCourses();
  }

  Future<void> deleteById(String id) async {
    await _repository.deleteCourse(id);
    await _loadCourses();
  }

  Future<void> clearAll() async {
    await _repository.deleteAllCourses();
    await _loadCourses();
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
