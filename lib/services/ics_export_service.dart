import '../models/study_task.dart';
import 'ics_export_io.dart' if (dart.library.html) 'ics_export_web.dart';

class IcsExportService {
  Future<void> exportIcs(
    List<StudyTask> tasks, {
    String filename = 'threadwise_plan.ics',
    String calendarName = 'ThreadWise Plan',
  }) async {
    if (tasks.isEmpty) return;
    final icsText = buildIcs(tasks, calendarName: calendarName);
    await saveOrShareIcs(filename, icsText);
  }

  String buildIcs(
    List<StudyTask> tasks, {
    String calendarName = 'ThreadWise Plan',
  }) {
    final nowUtc = DateTime.now().toUtc();
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ThreadWise Planner//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:${_esc(calendarName)}',
    ];

    for (final t in tasks) {
      final start = t.dateTime;
      final minutes = _durationMinutes(t.durationHours);
      final end = start.add(Duration(minutes: minutes));

      final uid = _makeUid(t);
      final dtstamp = _fmtUtc(nowUtc);
      final dtStartLocal = _fmtLocal(start);
      final dtEndLocal = _fmtLocal(end);

      final summary = t.subject.trim().isEmpty
          ? 'Study Session'
          : t.subject.trim();
      final description = _buildDescription(t);

      lines.addAll([
        'BEGIN:VEVENT',
        'UID:$uid',
        'DTSTAMP:$dtstamp',
        'DTSTART:$dtStartLocal',
        'DTEND:$dtEndLocal',
        'SUMMARY:${_esc(summary)}',
        'DESCRIPTION:${_esc(description)}',
        'CATEGORIES:STUDY',
        'END:VEVENT',
      ]);
    }

    lines.add('END:VCALENDAR');

    // iCalendar typically uses CRLF line endings.
    return lines.join('\r\n') + '\r\n';
  }

  int _durationMinutes(double hours) {
    final m = (hours * 60.0).round();
    if (m <= 0) return 60;
    return m;
  }

  String _buildDescription(StudyTask t) {
    final parts = <String>[
      t.task.trim(),
      'Difficulty: ${t.difficulty.name}',
      'DurationHours: ${t.durationHours}',
    ].where((s) => s.trim().isNotEmpty).toList();
    return parts.join('\\n');
  }

  String _makeUid(StudyTask t) {
    final base =
        '${t.subject}|${t.task}|${t.dateTime.toIso8601String()}|${t.durationHours}';
    final h = _simpleHash(base);
    return 'threadwise-$h-${t.dateTime.millisecondsSinceEpoch}@threadwise.local';
  }

  int _simpleHash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  String _fmtLocal(DateTime dt) {
    // Floating local time (no "Z")
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}'
        'T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _fmtUtc(DateTime dtUtc) {
    final dt = dtUtc.toUtc();
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}'
        'T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}Z';
  }

  String _esc(String s) {
    return s
        .replaceAll('\\', r'\\')
        .replaceAll('\r\n', r'\n')
        .replaceAll('\n', r'\n')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;');
  }
}
