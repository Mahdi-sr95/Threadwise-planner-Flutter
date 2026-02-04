import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/enums.dart';
import '../models/study_task.dart';
import '../state/plan_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int? _pendingJump;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<DateTime, List<StudyTask>> _groupByDay(List<StudyTask> tasks) {
    final map = <DateTime, List<StudyTask>>{};
    for (final t in tasks) {
      final d = _dayOnly(t.dateTime);
      map.putIfAbsent(d, () => <StudyTask>[]).add(t);
    }
    return map;
  }

  List<DateTime> _buildContinuousDays(DateTime start, DateTime end) {
    final s = _dayOnly(start);
    final e = _dayOnly(end);

    final out = <DateTime>[];
    for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }

  void _jumpToPageOnce(int index) {
    if (_pendingJump == index) return;
    _pendingJump = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) _pageController.jumpToPage(index);
      _pendingJump = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final planProv = context.watch<PlanProvider>();

    if (planProv.tasks.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Calendar'),
          actions: [
            IconButton(
              tooltip: 'Month view',
              icon: const Icon(Icons.calendar_month),
              onPressed: () => context.go('/calendar/month'),
            ),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No plan loaded yet.\nGenerate a plan or load a saved plan.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final grouped = _groupByDay(planProv.tasks);
    final taskDays = grouped.keys.toList()..sort();
    final days = _buildContinuousDays(taskDays.first, taskDays.last);

    final selected = planProv.selectedDay;
    final clampedSelected = selected.isBefore(days.first)
        ? days.first
        : (selected.isAfter(days.last) ? days.last : selected);

    // keep provider synced if it drifted out of range
    if (clampedSelected != selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          context.read<PlanProvider>().setSelectedDay(clampedSelected);
      });
    }

    final idx = days.indexOf(clampedSelected).clamp(0, days.length - 1);
    _jumpToPageOnce(idx);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Month view',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => context.go('/calendar/month'),
          ),
          IconButton(
            tooltip: 'Saved plans',
            icon: const Icon(Icons.history),
            onPressed: () => _showHistoryDialog(context),
          ),
          IconButton(
            tooltip: 'Clear plan',
            icon: const Icon(Icons.delete_outline),
            onPressed: planProv.clearPlan,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TableCalendar(
                    firstDay: days.first,
                    lastDay: days.last,
                    focusedDay: clampedSelected,
                    calendarFormat: CalendarFormat.week,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false, // ✅ no toggle button
                      titleCentered: true,
                    ),
                    selectedDayPredicate: (d) => isSameDay(d, clampedSelected),
                    onDaySelected: (selectedDay, focusedDay) {
                      final s = _dayOnly(selectedDay);
                      context.read<PlanProvider>().setSelectedDay(s);

                      final newIdx = days.indexOf(s);
                      if (newIdx >= 0) {
                        _pageController.animateToPage(
                          newIdx,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    eventLoader: (day) =>
                        grouped[_dayOnly(day)] ?? const <StudyTask>[],
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: days.length,
                onPageChanged: (index) {
                  context.read<PlanProvider>().setSelectedDay(days[index]);
                },
                itemBuilder: (context, index) {
                  final day = days[index];
                  final dayTasks = (grouped[day] ?? <StudyTask>[])
                    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DayCard(day: day, tasks: dayTasks),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 420,
          height: 520,
          child: Column(
            children: [
              AppBar(
                title: const Text('Saved Plans'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: Consumer<PlanProvider>(
                  builder: (context, planProvider, _) {
                    if (planProvider.planHistory.isEmpty) {
                      return const Center(child: Text('No saved plans'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: planProvider.planHistory.length,
                      itemBuilder: (context, index) {
                        final plan = planProvider.planHistory[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(_strategyIcon(plan.strategy)),
                            title: Text(plan.strategy.displayName),
                            subtitle: Text(
                              '${plan.tasks.length} tasks • ${plan.formattedDate}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.upload),
                              tooltip: 'Load',
                              onPressed: () {
                                planProvider.loadPlan(plan);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _strategyIcon(Strategy strategy) {
    switch (strategy) {
      case Strategy.waterfall:
        return Icons.layers;
      case Strategy.sandwich:
        return Icons.flip;
      case Strategy.sequential:
        return Icons.timeline;
      case Strategy.randomMix:
        return Icons.shuffle;
    }
  }
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<StudyTask> tasks;

  const _DayCard({required this.day, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final title = '${day.day}/${day.month}/${day.year}';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text('No tasks on this day'),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final t = tasks[i];
                    final start =
                        '${t.dateTime.hour}:${t.dateTime.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text('${t.subject} • $start'),
                      subtitle: Text(t.task),
                      trailing: Chip(label: Text(t.difficulty.displayName)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
