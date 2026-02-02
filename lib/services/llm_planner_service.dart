import 'dart:convert';

import '../models/course.dart';
import '../models/enums.dart';
import '../models/plan_request.dart';
import '../models/plan_result.dart';
import '../models/study_task.dart';
import 'llm_client.dart';
import 'planning_service.dart';

/// LLM-based implementation of PlanningService.
/// This file also provides a deterministic local PlannerService used by the app.
class LLMPlannerService implements PlanningService {
  final LLMClient client;

  LLMPlannerService({required this.client});

  @override
  Future<PlanResult> generatePlan(PlanRequest request) async {
    try {
      final systemPrompt = _buildSystemPrompt(request.strategy);
      final userPrompt = _buildUserPrompt(request);

      final response = await client.sendPrompt(
        userPrompt,
        systemPrompt: systemPrompt,
        maxTokens: 2500,
      );

      return _parseResponse(response);
    } catch (e) {
      return PlanResult.error(
        'Failed to generate plan: ${e.toString()}',
        InputStatus.incomplete,
      );
    }
  }

  @override
  Future<InputStatus> validateInput(String input) async {
    if (input.trim().isEmpty) return InputStatus.incomplete;

    final prompt = '''
Analyze this text and determine if it contains course information:
"$input"

Respond with ONLY one word:
- "complete" if it has course names, deadlines, and difficulty
- "incomplete" if missing some information
- "unrelated" if not about courses
''';

    try {
      final response = await client.sendPrompt(prompt, maxTokens: 10);
      final status = response.toLowerCase().trim();

      if (status.contains('complete')) return InputStatus.complete;
      if (status.contains('incomplete')) return InputStatus.incomplete;
      return InputStatus.unrelated;
    } catch (_) {
      return InputStatus.incomplete;
    }
  }

  @override
  Future<bool> testConnection() => client.testConnection();

  String _buildSystemPrompt(Strategy strategy) {
    return '''
You are a study planner assistant. Generate a JSON study plan based on the strategy: ${strategy.name}.

Strategy descriptions:
- waterfall: Start with hardest courses first, then easier ones
- sandwich: Alternate between hard and easy topics
- sequential: Study in deadline order
- randomMix: Randomized order for variety

Output ONLY valid JSON in this format:
{
  "tasks": [
    {
      "subject": "Course Name",
      "task": "Task description",
      "dateTime": "2026-01-31T09:00:00.000",
      "durationHours": 2.5,
      "difficulty": "medium"
    }
  ]
}

Rules:
- Each task should be 1-4 hours
- Spread tasks across multiple days
- Consider course difficulty and deadline
- Use ISO 8601 format for dateTime
- difficulty must be: easy, medium, or hard
''';
  }

  String _buildUserPrompt(PlanRequest request) {
    return '''
User input: ${request.userInput}

Settings:
- Max hours per day: ${request.maxHoursPerDay}
- Break between sessions: ${request.breakMinutes} minutes
- Start date: ${request.startDate?.toIso8601String() ?? 'today'}

Generate the study plan following the ${request.strategy.name} strategy.
''';
  }

  PlanResult _parseResponse(String response) {
    try {
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd <= 0 || jsonEnd <= jsonStart) {
        throw Exception('No JSON found in response');
      }

      final jsonStr = response.substring(jsonStart, jsonEnd);
      final Map<String, dynamic> json =
          jsonDecode(jsonStr) as Map<String, dynamic>;

      if (!json.containsKey('tasks')) {
        throw Exception('Missing tasks field');
      }

      final List<dynamic> rawTasks = json['tasks'] as List<dynamic>;
      final tasks = rawTasks
          .map((t) => StudyTask.fromJson(t as Map<String, dynamic>))
          .toList();

      return PlanResult.success(tasks);
    } catch (e) {
      return PlanResult.error(
        'Failed to parse LLM response: ${e.toString()}',
        InputStatus.incomplete,
      );
    }
  }
}

class PlannerService {
  /// Max number of consecutive sessions allowed for the same course in Round-Robin mode.
  static const int _maxConsecutivePerCourse = 2;

  /// Default duration per session used by the local planner.
  static const double _hoursPerSession = 2.5;

  /// Gap between sessions (2.5h study + buffer).
  static const Duration _slotStep = Duration(hours: 4);

  /// Daily cutoff after which the next session moves to the next day at 09:00.
  static const int _dayCutoffHour = 18;

  /// Local plan generator.
  ///
  /// Key rule: no course can appear more than 2 consecutive time-slots unless it is
  /// the only remaining course with pending sessions.
  static List<StudyTask> generatePlan(
    List<Course> courses,
    Strategy strategy,
  ) {
    if (courses.isEmpty) return [];

    final ordered = _orderCoursesForStrategy(courses, strategy);
    final queue = List<_CourseWork>.from(
      ordered.map((c) => _CourseWork.fromCourse(c, _hoursPerSession)),
    );

    final now = DateTime.now();
    var currentDate = DateTime(now.year, now.month, now.day, 9, 0);

    final tasks = <StudyTask>[];

    String? lastCourseId;
    int consecutiveCount = 0;

    while (queue.any((w) => w.sessionsLeft > 0)) {
      final int idx = _pickNextIndex(
        queue,
        lastCourseId: lastCourseId,
        consecutiveCount: consecutiveCount,
        maxConsecutive: _maxConsecutivePerCourse,
      );

      final w = queue[idx];
      final duration = w.nextDuration();

      tasks.add(
        StudyTask(
          subject: w.course.name,
          task: 'Study session ${w.sessionNumber}/${w.totalSessions}',
          dateTime: currentDate,
          durationHours: duration,
          difficulty: w.course.difficulty,
        ),
      );

      w.consumeOne();

      if (lastCourseId == w.course.id) {
        consecutiveCount += 1;
      } else {
        lastCourseId = w.course.id;
        consecutiveCount = 1;
      }

      currentDate = currentDate.add(_slotStep);
      if (currentDate.hour >= _dayCutoffHour) {
        currentDate = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day + 1,
          9,
          0,
        );
      }
    }

    return tasks;
  }

  static int _pickNextIndex(
    List<_CourseWork> queue, {
    required String? lastCourseId,
    required int consecutiveCount,
    required int maxConsecutive,
  }) {
    final available = <int>[];
    for (int i = 0; i < queue.length; i++) {
      if (queue[i].sessionsLeft > 0) available.add(i);
    }

    if (available.isEmpty) return 0;

    final hasAlternative = available.any(
      (i) => queue[i].course.id != lastCourseId,
    );

    if (lastCourseId != null &&
        consecutiveCount >= maxConsecutive &&
        hasAlternative) {
      for (final i in available) {
        if (queue[i].course.id != lastCourseId) return i;
      }
    }

    return available.first;
  }

  static List<Course> _orderCoursesForStrategy(
    List<Course> courses,
    Strategy strategy,
  ) {
    final sorted = List<Course>.from(courses);

    switch (strategy) {
      case Strategy.waterfall:
        sorted.sort((a, b) {
          final diffCompare =
              b.difficulty.index.compareTo(a.difficulty.index);
          if (diffCompare != 0) return diffCompare;
          return a.deadline.compareTo(b.deadline);
        });
        break;

      case Strategy.sequential:
        sorted.sort((a, b) => a.deadline.compareTo(b.deadline));
        break;

      case Strategy.sandwich:
        sorted.sort((a, b) {
          final aDist = (a.difficulty.index - 1).abs();
          final bDist = (b.difficulty.index - 1).abs();
          final distCompare = bDist.compareTo(aDist);
          if (distCompare != 0) return distCompare;
          return a.deadline.compareTo(b.deadline);
        });
        break;

      case Strategy.randomMix:
        sorted.shuffle();
        break;
    }

    return sorted;
  }
}

class _CourseWork {
  final Course course;
  final double hoursPerSession;

  final int totalSessions;
  int sessionsLeft;

  final double remainingHoursForLastSession;

  int sessionNumber = 1;

  _CourseWork({
    required this.course,
    required this.hoursPerSession,
    required this.totalSessions,
    required this.sessionsLeft,
    required this.remainingHoursForLastSession,
  });

  factory _CourseWork.fromCourse(Course course, double hoursPerSession) {
    final total = (course.studyHours / hoursPerSession).ceil();
    final remainder = course.studyHours - (hoursPerSession * (total - 1));
    final lastDuration = remainder <= 0 ? hoursPerSession : remainder;

    return _CourseWork(
      course: course,
      hoursPerSession: hoursPerSession,
      totalSessions: total,
      sessionsLeft: total,
      remainingHoursForLastSession: lastDuration,
    );
  }

  double nextDuration() {
    if (sessionsLeft <= 1) return remainingHoursForLastSession;
    return hoursPerSession;
  }

  void consumeOne() {
    if (sessionsLeft <= 0) return;
    sessionsLeft -= 1;
    sessionNumber = (totalSessions - sessionsLeft) + 1;
  }
}
