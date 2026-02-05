import 'package:csv/csv.dart';
import '../models/study_task.dart';

// Picks web on web, IO on Windows/Android/iOS
import 'csv_export_io.dart' if (dart.library.html) 'csv_export_web.dart';

class CsvExportService {
  String buildCsv(List<StudyTask> tasks) {
    final rows = <List<dynamic>>[
      ['date', 'time', 'subject', 'task', 'duration_hours', 'difficulty'],
      ...tasks.map(
        (t) => [
          '${t.dateTime.year}-${t.dateTime.month.toString().padLeft(2, '0')}-${t.dateTime.day.toString().padLeft(2, '0')}',
          '${t.dateTime.hour.toString().padLeft(2, '0')}:${t.dateTime.minute.toString().padLeft(2, '0')}',
          t.subject,
          t.task,
          t.durationHours,
          t.difficulty.toString().split('.').last,
        ],
      ),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  Future<void> exportCsv(List<StudyTask> tasks) async {
    if (tasks.isEmpty) return;
    final csvText = buildCsv(tasks);
    await saveOrShareCsv('threadwise_plan.csv', csvText);
  }
}
