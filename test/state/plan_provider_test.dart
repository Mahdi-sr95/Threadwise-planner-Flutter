import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threadwise_planner/models/course.dart';
import 'package:threadwise_planner/models/enums.dart';
import 'package:threadwise_planner/state/plan_provider.dart';

List<Course> _sampleCourses() => [
      Course(
        name: 'Mobile Application Development',
        deadline: DateTime(2026, 2, 15),
        difficulty: Difficulty.hard,
        studyHours: 10.0,
      ),
      Course(
        name: 'Database Systems',
        deadline: DateTime(2026, 2, 20),
        difficulty: Difficulty.medium,
        studyHours: 8.0,
      ),
    ];

Future<void> _clearPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

Future<void> _waitForProviderInit() async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('PlanProvider', () {
    test('saveCurrentPlan adds to history and caps to 10 (most recent first)', () async {
      await _clearPrefs();

      final provider = PlanProvider();
      await _waitForProviderInit();

      await provider.generatePlan(_sampleCourses());
      expect(provider.tasks.isNotEmpty, true);

      for (var i = 0; i < 11; i++) {
        await provider.saveCurrentPlan(notes: 'plan $i');
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      expect(provider.planHistory.length, 10);
      expect(provider.planHistory.first.notes, 'plan 10');
      expect(provider.planHistory.last.notes, 'plan 1');
    });

    test('deletePlanFromHistory removes plan by id', () async {
      await _clearPrefs();

      final provider = PlanProvider();
      await _waitForProviderInit();

      await provider.generatePlan(_sampleCourses());
      expect(provider.tasks.isNotEmpty, true);

      await provider.saveCurrentPlan(notes: 'A');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await provider.saveCurrentPlan(notes: 'B');

      expect(provider.planHistory.length, 2);

      final idToDelete = provider.planHistory[1].id; // A
      await provider.deletePlanFromHistory(idToDelete);

      expect(provider.planHistory.any((p) => p.id == idToDelete), false);
      expect(provider.planHistory.length, 1);
      expect(provider.planHistory.first.notes, 'B');
    });
  });
}
