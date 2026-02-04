// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
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
  DateTime _focusedDay = _dayOnly(DateTime.now());
  DateTime _selectedDay = _dayOnly(DateTime.now());

  final PageController _pageController = PageController(viewportFraction: 0.92);
  bool _didInitialJump = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToIndexOnce(int index) {
    if (_didInitialJump) return;
    _didInitialJump = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final planProv = context.watch<PlanProvider>();

    final grouped = _groupByDay(planProv.tasks);
    final taskDays = grouped.keys.toList()..sort();

    // Range logic: if plan exists -> use plan range, else show a reasonable placeholder range
    final DateTime rangeStart;
    final DateTime rangeEnd;
    if (taskDays.isNotEmpty) {
      rangeStart = _dayOnly(taskDays.first);
      rangeEnd = _dayOnly(taskDays.last);
    } else {
      final today = _dayOnly(DateTime.now());
      rangeStart = today.subtract(const Duration(days: 7));
      rangeEnd = today.add(const Duration(days: 21));
    }

    final days = _buildContinuousDays(rangeStart, rangeEnd);

    // Clamp selected day into range (do NOT force to a task day)
    final selected = _dayOnly(_selectedDay);
    DateTime initialDay = selected;
    if (initialDay.isBefore(rangeStart)) initialDay = rangeStart;
    if (initialDay.isAfter(rangeEnd)) initialDay = rangeEnd;

    _selectedDay = initialDay;
    _focusedDay = initialDay;

    final initialIndex = days
        .indexOf(_dayOnly(initialDay))
        .clamp(0, days.length - 1);
    _jumpToIndexOnce(initialIndex);

    final hasRealPlan = planProv.tasks.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          _historyButton(context),
          IconButton(
            tooltip: 'Clear plan',
            icon: const Icon(Icons.delete_outline),
            onPressed: planProv.tasks.isEmpty ? null : planProv.clearPlan,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Week strip
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TableCalendar(
                    firstDay: rangeStart,
                    lastDay: rangeEnd,
                    focusedDay: _focusedDay,
                    calendarFormat: CalendarFormat.week,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = _dayOnly(selectedDay);
                        _focusedDay = _dayOnly(focusedDay);
                      });

                      final idx = days.indexOf(_dayOnly(selectedDay));
                      if (idx >= 0 && _pageController.hasClients) {
                        _pageController.animateToPage(
                          idx,
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

            if (!hasRealPlan)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'No plan loaded yet. This is a placeholder date range.\nGenerate a plan to see real tasks here.',
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 8),

            // horizontal swipe: one page per day
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: days.length,
                onPageChanged: (index) {
                  final newDay = days[index];
                  setState(() {
                    _selectedDay = newDay;
                    _focusedDay = newDay;
                  });
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

  Widget _historyButton(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, _) {
        return IconButton(
          icon: Badge(
            label: Text('${planProvider.planHistory.length}'),
            isLabelVisible: planProvider.planHistory.isNotEmpty,
            child: const Icon(Icons.history),
          ),
          tooltip: 'Saved plans',
          onPressed: () => _showHistoryDialog(context),
        );
      },
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
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${plan.tasks.length} tasks'),
                                Text(plan.formattedDate),
                                if (plan.notes != null) Text(plan.notes!),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.upload),
                              tooltip: 'Load',
                              onPressed: () {
                                planProvider.loadPlan(plan);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Plan loaded!')),
                                );

                                // allow re-jump to correct day range after loading
                                setState(() {
                                  _didInitialJump = false;
                                  _selectedDay = _dayOnly(DateTime.now());
                                  _focusedDay = _dayOnly(DateTime.now());
                                });
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

Map<DateTime, List<StudyTask>> _groupByDay(List<StudyTask> tasks) {
  final map = <DateTime, List<StudyTask>>{};
  for (final t in tasks) {
    final d = _dayOnly(t.dateTime);
    map.putIfAbsent(d, () => <StudyTask>[]).add(t);
  }
  return map;
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

List<DateTime> _buildContinuousDays(DateTime start, DateTime end) {
  final s = _dayOnly(start);
  final e = _dayOnly(end);
  final out = <DateTime>[];
  for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
    out.add(d);
  }
  return out;
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
