import 'package:flutter/foundation.dart';
import '../models/study_task.dart';
import '../models/course.dart';
import 'settings_provider.dart';

enum Strategy { waterfall, sandwich, sequential, randomMix }

extension StrategyLabel on Strategy {
  String get label => switch (this) {
        Strategy.waterfall => 'Waterfall',
        Strategy.sandwich => 'Sandwich',
        Strategy.sequential => 'Sequential',
        Strategy.randomMix => 'Random Mix',
      };
}

class PlanProvider extends ChangeNotifier {
  Strategy _strategy = Strategy.waterfall;
  List<StudyTask> _tasks = [];
  List<Course> _lastCourses = [];
  AppSettings? _lastSettings;
  bool _loading = false;
  String? _error;

  Strategy get strategy => _strategy;
  List<StudyTask> get tasks => List.unmodifiable(_tasks);
  bool get loading => _loading;
  String? get error => _error;

  /// Change strategy and regenerate plan if courses exist
  void setStrategy(Strategy s) {
    if (_strategy == s) return;
    _strategy = s;
    notifyListeners();

    // Auto-regenerate plan if we already have courses
    if (_lastCourses.isNotEmpty && _lastSettings != null) {
      generatePlan(_lastCourses, _lastSettings!);
    }
  }

  /// Generate study plan from actual courses using settings
  Future<void> generatePlan(List<Course> courses, AppSettings settings) async {
    _loading = true;
    _error = null;
    _lastCourses = List.from(courses);
    _lastSettings = settings;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (courses.isEmpty) {
        _tasks = [];
        return;
      }

      // Generate tasks based on strategy
      _tasks = _generateTasksByStrategy(courses, settings);
    } catch (e) {
      _error = 'Failed to generate plan: $e';
      _tasks = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Generate tasks using the selected strategy
  List<StudyTask> _generateTasksByStrategy(
    List<Course> courses,
    AppSettings settings,
  ) {
    switch (_strategy) {
      case Strategy.waterfall:
        return _generateWaterfall(courses, settings);
      case Strategy.sandwich:
        return _generateSandwich(courses, settings);
      case Strategy.sequential:
        return _generateSequential(courses, settings);
      case Strategy.randomMix:
        return _generateRandomMix(courses, settings);
    }
  }

  /// Waterfall: Round-robin with hardest courses first
  /// Max 2 consecutive sessions per course before rotating
  List<StudyTask> _generateWaterfall(
    List<Course> courses,
    AppSettings settings,
  ) {
    // Sort by difficulty (hardest first), then by deadline
    final sorted = List<Course>.from(courses);
    sorted.sort((a, b) {
      final diffCompare = b.difficulty.index.compareTo(a.difficulty.index);
      if (diffCompare != 0) return diffCompare;
      return a.deadline.compareTo(b.deadline);
    });

    return _generateRoundRobin(sorted, settings, maxConsecutive: 2);
  }

  /// Sandwich: Round-robin alternating between hard and easy
  /// Max 2 consecutive sessions per course
  List<StudyTask> _generateSandwich(
    List<Course> courses,
    AppSettings settings,
  ) {
    // Sort by difficulty
    final sorted = List<Course>.from(courses);
    sorted.sort((a, b) => b.difficulty.index.compareTo(a.difficulty.index));

    // Interleave hard and easy courses
    final List<Course> sandwiched = [];
    int left = 0; // Hard courses
    int right = sorted.length - 1; // Easy courses

    while (left <= right) {
      if (left == right) {
        sandwiched.add(sorted[left]);
      } else {
        sandwiched.add(sorted[left]); // Add hard
        sandwiched.add(sorted[right]); // Add easy
      }
      left++;
      right--;
    }

    return _generateRoundRobin(sandwiched, settings, maxConsecutive: 2);
  }

  /// Sequential: Complete all tasks for one course before moving to next
  List<StudyTask> _generateSequential(
    List<Course> courses,
    AppSettings settings,
  ) {
    // Sort courses by deadline (earliest first)
    final sorted = List<Course>.from(courses);
    sorted.sort((a, b) => a.deadline.compareTo(b.deadline));

    final tasks = <StudyTask>[];
    final now = DateTime.now();
    var currentTime = DateTime(now.year, now.month, now.day, 9, 0);

    // Process each course completely before moving to next
    for (final course in sorted) {
      final courseTasks = _generateAllTasksForCourse(
        course,
        currentTime,
        settings,
      );
      tasks.addAll(courseTasks);

      // Update time to continue after last task + break
      if (courseTasks.isNotEmpty) {
        final lastTask = courseTasks.last;
        currentTime = lastTask.dateTime.add(
          Duration(
            hours: lastTask.durationHours.floor(),
            minutes: ((lastTask.durationHours % 1) * 60).round() +
                settings.breakMinutes,
          ),
        );
      }
    }

    return tasks;
  }

  /// Random Mix: Shuffle courses randomly and use round-robin
  List<StudyTask> _generateRandomMix(
    List<Course> courses,
    AppSettings settings,
  ) {
    final shuffled = List<Course>.from(courses);
    shuffled.shuffle();
    // Random mix doesn't enforce max consecutive (can be random)
    return _generateRoundRobin(shuffled, settings, maxConsecutive: null);
  }

  /// Round-robin scheduling with max consecutive sessions per course
  /// This ensures variety and prevents studying one subject too long
  List<StudyTask> _generateRoundRobin(
    List<Course> orderedCourses,
    AppSettings settings, {
    int? maxConsecutive, // null means no limit (for random)
  }) {
    // Calculate total sessions needed for each course
    const sessionDuration = 2.5; // hours
    final courseData = orderedCourses.map((course) {
      final totalSessions = (course.studyHours / sessionDuration).ceil();
      return {
        'course': course,
        'totalSessions': totalSessions,
        'completedSessions': 0,
      };
    }).toList();

    final tasks = <StudyTask>[];
    final now = DateTime.now();
    var currentTime = DateTime(now.year, now.month, now.day, 9, 0);
    var dailyHours = 0.0;

    // Round-robin through courses
    while (courseData.any((c) => 
        (c['completedSessions'] as int) < (c['totalSessions'] as int))) {
      for (final data in courseData) {
        final course = data['course'] as Course;
        final totalSessions = data['totalSessions'] as int;
        var completedSessions = data['completedSessions'] as int;

        // Skip if course is already done
        if (completedSessions >= totalSessions) continue;

        // Schedule up to maxConsecutive sessions for this course
        final sessionsToSchedule = maxConsecutive != null
            ? (totalSessions - completedSessions).clamp(0, maxConsecutive)
            : (totalSessions - completedSessions);

        for (int i = 0; i < sessionsToSchedule; i++) {
          // Check daily limit
          if (dailyHours + sessionDuration > settings.maxHoursPerDay) {
            // Move to next day
            currentTime = _getNextDayStart(currentTime, settings);
            dailyHours = 0.0;
          }

          // Skip weekends if needed
          currentTime = _skipWeekendsIfNeeded(currentTime, settings);

          // Create task
          final actualDuration = sessionDuration.clamp(
            0.0,
            course.studyHours - (completedSessions * sessionDuration),
          );

          tasks.add(
            StudyTask(
              subject: course.name,
              task: 'Study session ${completedSessions + 1} of $totalSessions',
              dateTime: currentTime,
              durationHours: actualDuration,
              difficulty: course.difficulty,
            ),
          );

          completedSessions++;
          dailyHours += actualDuration;

          // Move time forward by session duration + break
          currentTime = currentTime.add(
            Duration(
              hours: actualDuration.floor(),
              minutes: ((actualDuration % 1) * 60).round() +
                  settings.breakMinutes,
            ),
          );
        }

        // Update completed count
        data['completedSessions'] = completedSessions;
      }
    }

    return tasks;
  }

  /// Generate all tasks for a single course (used in Sequential only)
  List<StudyTask> _generateAllTasksForCourse(
    Course course,
    DateTime startTime,
    AppSettings settings,
  ) {
    final tasks = <StudyTask>[];
    var currentTime = startTime;
    var dailyHours = 0.0;

    const sessionDuration = 2.5;
    final numberOfSessions = (course.studyHours / sessionDuration).ceil();
    final actualSessionDuration = course.studyHours / numberOfSessions;

    for (int i = 0; i < numberOfSessions; i++) {
      // Check daily limit
      if (dailyHours + actualSessionDuration > settings.maxHoursPerDay) {
        currentTime = _getNextDayStart(currentTime, settings);
        dailyHours = 0.0;
      }

      // Skip weekends if needed
      currentTime = _skipWeekendsIfNeeded(currentTime, settings);

      tasks.add(
        StudyTask(
          subject: course.name,
          task: 'Study session ${i + 1} of $numberOfSessions',
          dateTime: currentTime,
          durationHours: actualSessionDuration,
          difficulty: course.difficulty,
        ),
      );

      dailyHours += actualSessionDuration;

      // Move time forward
      currentTime = currentTime.add(
        Duration(
          hours: actualSessionDuration.floor(),
          minutes: ((actualSessionDuration % 1) * 60).round() +
              settings.breakMinutes,
        ),
      );
    }

    return tasks;
  }

  /// Skip weekends if includeWeekends is false
  DateTime _skipWeekendsIfNeeded(DateTime date, AppSettings settings) {
    if (settings.includeWeekends) return date;

    var result = date;
    while (result.weekday > 5) {
      // Saturday=6, Sunday=7
      result = result.add(const Duration(days: 1));
      result = DateTime(result.year, result.month, result.day, 9, 0);
    }
    return result;
  }

  /// Get next day start time (9 AM)
  DateTime _getNextDayStart(DateTime current, AppSettings settings) {
    var nextDay = DateTime(
      current.year,
      current.month,
      current.day + 1,
      9,
      0,
    );
    return _skipWeekendsIfNeeded(nextDay, settings);
  }

  void clear() {
    _tasks = [];
    _lastCourses = [];
    _lastSettings = null;
    _error = null;
    notifyListeners();
  }
}
