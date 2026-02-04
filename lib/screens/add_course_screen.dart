import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/secrets.dart';
import '../models/course.dart';
import '../models/enums.dart';
import '../state/courses_provider.dart';

import '../models/ai_course_parse_result.dart';
import '../services/ai_course_assistant_service.dart';
import '../services/llm_client.dart';

/// Screen for adding a new course with name, deadline, difficulty, and study hours
class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _studyHoursCtrl = TextEditingController();

  // AI assistant input (must NOT be auto-cleared on incomplete/unrelated)
  final _aiTextCtrl = TextEditingController();

  DateTime? _deadline;
  Difficulty _difficulty = Difficulty.medium;

  bool _aiLoading = false;
  AiCourseParseResult? _aiResult;
  String? _aiError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studyHoursCtrl.dispose();
    _aiTextCtrl.dispose();
    super.dispose();
  }

  /// Show date picker dialog for deadline selection
  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
    );

    if (picked != null) {
      setState(() => _deadline = DateTime(picked.year, picked.month, picked.day));
    }
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Validate and save the course (manual form)
  void _save() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a deadline')),
      );
      return;
    }

    final course = Course(
      name: _nameCtrl.text.trim(),
      deadline: _deadline!,
      difficulty: _difficulty,
      studyHours: double.parse(_studyHoursCtrl.text.trim()),
    );

    context.read<CoursesProvider>().addCourse(course);
    context.go('/courses');
  }

  Future<void> _analyzeAiText() async {
    // Read token from the existing Secrets class (do NOT change secrets.dart)
    final token = Secrets.huggingFaceToken.trim();

    if (token.isEmpty) {
      setState(() {
        _aiError = 'HuggingFace token is empty. Put it in lib/config/secrets.dart (Secrets.huggingFaceToken).';
        _aiResult = null;
      });
      return;
    }

    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiResult = null;
    });

    final service = AiCourseAssistantService(
      LLMClient(apiToken: token),
    );

    try {
      final result = await service.analyzeAndExtractCourses(_aiTextCtrl.text);
      if (!mounted) return;
      setState(() => _aiResult = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiError = 'Unexpected error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _aiLoading = false);
    }
  }

  Future<void> _confirmAndAddAiCourses() async {
    final result = _aiResult;
    if (result == null || !result.canAddCourses) return;

    final provider = context.read<CoursesProvider>();

    setState(() {
      _aiLoading = true;
      _aiError = null;
    });

    try {
      for (final draft in result.courses) {
        await provider.addCourse(draft.toCourse());
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${result.courses.length} course(s).')),
      );

      // Do NOT clear AI text automatically.
      context.go('/courses');
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiError = 'Failed to add courses: $e');
    } finally {
      if (!mounted) return;
      setState(() => _aiLoading = false);
    }
  }

  Color _statusColor(InputStatus status, BuildContext context) {
    switch (status) {
      case InputStatus.complete:
        return Colors.green;
      case InputStatus.incomplete:
        return Theme.of(context).colorScheme.secondary;
      case InputStatus.unrelated:
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadlineText = _deadline == null ? 'Pick a date' : _formatDate(_deadline!);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Course')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // -------------------------
              // AI Assistant (NEW section)
              // -------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add with AI (optional)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text('Paste a description of your courses/exams. The AI will validate your text and show a preview before adding.'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _aiTextCtrl,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Describe your courses',
                          hintText:
                              'Example:\nDatabase Systems exam on 2026-02-20 (medium), need 12 hours.\nMobile App Dev on 2026-02-15 (hard), need 20 hours.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_aiLoading) const LinearProgressIndicator(),
                      if (_aiError != null) ...[
                        const SizedBox(height: 10),
                        Text(_aiError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      if (_aiResult != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _aiResult!.message,
                          style: TextStyle(
                            color: _statusColor(_aiResult!.status, context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _aiLoading ? null : _analyzeAiText,
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Analyze & Preview'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _aiLoading
                                ? null
                                : () {
                                    _aiTextCtrl.clear(); // only on explicit user action
                                    setState(() {
                                      _aiResult = null;
                                      _aiError = null;
                                    });
                                  },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      if (_aiResult != null && _aiResult!.canAddCourses) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        Text('Preview (${_aiResult!.courses.length})', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        ..._aiResult!.courses.map(
                          (c) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.school),
                            title: Text(c.name),
                            subtitle: Text(
                              'Deadline: ${c.deadline}  Difficulty: ${c.difficulty.displayName}  Hours: ${c.studyHours}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _aiLoading ? null : _confirmAndAddAiCourses,
                            child: const Text('Confirm & Add courses'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -------------------------
              // Existing manual form (UNCHANGED)
              // -------------------------
              Text('Course details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Enter the course info, then save.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Course name',
                  hintText: 'e.g., Mobile Application Development',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Course name is required';
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Study hours required';
                  final num = double.tryParse(v.trim());
                  if (num == null || num <= 0) return 'Enter a valid positive number';
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
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.name[0].toUpperCase() + d.name.substring(1)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _difficulty = v ?? Difficulty.medium),
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Save')),
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
