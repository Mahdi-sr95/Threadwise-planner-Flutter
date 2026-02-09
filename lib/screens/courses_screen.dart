import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/settings_provider.dart';
import '../state/courses_provider.dart';
import '../state/plan_provider.dart';
import '../state/semesters_provider.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coursesProv = context.watch<CoursesProvider>();
    final planProv = context.watch<PlanProvider>();
    final semProv = context.watch<SemestersProvider>();

    final courses = coursesProv.coursesForSelectedSemester;
    final semesterName = semProv.selectedSemester?.name ?? 'Default';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            tooltip: 'Semesters',
            icon: const Icon(Icons.school),
            onPressed: () => context.go('/semesters'),
          ),
          IconButton(
            tooltip: 'Saved courses',
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => context.go('/saved-courses'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Semester: $semesterName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/semesters'),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/saved-courses'),
                icon: const Icon(Icons.bookmark_outline),
                label: const Text('Select an earlier course'),
              ),
            ),

            const SizedBox(height: 16),

            Text('Your courses', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),

            Center(
              child: SizedBox(
                width: 260,
                child: FilledButton.icon(
                  onPressed: () => context.go('/courses/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add course'),
                ),
              ),
            ),

            const SizedBox(height: 14),

            if (courses.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No courses in this semester yet.\nUse "Add course" above to create one.',
                    textAlign: TextAlign.center,
                  ),
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
                      onTap: () => context.go('/courses/${c.id}/edit'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                context.go('/courses/${c.id}/edit'),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => coursesProv.removeAt(i),
                          ),
                        ],
                      ),
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

  static String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
