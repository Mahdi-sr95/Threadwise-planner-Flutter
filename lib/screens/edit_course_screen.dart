import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/enums.dart';
import '../state/courses_provider.dart';
import '../state/plan_provider.dart';

class EditCourseScreen extends StatefulWidget {
  final String courseId;

  /// If opened from plan screen, pass from="plan" so we can return there.
  final String? from;

  const EditCourseScreen({super.key, required this.courseId, this.from});

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _studyHoursCtrl = TextEditingController();

  DateTime? _deadline;
  Difficulty _difficulty = Difficulty.medium;

  bool _loadedOnce = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studyHoursCtrl.dispose();
    super.dispose();
  }

  void _prefill(Course c) {
    _nameCtrl.text = c.name;
    _studyHoursCtrl.text = c.studyHours.toString();
    _deadline = DateTime(c.deadline.year, c.deadline.month, c.deadline.day);
    _difficulty = c.difficulty;
    _loadedOnce = true;
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadline ?? now.add(const Duration(days: 7));

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDate: initial,
    );

    if (picked != null) {
      setState(() {
        _deadline = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  void _goBack() {
    if (widget.from == 'plan') {
      context.go('/plan');
    } else {
      context.go('/courses');
    }
  }

  Future<void> _save(Course original) async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_deadline == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a deadline')));
      return;
    }

    final updated = original.copyWith(
      name: _nameCtrl.text.trim(),
      deadline: _deadline!,
      difficulty: _difficulty,
      studyHours: double.parse(_studyHoursCtrl.text.trim()),
    );

    //Update the course
    await context.read<CoursesProvider>().updateCourse(updated);

    // Regenerate the plan if the initial page was plan
    if (widget.from == 'plan') {
      final courses = context.read<CoursesProvider>().courses;
      await context.read<PlanProvider>().generatePlan(courses);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Course updated')));

    _goBack();
  }

  @override
  Widget build(BuildContext context) {
    final coursesProv = context.watch<CoursesProvider>();
    final course = coursesProv.getById(widget.courseId);

    if (course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Course')),
        body: const Center(child: Text('Course not found')),
      );
    }

    if (!_loadedOnce) {
      _prefill(course);
    }

    final deadlineText = _deadline == null
        ? 'Pick a date'
        : _formatDate(_deadline!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Course'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Course name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Course name is required';
                  if (v.trim().length < 2) return 'Too short';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _studyHoursCtrl,
                decoration: const InputDecoration(
                  labelText: 'Study hours needed',
                  border: OutlineInputBorder(),
                  suffixText: 'hours',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Study hours required';
                  final num = double.tryParse(v.trim());
                  if (num == null || num <= 0)
                    return 'Enter a valid positive number';
                  if (num > 200) return 'Too many hours (max 200)';
                  return null;
                },
              ),
              const SizedBox(height: 12),

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

              DropdownButtonFormField<Difficulty>(
                initialValue: _difficulty,
                items: Difficulty.values
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _difficulty = v ?? _difficulty),
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _save(course),
                  child: const Text('Save changes'),
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _goBack,
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
