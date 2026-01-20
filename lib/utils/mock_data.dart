import '../models/course.dart';
import '../models/study_task.dart';
import '../models/enums.dart';

class MockData {
  static final List<Course> mockCourses = [
    Course(
      name: 'Mobile Application Development',
      deadline: DateTime(2026, 2, 15),
      difficulty: Difficulty.hard,
    ),
    Course(
      name: 'Database Systems',
      deadline: DateTime(2026, 2, 20),
      difficulty: Difficulty.medium,
    ),
    Course(
      name: 'Software Engineering',
      deadline: DateTime(2026, 2, 18),
      difficulty: Difficulty.medium,
    ),
    Course(
      name: 'Computer Networks',
      deadline: DateTime(2026, 2, 22),
      difficulty: Difficulty.easy,
    ),
  ];

  static final List<StudyTask> mockPlan = [
    StudyTask(
      subject: 'Mobile Application Development',
      task: 'Flutter basics and widgets',
      dateTime: DateTime(2026, 1, 21, 9, 0),
      durationHours: 2.5,
      difficulty: Difficulty.hard,
    ),
    StudyTask(
      subject: 'Database Systems',
      task: 'SQL queries and normalization',
      dateTime: DateTime(2026, 1, 21, 14, 0),
      durationHours: 2.0,
      difficulty: Difficulty.medium,
    ),
    StudyTask(
      subject: 'Mobile Application Development',
      task: 'State management with Provider',
      dateTime: DateTime(2026, 1, 22, 9, 0),
      durationHours: 3.0,
      difficulty: Difficulty.hard,
    ),
    StudyTask(
      subject: 'Software Engineering',
      task: 'Design patterns review',
      dateTime: DateTime(2026, 1, 22, 14, 30),
      durationHours: 1.5,
      difficulty: Difficulty.medium,
    ),
    StudyTask(
      subject: 'Computer Networks',
      task: 'OSI model and protocols',
      dateTime: DateTime(2026, 1, 23, 10, 0),
      durationHours: 1.5,
      difficulty: Difficulty.easy,
    ),
  ];
}
