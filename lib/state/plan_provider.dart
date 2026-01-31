import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/enums.dart';
import '../models/saved_plan.dart';
import '../models/study_task.dart';
import '../services/llm_planner_service.dart';

/// Provider responsible for plan generation and persisted plan history.
class PlanProvider extends ChangeNotifier {
  static const String _historyKey = 'plan_history';

  Strategy _strategy = Strategy.waterfall;
  List<StudyTask> _tasks = <StudyTask>[];
  List<SavedPlan> _planHistory = <SavedPlan>[];
  bool _loading = false;
  String? _error;

  SharedPreferences? _prefs;

  Strategy get strategy => _strategy;
  List<StudyTask> get tasks => List.unmodifiable(_tasks);
  List<SavedPlan> get planHistory => List.unmodifiable(_planHistory);
  bool get loading => _loading;
  String? get error => _error;

  PlanProvider() {
    _initPrefs();
  }

  /// Initializes SharedPreferences and loads saved history.
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
      _tasks = PlannerService.generatePlan(courses, _strategy);
    } catch (e) {
      _tasks = <StudyTask>[];
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
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
    _tasks = List<StudyTask>.from(plan.tasks);
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading plan history: $e');
    }
  }

  /// Clears the current plan (does not touch saved history).
  void clearPlan() {
    _tasks = <StudyTask>[];
    _error = null;
    notifyListeners();
  }
}
