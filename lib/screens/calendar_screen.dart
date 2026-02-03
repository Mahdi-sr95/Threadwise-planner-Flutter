import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_task.dart';
import '../state/plan_provider.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planProv = context.watch<PlanProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Clear current plan',
            onPressed: planProv.tasks.isEmpty ? null : planProv.clearPlan,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SavedPlansPicker(planProv: planProv),
            const SizedBox(height: 16),

            if (planProv.tasks.isEmpty)
              _EmptyCalendarState(hasHistory: planProv.planHistory.isNotEmpty)
            else
              _CalendarDayColumns(tasks: planProv.tasks),
          ],
        ),
      ),
    );
  }
}

class _SavedPlansPicker extends StatelessWidget {
  final PlanProvider planProv;
  const _SavedPlansPicker({required this.planProv});

  @override
  Widget build(BuildContext context) {
    final history = planProv.planHistory;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved plans', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            if (history.isEmpty)
              Text(
                'No saved plans yet. Generate a plan and tap Save in the Plan tab.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select a saved plan',
                        border: OutlineInputBorder(),
                      ),
                      items: history.map((p) {
                        final label =
                            '${p.strategy.displayName} • ${p.tasks.length} tasks • ${p.formattedDate}'
                            '${p.notes != null && p.notes!.trim().isNotEmpty ? ' • ${p.notes}' : ''}';
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        final plan = history.firstWhere((p) => p.id == id);
                        planProv.loadPlan(plan);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Loaded saved plan')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Manage history',
                    onPressed: () => _showHistoryDialog(context),
                    icon: const Icon(Icons.history),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _PlanHistoryDialog(),
    );
  }
}

class _PlanHistoryDialog extends StatelessWidget {
  const _PlanHistoryDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          children: [
            AppBar(
              title: const Text('Plan History'),
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
                builder: (context, planProv, _) {
                  if (planProv.planHistory.isEmpty) {
                    return const Center(child: Text('No saved plans'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: planProv.planHistory.length,
                    itemBuilder: (context, index) {
                      final p = planProv.planHistory[index];
                      final subtitle = <String>[
                        '${p.tasks.length} tasks',
                        p.formattedDate,
                        if (p.notes != null && p.notes!.trim().isNotEmpty)
                          p.notes!,
                      ].join(' • ');

                      return Card(
                        child: ListTile(
                          title: Text(p.strategy.displayName),
                          subtitle: Text(subtitle),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Load',
                                icon: const Icon(Icons.upload),
                                onPressed: () {
                                  planProv.loadPlan(p);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Loaded saved plan'),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    planProv.deletePlanFromHistory(p.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.read<PlanProvider>().clearHistory(),
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear history'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCalendarState extends StatelessWidget {
  final bool hasHistory;
  const _EmptyCalendarState({required this.hasHistory});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, size: 64),
            const SizedBox(height: 12),
            Text(
              'Nothing to show',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasHistory
                  ? 'Pick a saved plan above to view it as a calendar.'
                  : 'Generate a plan and save it first, then it will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// “Calendar-like” view: grouped by day, each day is a section.
/// Later you can swap this with a real month grid or week timeline.
class _CalendarDayColumns extends StatelessWidget {
  final List<StudyTask> tasks;
  const _CalendarDayColumns({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(tasks);
    final days = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: days.map((day) {
        final dayTasks = grouped[day]!
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dayLabel(day),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...dayTasks.map((t) => _CalendarTaskChip(task: t)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Map<DateTime, List<StudyTask>> _groupByDay(List<StudyTask> tasks) {
    final map = <DateTime, List<StudyTask>>{};
    for (final t in tasks) {
      final d = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      map.putIfAbsent(d, () => <StudyTask>[]).add(t);
    }
    return map;
  }

  String _dayLabel(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final w = weekdays[date.weekday - 1];
    return '$w ${date.day}/${date.month}/${date.year}';
  }
}

class _CalendarTaskChip extends StatelessWidget {
  final StudyTask task;
  const _CalendarTaskChip({required this.task});

  @override
  Widget build(BuildContext context) {
    final start =
        '${task.dateTime.hour.toString().padLeft(2, '0')}:${task.dateTime.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_note, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$start • ${task.subject}\n${task.task}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
