import 'dart:io' show File;

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/study_task.dart';

import 'csv_export_web.dart' if (dart.library.io) 'csv_export_io.dart';

class CsvExportService {
  String buildCsv(List<StudyTask> tasks) {
    final rows = <List<dynamic>>[
      ['subject', 'task', 'date', 'start_time', 'duration_hours', 'difficulty'],
      ...tasks.map((t) {
        final date = _yyyyMmDd(t.dateTime);
        final time = _hhMm(t.dateTime);
        return [
          t.subject,
          t.task,
          date,
          time,
          t.durationHours,
          t.difficulty.toString().split('.').last,
        ];
      }),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  Future<void> export({
    required List<StudyTask> tasks,
    String fileName = 'threadwise_plan.csv',
  }) async {
    final csv = buildCsv(tasks);

    if (kIsWeb) {
      // Browser download
      downloadCsvWeb(csv: csv, fileName: fileName);
      return;
    }

    // Mobile/Desktop: save temp + share
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv, flush: true);

    await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/csv', name: fileName),
    ], text: 'ThreadWise study plan (CSV)');
  }

  String _yyyyMmDd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _hhMm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
