import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/enums.dart';
import '../state/courses_provider.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  DateTime? _deadline;
  Difficulty _difficulty = Difficulty.medium;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
    );

    if (picked != null) {
      setState(
        () => _deadline = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  void _save() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_deadline == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a deadline')));
      return;
    }

    final course = Course(
      name: _nameCtrl.text.trim(),
      deadline: _deadline!,
      difficulty: _difficulty,
    );

    context.read<CoursesProvider>().addCourses(course);

    // Go back to courses list
    context.go('/courses');
  }

  @override
  Widget build(BuildContext context) {
    final deadlineText = _deadline == null
        ? 'Pick a date'
        : _formatDate(_deadline!);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Course')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Course details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the course info, then save.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Course name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Course name',
                  hintText: 'e.g., Mobile Application Development',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Course name is required';
                  if (v.trim().length < 2) return 'Too short';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Deadline picker (UI)
              InkWell(
                onTap: _pickDeadline,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Deadline',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_month),
                  ),
                  child: Text(deadlineText),
                ),
              ),
              const SizedBox(height: 12),

              // Difficulty
              DropdownButtonFormField<Difficulty>(
                value: _difficulty,
                items: Difficulty.values
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          d.name[0].toUpperCase() + d.name.substring(1),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _difficulty = v ?? Difficulty.medium),
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              // Save/Cancel
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
