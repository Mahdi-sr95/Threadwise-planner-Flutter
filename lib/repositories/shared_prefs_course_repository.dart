import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import 'course_repository.dart';

/// SharedPreferences implementation for Course storage
/// Uses JSON serialization for simple local data persistence
class SharedPrefsCourseRepository implements CourseRepository {
  static const String _key = 'courses';
  SharedPreferences? _prefs;

  /// Initialize SharedPreferences instance
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _safePrefs {
    if (_prefs == null) {
      throw Exception('Repository not initialized. Call init() first.');
    }
    return _prefs!;
  }

  @override
  Future<void> saveCourse(Course course) async {
    final courses = await getAllCourses();
    final index = courses.indexWhere((c) => c.id == course.id);
    
    if (index >= 0) {
      courses[index] = course;
    } else {
      courses.add(course);
    }
    
    await _saveCourses(courses);
  }

  @override
  Future<List<Course>> getAllCourses() async {
    final jsonString = _safePrefs.getString(_key);
    if (jsonString == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((json) => Course.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Course?> getCourseById(String id) async {
    final courses = await getAllCourses();
    try {
      return courses.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateCourse(Course course) async {
    await saveCourse(course);
  }

  @override
  Future<void> deleteCourse(String id) async {
    final courses = await getAllCourses();
    courses.removeWhere((c) => c.id == id);
    await _saveCourses(courses);
  }

  @override
  Future<void> deleteAllCourses() async {
    await _safePrefs.remove(_key);
  }

  @override
  Future<int> getCourseCount() async {
    final courses = await getAllCourses();
    return courses.length;
  }

  /// Save courses list to SharedPreferences
  Future<void> _saveCourses(List<Course> courses) async {
    final jsonList = courses.map((c) => c.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _safePrefs.setString(_key, jsonString);
  }

  /// Close repository (no-op for SharedPreferences)
  Future<void> close() async {
    // SharedPreferences doesn't need explicit closing
  }
}
