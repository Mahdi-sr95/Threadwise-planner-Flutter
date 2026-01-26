import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/courses_provider.dart';
import '../state/plan_provider.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

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
                        'Deadline: ${c.deadline.toLocal()} • ${c.difficulty.name}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => coursesProv.removeAt(i),
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
                labelText: 'Strategy',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: courses.isEmpty
                    ? null
                    : () async {
                        await planProv.generateFromMock();
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
}
