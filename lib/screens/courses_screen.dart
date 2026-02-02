import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/settings_provider.dart';
import '../state/courses_provider.dart';
import '../state/plan_provider.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context, {
    required String courseName,
    required VoidCallback onDelete,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete course?'),
        content: Text('This will remove "$courseName" from your courses.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final coursesProv = context.watch<CoursesProvider>();
    final planProv = context.watch<PlanProvider>();
    final courses = coursesProv.courses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            onPressed: () => context.go('/courses/add'),
            icon: const Icon(Icons.add),
            tooltip: 'Add course',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Your courses', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            if (courses.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No courses yet. Tap + to add one.'),
                ),
              )
            else
              ...List.generate(courses.length, (i) {
                final c = courses[i];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      title: Text(c.name),
                      subtitle: Text(
                        'Deadline: ${_formatDate(c.deadline)} • ${c.difficulty.displayName} • ${c.studyHours}h',
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Course actions',
                        onSelected: (value) async {
                          if (value == 'edit') {
                            context.go('/courses/${c.id}/edit?from=courses');
                          } else if (value == 'delete') {
                            await _confirmDelete(
                              context,
                              courseName: c.name,
                              onDelete: () => coursesProv.removeAt(i),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        // Optional: tap row to edit too
                        context.go('/courses/${c.id}/edit?from=courses');
                      },
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),

            DropdownButtonFormField<Strategy>(
              value: planProv.strategy,
              items: Strategy.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) planProv.setStrategy(v);
              },
              decoration: const InputDecoration(
                labelText: 'Study Strategy',
                border: OutlineInputBorder(),
                helperText: 'Choose how to organize your study sessions',
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                planProv.strategy.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: courses.isEmpty
                    ? null
                    : () async {
                        final settings = context
                            .read<SettingsProvider>()
                            .settings;
                        await planProv.generatePlan(courses, settings);

                        if (context.mounted) context.go('/plan');
                      },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
