import 'package:flutter/foundation.dart';
import '../utils/mock_data.dart';
import '../models/study_task.dart';

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
  bool _loading = false;
  String? _error;

  // ✅ getters must return the private fields (underscore)
  Strategy get strategy => _strategy;
  List<StudyTask> get tasks => List.unmodifiable(_tasks);
  bool get loading => _loading;
  String? get error => _error;

  void setStrategy(Strategy s) {
    _strategy = s;
    notifyListeners();
  }

  Future<void> generateFromMock() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      _tasks = [...MockData.mockPlan];
    } catch (e) {
      _error = 'Failed to generate plan: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _tasks = [];
    _error = null;
    notifyListeners();
  }
}
