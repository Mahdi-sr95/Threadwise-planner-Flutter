import '../models/semester.dart';

abstract class SemestersRepository {
  Future<void> init();

  Future<List<Semester>> getAll();
  Future<void> save(Semester semester);
  Future<void> deleteById(String id);
  Future<void> deleteAll();

  Future<String?> getSelectedSemesterId();
  Future<void> setSelectedSemesterId(String id);
}
