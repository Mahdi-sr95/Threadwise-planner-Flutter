import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../repositories/shared_prefs_course_repository.dart';

/// Provider for managing courses state with local persistence
/// Handles CRUD operations and notifies listeners on changes
class CoursesProvider extends ChangeNotifier {
  final SharedPrefsCourseRepository _repository = SharedPrefsCourseRepository();
  List<Course> _courses = [];
  bool _initialized = false;

  List<Course> get courses => List.unmodifiable(_courses);

  /// Initialize repository and load courses from storage
  Future<void> init() async {
    if (_initialized) return;
    
    await _repository.init();
    await _loadCourses();
    _initialized = true;
  }

  /// Load all courses from repository
  Future<void> _loadCourses() async {
    _courses = await _repository.getAllCourses();
    notifyListeners();
  }

  /// Add a new course and persist to storage
  Future<void> addCourses(Course course) async {
    await _repository.saveCourse(course);
    await _loadCourses();
  }

  /// Remove course at index and update storage
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _courses.length) return;
    
    final courseId = _courses[index].id;
    await _repository.deleteCourse(courseId);
    await _loadCourses();
  }

  /// Delete all courses from storage
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
