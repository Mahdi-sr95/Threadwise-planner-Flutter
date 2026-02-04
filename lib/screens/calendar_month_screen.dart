import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/study_task.dart';
import '../state/plan_provider.dart';

class CalendarMonthScreen extends StatelessWidget {
  const CalendarMonthScreen({super.key});

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<DateTime, List<StudyTask>> _groupByDay(List<StudyTask> tasks) {
    final map = <DateTime, List<StudyTask>>{};
    for (final t in tasks) {
      final d = _dayOnly(t.dateTime);
      map.putIfAbsent(d, () => <StudyTask>[]).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final planProv = context.watch<PlanProvider>();

    if (planProv.tasks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Month')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No plan loaded yet.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final grouped = _groupByDay(planProv.tasks);
    final taskDays = grouped.keys.toList()..sort();
    final firstDay = taskDays.first;
    final lastDay = taskDays.last;

    final selected = planProv.selectedDay;
    final focused = selected.isBefore(firstDay)
        ? firstDay
        : (selected.isAfter(lastDay) ? lastDay : selected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Month'),
        actions: [
          IconButton(
            tooltip: 'Back to daily view',
            icon: const Icon(Icons.view_carousel),
            onPressed: () => context.go('/calendar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableCalendar(
                firstDay: firstDay,
                lastDay: lastDay,
                focusedDay: focused,
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                selectedDayPredicate: (d) => isSameDay(d, selected),
                onDaySelected: (selectedDay, focusedDay) {
                  context.read<PlanProvider>().setSelectedDay(
                    _dayOnly(selectedDay),
                  );
                  context.go(
                    '/calendar',
                  ); // jump to calendar_screen on that specific selected day
                },
                eventLoader: (day) =>
                    grouped[_dayOnly(day)] ?? const <StudyTask>[],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
