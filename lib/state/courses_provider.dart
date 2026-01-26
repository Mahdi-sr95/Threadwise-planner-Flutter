import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../utils/mock_data.dart';

class CoursesProvider extends ChangeNotifier {
  final List<Course> _courses = [];
  List<Course> get courses => List.unmodifiable(_courses);
  void seedFromMock() {
    if (_courses.isNotEmpty) return;
    _courses.addAll(MockData.mockCourses);
    notifyListeners();
  }

  void addCourses(Course course) {
    _courses.add(course);
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _courses.length) return;
    _courses.removeAt(index);
    notifyListeners();
  }
}
