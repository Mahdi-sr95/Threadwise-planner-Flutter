import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/enums.dart';
import '../state/courses_provider.dart';
import '../state/semesters_provider.dart';

/// Screen for adding a new course with name, deadline, difficulty, study hours,
/// and (NEW) selecting which semester it belongs to.
class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _studyHoursCtrl = TextEditingController();

  DateTime? _deadline;
  Difficulty _difficulty = Difficulty.medium;

  String? _selectedSemesterId;
  bool _semesterInitDone = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studyHoursCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set default semester once (selected semester if any, else first semester if exists)
    if (!_semesterInitDone) {
      final semProv = context.read<SemestersProvider>();
      final selected = semProv.selectedSemester;
      if (selected != null) {
        _selectedSemesterId = selected.id;
      } else if (semProv.semesters.isNotEmpty) {
        _selectedSemesterId = semProv.semesters.first.id;
      }
      _semesterInitDone = true;
    }
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

    final semProv = context.read<SemestersProvider>();
    final semesterId = _selectedSemesterId ?? semProv.selectedSemester?.id;

    if (semesterId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a semester')));
      return;
    }

    final course = Course(
      name: _nameCtrl.text.trim(),
      deadline: _deadline!,
      difficulty: _difficulty,
      studyHours: double.parse(_studyHoursCtrl.text.trim()),
    );

    context.read<CoursesProvider>().addCourse(course, semesterId: semesterId);

    context.go('/courses');
  }

  @override
  Widget build(BuildContext context) {
    final semProv = context.watch<SemestersProvider>();
    final semesters = semProv.semesters;

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

              // NEW: Semester selector
              if (semesters.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No semesters yet.'),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.go('/semesters'),
                          icon: const Icon(Icons.school),
                          label: const Text('Create a semester'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedSemesterId,
                  items: semesters
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSemesterId = v),
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    border: OutlineInputBorder(),
                    helperText: 'Choose which semester this course belongs to',
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select a semester' : null,
                ),

              const SizedBox(height: 12),

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

              TextFormField(
                controller: _studyHoursCtrl,
                decoration: const InputDecoration(
                  labelText: 'Study hours needed',
                  hintText: 'e.g., 15',
                  border: OutlineInputBorder(),
                  suffixText: 'hours',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                textInputAction: TextInputAction.next,
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
                    setState(() => _difficulty = v ?? Difficulty.medium),
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: semesters.isEmpty ? null : _save,
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
