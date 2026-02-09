import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/saved_courses_provider.dart';
import '../models/enums.dart';
import '../models/study_task.dart';
import '../state/courses_provider.dart';
import '../state/plan_provider.dart';
import 'package:go_router/go_router.dart';
import '../services/csv_export_service.dart';
import '../services/ics_export_service.dart';

/// Displays the generated plan, allows strategy selection, saving and loading
/// history.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  void _openEditCourseFromTask(BuildContext context, StudyTask task) {
    final coursesProv = context.read<CoursesProvider>();
    final matches = coursesProv.findByName(task.subject);

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course not found for "${task.subject}"')),
      );
      return;
    }

    final course = matches.first;
    context.go('/courses/${course.id}/edit?from=plan');
  }

  static final CsvExportService _csvExporter = CsvExportService();
  static final IcsExportService icsExporter = IcsExportService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Plan'),
        actions: [
          // History button (uses _showHistoryDialog)
          Consumer<PlanProvider>(
            builder: (context, planProvider, _) {
              return IconButton(
                icon: Badge(
                  label: Text('${planProvider.planHistory.length}'),
                  isLabelVisible: planProvider.planHistory.isNotEmpty,
                  child: const Icon(Icons.history),
                ),
                tooltip: 'Plan History',
                onPressed: () => _showHistoryDialog(context),
              );
            },
          ),
          // Export CSV button
          Consumer<PlanProvider>(
            builder: (context, planProvider, _) {
              return IconButton.filledTonal(
                icon: const Icon(Icons.download),
                tooltip: 'Export CSV',
                onPressed: planProvider.tasks.isEmpty
                    ? null
                    : () async {
                        try {
                          await _csvExporter.exportCsv(planProvider.tasks);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('CSV export failed: $e')),
                          );
                        }
                      },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Planning Strategy',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Consumer<PlanProvider>(
                    builder: (context, planProvider, _) {
                      return SegmentedButton<Strategy>(
                        segments: const [
                          ButtonSegment(
                            value: Strategy.waterfall,
                            label: Text('Waterfall'),
                            icon: Icon(Icons.layers),
                          ),
                          ButtonSegment(
                            value: Strategy.sandwich,
                            label: Text('Sandwich'),
                            icon: Icon(Icons.flip),
                          ),
                          ButtonSegment(
                            value: Strategy.sequential,
                            label: Text('Sequential'),
                            icon: Icon(Icons.timeline),
                          ),
                          ButtonSegment(
                            value: Strategy.randomMix,
                            label: Text('Random'),
                            icon: Icon(Icons.shuffle),
                          ),
                        ],
                        selected: {planProvider.strategy},
                        onSelectionChanged: (newSelection) {
                          planProvider.setStrategy(newSelection.first);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Consumer<PlanProvider>(
                    builder: (context, planProvider, _) {
                      return Text(
                        planProvider.strategy.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Consumer2<CoursesProvider, PlanProvider>(
                    builder: (context, coursesProvider, planProvider, _) {
                      return FilledButton.icon(
                        onPressed: planProvider.loading
                            ? null
                            : () async {
                                await planProvider.generatePlan(
                                  coursesProvider.courses,
                                );
                              },
                        icon: planProvider.loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          planProvider.loading
                              ? 'Generating...'
                              : 'Generate Plan',
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<PlanProvider>(
                  builder: (context, planProvider, _) {
                    return IconButton.filledTonal(
                      icon: const Icon(Icons.save),
                      onPressed: planProvider.tasks.isEmpty
                          ? null
                          : () => _showSaveDialog(context),
                      tooltip: 'Save Plan',
                    );
                  },
                ),
                Consumer<PlanProvider>(
                  builder: (context, planProvider, _) {
                    return IconButton.filledTonal(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: planProvider.tasks.isEmpty
                          ? null
                          : planProvider.clearPlan,
                      tooltip: 'Clear Plan',
                    );
                  },
                ),
                Consumer<PlanProvider>(
                  builder: (context, planProvider, _) {
                    return IconButton.filledTonal(
                      icon: const Icon(Icons.event_available),
                      tooltip: 'Export ICS',
                      onPressed: planProvider.tasks.isEmpty
                          ? null
                          : () async {
                              try {
                                await icsExporter.exportIcs(planProvider.tasks);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('ICS export failed: $e'),
                                  ),
                                );
                              }
                            },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<PlanProvider>(
              builder: (context, planProvider, _) {
                if (planProvider.loading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Generating your study plan...'),
                      ],
                    ),
                  );
                }

                if (planProvider.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${planProvider.error}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (planProvider.tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No plan generated yet',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add courses and generate a plan',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return _buildTaskList(context, planProvider.tasks);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, List<StudyTask> tasks) {
    final Map<DateTime, List<StudyTask>> groupedTasks = {};

    for (final task in tasks) {
      final date = DateTime(
        task.dateTime.year,
        task.dateTime.month,
        task.dateTime.day,
      );
      groupedTasks.putIfAbsent(date, () => <StudyTask>[]).add(task);
    }

    final sortedDates = groupedTasks.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dateTasks = groupedTasks[date]!
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _formatDate(date),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...dateTasks.map((task) => _buildTaskCard(context, task)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, StudyTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _openEditCourseFromTask(context, task),
        leading: CircleAvatar(
          backgroundColor: _getDifficultyColor(task.difficulty),
          child: const Icon(Icons.book, color: Colors.white, size: 20),
        ),
        title: Text(task.subject),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.task),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${task.dateTime.hour}:${task.dateTime.minute.toString().padLeft(2, '0')} • ${task.formattedDuration}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            task.difficulty.displayName,
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: _getDifficultyColor(
            task.difficulty,
          ).withValues(alpha: 0.2),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == tomorrow) return 'Tomorrow';

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.day}/${date.month}/${date.year}';
  }

  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
    }
  }

  void _showSaveDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Plan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'e.g., Exam week plan',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final notes = controller.text.trim().isEmpty
                  ? null
                  : controller.text.trim();

              await context.read<PlanProvider>().saveCurrentPlan(notes: notes);

              await context.read<SavedCoursesProvider>().ingestFromSavedPlan(
                context.read<CoursesProvider>().courses,
              );

              if (!context.mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Plan saved!')));
            },
            child: const Text('Save'),
          ),
        ],
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.upload),
                                  tooltip: 'Load',
                                  onPressed: () {
                                    planProvider.loadPlan(plan);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Plan loaded!'),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Delete',
                                  onPressed: () {
                                    planProvider.deletePlanFromHistory(plan.id);
                                  },
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
