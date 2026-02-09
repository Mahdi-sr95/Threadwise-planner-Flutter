import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/enums.dart';
import '../models/saved_plan.dart';
import '../models/study_task.dart';
import '../services/llm_planner_service.dart';
import '../services/notifications_service.dart';

/// Provider responsible for plan generation and persisted plan history.
class PlanProvider extends ChangeNotifier {
  static const String _historyKey = 'plan_history';

  Strategy _strategy = Strategy.waterfall;
  final List<StudyTask> _tasks = <StudyTask>[];
  List<SavedPlan> _planHistory = <SavedPlan>[];

  bool _loading = false;
  String? _error;

  SharedPreferences? _prefs;

  DateTime _selectedDay = DateTime.now();

  Strategy get strategy => _strategy;
  List<StudyTask> get tasks => List.unmodifiable(_tasks);
  List<SavedPlan> get planHistory => List.unmodifiable(_planHistory);
  bool get loading => _loading;
  String? get error => _error;

  DateTime get selectedDay =>
      DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

  PlanProvider() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadHistory();
  }

  /// Updates the selected strategy.
  void setStrategy(Strategy newStrategy) {
    if (_strategy == newStrategy) return;
    _strategy = newStrategy;
    notifyListeners();
  }

  void setSelectedDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (_selectedDay.year == d.year &&
        _selectedDay.month == d.month &&
        _selectedDay.day == d.day) {
      return;
    }
    _selectedDay = d;
    notifyListeners();
  }

  /// Generates a new plan based on the current strategy.
  /// The optional settings argument is kept for compatibility with existing callers.
  Future<void> generatePlan(List<Course> courses, [dynamic settings]) async {
    if (courses.isEmpty) {
      _error = 'No courses available';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final generated = PlannerService.generatePlan(courses, _strategy);
      _tasks
        ..clear()
        ..addAll(generated);

      // Keep selected day sensible
      if (_tasks.isNotEmpty) {
        final days = _tasks
            .map((t) => DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day))
            .toList()
          ..sort();
        _selectedDay = days.first;
      }

      // Schedule notifications - never let this crash plan generation
      await _tryScheduleNotifications();
    } catch (e) {
      _tasks.clear();
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _tryScheduleNotifications() async {
    // If no tasks, clear notifications and return
    if (_tasks.isEmpty) {
      try {
        await NotificationsService.instance.cancelAll();
      } catch (_) {}
      return;
    }

    try {
      final granted =
          await NotificationsService.instance.requestPermissionsIfNeeded();

      // Even if permission is not granted (e.g., iOS user denied),
      // do not treat it as a fatal error.
      if (!granted) return;

      await NotificationsService.instance.rescheduleAll(
        tasks: _tasks,
        taskKeyOf: (t) => t.key,
        notifyBefore: Duration.zero, // change to e.g. Duration(minutes: 5)
      );
    } catch (e) {
      // Do not crash; just log
      debugPrint('Notifications scheduling failed: $e');
    }
  }

  /// Saves the currently generated plan into history.
  Future<void> saveCurrentPlan({String? notes}) async {
    if (_tasks.isEmpty) return;

    final plan = SavedPlan(
      strategy: _strategy,
      tasks: List<StudyTask>.from(_tasks),
      notes: notes,
    );

    _planHistory.insert(0, plan);
    if (_planHistory.length > 10) {
      _planHistory = _planHistory.sublist(0, 10);
    }

    await _saveHistory();
    notifyListeners();
  }

  /// Loads a plan from history into the current state.
  void loadPlan(SavedPlan plan) {
    _strategy = plan.strategy;

    _tasks
      ..clear()
      ..addAll(plan.tasks);

    if (_tasks.isNotEmpty) {
      final days = _tasks
          .map((t) => DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day))
          .toList()
        ..sort();
      _selectedDay = days.first;

      // Reschedule notifications for the loaded plan (fire-and-forget safely)
      NotificationsService.instance
          .rescheduleAll(
            tasks: _tasks,
            taskKeyOf: (t) => t.key,
            notifyBefore: Duration.zero,
          )
          .catchError((e) {
        debugPrint('Notifications reschedule failed: $e');
      });
    } else {
      NotificationsService.instance.cancelAll().catchError((_) {});
    }

    notifyListeners();
  }

  /// Deletes a specific plan from history.
  Future<void> deletePlanFromHistory(String planId) async {
    _planHistory.removeWhere((p) => p.id == planId);
    await _saveHistory();
    notifyListeners();
  }

  /// Clears all plan history.
  Future<void> clearHistory() async {
    _planHistory.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final jsonList = _planHistory.map((p) => p.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(jsonList));
  }

  Future<void> _loadHistory() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final jsonString = prefs.getString(_historyKey);
    if (jsonString == null || jsonString.trim().isEmpty) return;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      _planHistory = jsonList
          .map((e) => SavedPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading plan history: $e');
      _planHistory = <SavedPlan>[];
    }

    notifyListeners();
  }

  /// Clears the current plan (does not touch saved history).
  void clearPlan() {
    _tasks.clear();
    _error = null;
    _selectedDay = DateTime.now();

    NotificationsService.instance.cancelAll().catchError((_) {});
    notifyListeners();
  }
}
