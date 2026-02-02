import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/study_task.dart';
import '../state/plan_provider.dart';

/// Displays the generated plan, allows strategy selection, saving and loading history.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plan (${planProv.strategy.label})'),
        actions: [
          IconButton(
            tooltip: 'Generate (mock)',
            onPressed: () => context.read<PlanProvider>().generateFromMock(),
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: () => context.read<PlanProvider>().clear(),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (_) {
            if (planProv.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (planProv.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(planProv.error!),
                ),
              );
            }

            if (planProv.tasks.isEmpty) {
              return _EmptyPlan(
                onGenerate: () =>
                    context.read<PlanProvider>().generateFromMock(),
              );
            }

            return _PlanList(tasks: planProv.tasks);
          },
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

class _EmptyPlan extends StatelessWidget {
  final VoidCallback onGenerate;
  const _EmptyPlan({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_agenda_outlined, size: 64),
            const SizedBox(height: 12),
            Text('No plan yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Generate a plan from Courses, or tap Generate here (mock).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate (mock)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanList extends StatelessWidget {
  final List<StudyTask> tasks;
  const _PlanList({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(tasks);
    final days = grouped.keys.toList()..sort();

    final dayFmt = DateFormat('EEEE, MMM d');
    final timeFmt = DateFormat('HH:mm');

    return ListView.builder(
      // I used a builder function here because it makes the performance better by building the items lazily
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final dayTasks = grouped[day]!
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayFmt.format(day),
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 10),

              ...dayTasks.map((t) {
                final start = t.dateTime;
                final end = start.add(
                  Duration(minutes: (t.durationHours * 60).round()),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(
                        '${timeFmt.format(start)}–${timeFmt.format(end)}  •  ${t.subject}',
                      ),
                      subtitle: Text(t.task),
                      trailing: Chip(
                        label: Text(_difficultyLabel(t.difficulty)),
                      ),
                      onTap: null,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Map<DateTime, List<StudyTask>> _groupByDay(List<StudyTask> tasks) {
    final map = <DateTime, List<StudyTask>>{};
    for (final t in tasks) {
      final d = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      map.putIfAbsent(d, () => []).add(t);
    }
    return map;
  }

  String _difficultyLabel(dynamic difficulty) {
    final name = difficulty.toString().split('.').last;
    return name[0].toUpperCase() + name.substring(1);
  }
}
