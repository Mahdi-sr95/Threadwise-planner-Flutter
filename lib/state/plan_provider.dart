import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/study_task.dart';
import '../models/enums.dart';
import '../services/llm_client.dart';
import '../config/secrets.dart';
import 'settings_provider.dart';

/// Provider for managing study plan generation and state
/// Handles strategy selection, task generation with Round-Robin scheduling
class PlanProvider extends ChangeNotifier {
  Strategy _strategy = Strategy.waterfall;
  List<StudyTask> _tasks = [];
  bool _loading = false;
  String? _error;
  late final LLMClient _llmClient;

  PlanProvider() {
    _llmClient = LLMClient(apiToken: Secrets.huggingFaceToken);
  }

  Strategy get strategy => _strategy;
  List<StudyTask> get tasks => _tasks;
  bool get loading => _loading;
  String? get error => _error;

  /// Update the selected planning strategy
  void setStrategy(Strategy newStrategy) {
    _strategy = newStrategy;
    notifyListeners();
  }

  /// Generate study plan based on courses and user settings
  /// Uses Round-Robin algorithm to distribute study sessions
  Future<void> generatePlan(
    List<Course> courses,
    AppSettings settings,
  ) async {
    if (courses.isEmpty) {
      _error = 'No courses available';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _tasks = await _generateTasksLocally(courses, settings);
      _error = null;
    } catch (e) {
      _error = 'Failed to generate plan: $e';
      _tasks = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Generate tasks using Round-Robin scheduling algorithm
  /// Each session is 2 hours max, with breaks between sessions
  Future<List<StudyTask>> _generateTasksLocally(
    List<Course> courses,
    AppSettings settings,
  ) async {
    // Each study session is 2 hours
    const double sessionDurationHours = 2.0;
    
    // Sort courses based on selected strategy
    final sortedCourses = _sortCoursesByStrategy(courses);

    // Calculate how many 2-hour sessions each course needs
    final courseSessionInfo = sortedCourses.map((course) {
      final totalSessions = (course.studyHours / sessionDurationHours).ceil();
      return {
        'course': course,
        'totalSessions': totalSessions,
        'completedSessions': 0,
        'remainingHours': course.studyHours,
      };
    }).toList();

    final tasks = <StudyTask>[];
    final now = DateTime.now();
    DateTime currentTime = DateTime(now.year, now.month, now.day, 9, 0);
    double dailyHours = 0.0;

    // Round-Robin: cycle through courses until all are complete
    bool anyIncomplete = true;
    while (anyIncomplete) {
      anyIncomplete = false;

      for (final info in courseSessionInfo) {
        final course = info['course'] as Course;
        final totalSessions = info['totalSessions'] as int;
        var completedSessions = info['completedSessions'] as int;
        var remainingHours = info['remainingHours'] as double;

        // Skip if this course is finished
        if (completedSessions >= totalSessions) continue;

        anyIncomplete = true;

        // For Waterfall and Sandwich: max 2 consecutive sessions per course
        // For Sequential: complete entire course before moving to next
        // For Random Mix: no limit (random distribution)
        int sessionsToScheduleNow = 1;
        
        if (_strategy == Strategy.waterfall || _strategy == Strategy.sandwich) {
          // Schedule up to 2 consecutive sessions
          sessionsToScheduleNow = (totalSessions - completedSessions).clamp(1, 2);
        } else if (_strategy == Strategy.sequential) {
          // Schedule all remaining sessions for this course
          sessionsToScheduleNow = totalSessions - completedSessions;
        } else if (_strategy == Strategy.randomMix) {
          // Random: can be 1 or 2 sessions
          sessionsToScheduleNow = (totalSessions - completedSessions).clamp(1, 2);
        }

        // Schedule the determined number of sessions
        for (int i = 0; i < sessionsToScheduleNow; i++) {
          if (completedSessions >= totalSessions) break;

          // Check if we exceeded daily limit
          if (dailyHours + sessionDurationHours > settings.maxHoursPerDay) {
            // Move to next day
            currentTime = _getNextDayStart(currentTime);
            currentTime = _skipWeekendsIfNeeded(currentTime, settings);
            dailyHours = 0.0;
          }

          // Calculate actual duration for this session
          final actualDuration = remainingHours >= sessionDurationHours
              ? sessionDurationHours
              : remainingHours;

          // Create study task
          tasks.add(StudyTask(
            subject: course.name,
            task: 'Study ${course.name} - Session ${completedSessions + 1}',
            dateTime: currentTime,
            durationHours: actualDuration,
            difficulty: course.difficulty,
          ));

          // Update tracking variables
          completedSessions++;
          remainingHours -= actualDuration;
          dailyHours += actualDuration;

          // Move time forward by session duration plus break
          currentTime = currentTime.add(Duration(
            hours: actualDuration.floor(),
            minutes: ((actualDuration - actualDuration.floor()) * 60).round() +
                settings.breakMinutes,
          ));
        }

        // Update the info map with new values
        info['completedSessions'] = completedSessions;
        info['remainingHours'] = remainingHours;

        // For Sequential strategy, don't break the loop - continue with same course
        if (_strategy == Strategy.sequential) {
          // Already scheduled all sessions for this course above
          continue;
        }
      }
    }

    return tasks;
  }

  /// Sort courses according to selected strategy
  List<Course> _sortCoursesByStrategy(List<Course> courses) {
    final sorted = List<Course>.from(courses);

    switch (_strategy) {
      case Strategy.waterfall:
        // Hardest courses first
        sorted.sort((a, b) {
          final diffCompare = b.difficulty.index.compareTo(a.difficulty.index);
          if (diffCompare != 0) return diffCompare;
          return a.deadline.compareTo(b.deadline);
        });
        break;

      case Strategy.sandwich:
        // Alternate between hard and easy
        sorted.sort((a, b) => b.difficulty.index.compareTo(a.difficulty.index));
        final result = <Course>[];
        int left = 0;
        int right = sorted.length - 1;
        while (left <= right) {
          if (left <= right) result.add(sorted[left++]);
          if (left <= right) result.add(sorted[right--]);
        }
        return result;

      case Strategy.sequential:
        // By deadline (earliest first)
        sorted.sort((a, b) => a.deadline.compareTo(b.deadline));
        break;

      case Strategy.randomMix:
        // Random order for variety
        sorted.shuffle();
        break;
    }

    return sorted;
  }

  /// Skip weekends if setting is disabled
  DateTime _skipWeekendsIfNeeded(DateTime date, AppSettings settings) {
    if (settings.includeWeekends) return date;

    var result = date;
    while (result.weekday == DateTime.saturday ||
        result.weekday == DateTime.sunday) {
      result = result.add(const Duration(days: 1));
      result = DateTime(result.year, result.month, result.day, 9, 0);
    }
    return result;
  }

  /// Get next day start time at 9 AM
  DateTime _getNextDayStart(DateTime current) {
    final nextDay = DateTime(
      current.year,
      current.month,
      current.day + 1,
      9,
      0,
    );
    return nextDay;
  }

  /// Clear all tasks and reset state
  void clearPlan() {
    _tasks = [];
    _error = null;
    notifyListeners();
  }
}
