import 'package:flutter_test/flutter_test.dart';
import 'package:threadwise_planner/models/enums.dart';
import 'package:threadwise_planner/models/study_task.dart';

void main() {
  group('StudyTask', () {
    test('formattedDuration handles 0h/1h/1h30', () {
      final base = DateTime(2026, 2, 1, 9, 0);

      final t0 = StudyTask(
        subject: 'X',
        task: 'T',
        dateTime: base,
        durationHours: 0.0,
        difficulty: Difficulty.easy,
      );
      expect(t0.formattedDuration, '0m');

      final t1 = StudyTask(
        subject: 'X',
        task: 'T',
        dateTime: base,
        durationHours: 1.0,
        difficulty: Difficulty.easy,
      );
      expect(t1.formattedDuration, '1h');

      final t2 = StudyTask(
        subject: 'X',
        task: 'T',
        dateTime: base,
        durationHours: 1.5,
        difficulty: Difficulty.easy,
      );
      expect(t2.formattedDuration, '1h 30m');
    });

    test('JSON round-trip toJson/fromJson preserves fields', () {
      final original = StudyTask(
        subject: 'Mobile App Dev',
        task: 'Study session 1',
        dateTime: DateTime(2026, 2, 1, 9, 0),
        durationHours: 2.5,
        difficulty: Difficulty.hard,
      );

      final json = original.toJson();
      final decoded = StudyTask.fromJson(json);

      expect(decoded.subject, original.subject);
      expect(decoded.task, original.task);
      expect(decoded.durationHours, original.durationHours);
      expect(decoded.difficulty, original.difficulty);

      // safer than direct DateTime equality in case of parsing nuances
      expect(decoded.dateTime.toIso8601String(), original.dateTime.toIso8601String());
    });
  });
}
