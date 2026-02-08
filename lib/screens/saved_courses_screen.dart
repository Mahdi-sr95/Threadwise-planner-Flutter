import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/saved_course.dart';
import '../state/courses_provider.dart';
import '../state/saved_courses_provider.dart';
import '../state/semesters_provider.dart';

class SavedCoursesScreen extends StatelessWidget {
  const SavedCoursesScreen({super.key});

  Future<void> _selectSavedCourse(BuildContext context, SavedCourse sc) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDate: now.add(const Duration(days: 14)),
    );

    if (picked == null) return;

    final deadline = DateTime(picked.year, picked.month, picked.day);

    final semProv = context.read<SemestersProvider>();
    final semesterId = semProv.selectedSemester?.id;

    if (semesterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a semester first')),
      );
      return;
    }

    await context.read<CoursesProvider>().addCourse(
      Course(
        name: sc.name,
        deadline: deadline,
        difficulty: sc.difficulty,
        studyHours: sc.studyHours,
      ),
      semesterId: semesterId,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${sc.name}" to your courses')),
    );

    context.go('/courses');
  }

  @override
  Widget build(BuildContext context) {
    final savedProv = context.watch<SavedCoursesProvider>();
    final saved = savedProv.saved;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Courses'),
        leading: IconButton(
          tooltip: 'Back to Courses',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/courses'),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => savedProv.reload(),
          ),
          IconButton(
            tooltip: 'Clear library',
            icon: const Icon(Icons.delete_outline),
            onPressed: saved.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Clear saved courses?'),
                        content: const Text(
                          'This removes all saved courses derived from saved plans.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await savedProv.clearLibrary();
                    }
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: SizedBox(
                width: 280,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Courses'),
                  onPressed: () => context.go('/courses'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (saved.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No saved courses yet.\nSave a plan first to build this library.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...List.generate(saved.length, (i) {
                final sc = saved[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      title: Text(sc.name),
                      subtitle: Text(
                        '${sc.difficulty.name} • ${sc.studyHours}h • used ${sc.timesUsed}×',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectSavedCourse(context, sc),
                      onLongPress: () async {
                        await savedProv.deleteSavedCourse(sc.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Removed "${sc.name}"')),
                        );
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
