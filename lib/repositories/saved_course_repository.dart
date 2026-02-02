import '../models/saved_course.dart';

abstract class SavedCourseRepository {
  Future<void> init();

  Future<List<SavedCourse>> getAll();
  Future<void> insertOrUpdate(SavedCourse course);
  Future<void> delete(String id);
  Future<void> clearAll();

  Future<void> close();
}
