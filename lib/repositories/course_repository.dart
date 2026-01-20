import '../models/course.dart';

abstract class CourseRepository {
  Future<void> saveCourse(Course course);
  
  Future<List<Course>> getAllCourses();
  
  Future<Course?> getCourseById(String id);
  
  Future<void> updateCourse(Course course);
  
  Future<void> deleteCourse(String id);
  
  Future<void> deleteAllCourses();
  
  Future<int> getCourseCount();
}
