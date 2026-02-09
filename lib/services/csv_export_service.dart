import 'package:csv/csv.dart';

import '../models/study_task.dart';
// Picks web on web, IO on Windows/Android/iOS.
import 'csv_export_io.dart' if (dart.library.html) 'csv_export_web.dart';

/// Builds and exports a study plan as CSV.
///
/// Notes:
/// - Uses conditional import to support both Web (download) and IO platforms (share file).
/// - Keeps formatting stable (YYYY-MM-DD + HH:mm) for spreadsheet compatibility.
class CsvExportService {
  /// Builds CSV text from a list of [StudyTask].
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

  /// Exports the current plan as a CSV file (download on Web, share file on mobile/desktop).
  Future<void> exportCsv(List<StudyTask> tasks) async {
    if (tasks.isEmpty) return;
    final csvText = buildCsv(tasks);
    await saveOrShareCsv('threadwise_plan.csv', csvText);
  }
}
