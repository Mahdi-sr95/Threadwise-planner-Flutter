import 'course.dart';
import 'enums.dart';

/// A single extracted course draft produced by the AI.
/// `deadline` must be an ISO date string: YYYY-MM-DD.
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

  /// Parses YYYY-MM-DD as a local date (midnight) to avoid timezone shifts.
  /// Also tolerates YYYY-M-D by using int parsing.
  DateTime get deadlineDate {
    final parts = deadline.trim().split('-');
    if (parts.length != 3) {
      throw FormatException(
        'Invalid deadline (expected YYYY-MM-DD).',
        deadline,
      );
    }

    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);

    if (y == null || m == null || d == null) {
      throw FormatException(
        'Invalid deadline (expected YYYY-MM-DD).',
        deadline,
      );
    }

    return DateTime(y, m, d);
  }

  Course toCourse() {
    final d = deadlineDate;
    return Course(
      name: name.trim(),
      deadline: DateTime(d.year, d.month, d.day),
      difficulty: difficulty,
      studyHours: studyHours,
    );
  }
}

/// The full AI parsing/validation result shown in the UI.
class AiCourseParseResult {
  final InputStatus status;
  final String message;
  final List<ParsedCourseDraft> courses;

  /// For debugging (optional to show in UI if needed).
  final String rawModelOutput;

  const AiCourseParseResult({
    required this.status,
    required this.message,
    required this.courses,
    required this.rawModelOutput,
  });

  bool get canAddCourses =>
      status == InputStatus.complete && courses.isNotEmpty;

  static AiCourseParseResult error(String msg, {String raw = ''}) {
    return AiCourseParseResult(
      status: InputStatus.incomplete,
      message: msg,
      courses: const [],
      rawModelOutput: raw,
    );
  }
}
