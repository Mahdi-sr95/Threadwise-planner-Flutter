import 'course.dart';
import 'enums.dart';

class ParsedCourseDraft {
  final String name;
  final String deadline; // YYYY-MM-DD
  final Difficulty difficulty;
  final double studyHours;

  const ParsedCourseDraft({
    required this.name,
    required this.deadline,
    required this.difficulty,
    required this.studyHours,
  });

  DateTime get deadlineDate => DateTime.parse(deadline);

  Course toCourse() {
    return Course(
      name: name.trim(),
      deadline: deadlineDate,
      difficulty: difficulty,
      studyHours: studyHours,
    );
  }
}

class AiCourseParseResult {
  final InputStatus status;
  final String message;
  final List<ParsedCourseDraft> courses;

  /// For debugging (optional to show in UI if needed)
  final String rawModelOutput;

  const AiCourseParseResult({
    required this.status,
    required this.message,
    required this.courses,
    required this.rawModelOutput,
  });

  bool get canAddCourses => status == InputStatus.complete && courses.isNotEmpty;

  static AiCourseParseResult error(String msg, {String raw = ''}) {
    return AiCourseParseResult(
      status: InputStatus.incomplete,
      message: msg,
      courses: const [],
      rawModelOutput: raw,
    );
  }
}
