import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/secrets.dart';
import '../models/ai_course_parse_result.dart';
import '../models/course.dart';
import '../models/enums.dart';
import '../services/ai_course_assistant_service.dart';
import '../services/calendar_import_service.dart';
import '../services/llm_client.dart';
import '../state/courses_provider.dart';

/// A lightweight internal draft model for items imported from the device calendar.
/// User can preview and (un)select drafts before adding them as real Course objects.
class _ImportedCourseDraft {
  final String name;
  final DateTime deadline;
  final Difficulty difficulty;
  final double studyHours;

  const _ImportedCourseDraft({
    required this.name,
    required this.deadline,
    required this.difficulty,
    required this.studyHours,
  });

  Course toCourse() {
    return Course(
      name: name.trim(),
      deadline: DateTime(deadline.year, deadline.month, deadline.day),
      difficulty: difficulty,
      studyHours: studyHours,
    );
  }
}

/// Screen for adding a new course with:
/// - Manual form (name/deadline/difficulty/studyHours)
/// - Optional AI assistant parsing (HuggingFace)
/// - Optional Calendar import (Android/iOS)
class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  // -------------------------
  // Manual form state
  // -------------------------
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _studyHoursCtrl = TextEditingController();

  DateTime? _deadline;
  Difficulty _difficulty = Difficulty.medium;

  // -------------------------
  // AI assistant state
  // -------------------------
  // Must NOT be auto-cleared on incomplete/unrelated; only clear on explicit user action.
  final _aiTextCtrl = TextEditingController();
  bool _aiLoading = false;
  AiCourseParseResult? _aiResult;
  String? _aiError;

  // -------------------------
  // Calendar import state
  // -------------------------
  bool _calLoading = false;
  String? _calError;
  List<_ImportedCourseDraft> _calDrafts = <_ImportedCourseDraft>[];
  final Set<int> _calSelected = <int>{};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studyHoursCtrl.dispose();
    _aiTextCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Helpers
  // -------------------------

  /// Date picker for manual deadline selection.
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

  /// Format date as YYYY-MM-DD.
  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
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

  /// MVP heuristic: suggest hours based on how close the deadline is.
  double _suggestStudyHours(DateTime deadline) {
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    final d1 = DateTime(deadline.year, deadline.month, deadline.day);
    final daysLeft = d1.difference(d0).inDays;

    if (daysLeft <= 3) return 18.0;
    if (daysLeft <= 7) return 15.0;
    if (daysLeft <= 14) return 12.0;
    if (daysLeft <= 30) return 10.0;
    return 8.0;
  }

  // -------------------------
  // Manual save
  // -------------------------

  /// Validate and save the course (manual form).
  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a deadline')),
      );
      return;
    }

    final hours = double.tryParse(_studyHoursCtrl.text.trim());
    if (hours == null || hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid study hours')),
      );
      return;
    }

    final course = Course(
      name: _nameCtrl.text.trim(),
      deadline: _deadline!,
      difficulty: _difficulty,
      studyHours: hours,
    );

    await context.read<CoursesProvider>().addCourse(course);

    if (!mounted) return;
    context.go('/courses');
  }

  // -------------------------
  // AI assistant logic
  // -------------------------

  Future<void> _analyzeAiText() async {
    final token = Secrets.huggingFaceToken.trim();

    if (token.isEmpty) {
      setState(() {
        _aiError =
            'HuggingFace token is empty. Put it in lib/config/secrets.dart (Secrets.huggingFaceToken).';
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

      final msg = e.toString();
      if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
        setState(
          () => _aiError =
              'AI request failed due to network/DNS. Check internet/VPN/Private DNS.\nDetails: $e',
        );
      } else {
        setState(() => _aiError = 'Unexpected error: $e');
      }
    } finally {
      // IMPORTANT: Avoid `return` inside `finally` (control_flow_in_finally).
      if (mounted) {
        setState(() => _aiLoading = false);
      }
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
      // IMPORTANT: Avoid `return` inside `finally` (control_flow_in_finally).
      if (mounted) {
        setState(() => _aiLoading = false);
      }
    }
  }

  // -------------------------
  // Calendar import logic
  // -------------------------

  Future<Calendar?> _pickCalendar(List<Calendar> calendars) async {
    // Filter out unusable calendars (no id).
    final usable = calendars.where((c) => c.id != null).toList();

    return showDialog<Calendar>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Select a calendar'),
          children: [
            SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: usable.length,
                  itemBuilder: (context, i) {
                    final c = usable[i];
                    final title = (c.name ?? 'Unnamed calendar').trim();
                    return SimpleDialogOption(
                      onPressed: () => Navigator.of(ctx).pop(c),
                      child: Text(title.isEmpty ? 'Unnamed calendar' : title),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importFromCalendar() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar import is available on Android/iOS only.')),
      );
      return;
    }

    setState(() {
      _calLoading = true;
      _calError = null;
    });

    try {
      final svc = CalendarImportService();

      final allowed = await svc.requestPermissions();
      if (!allowed) {
        if (!mounted) return;
        setState(() {
          _calError = 'Calendar permission was not granted.';
          _calDrafts = <_ImportedCourseDraft>[];
          _calSelected.clear();
        });
        return;
      }

      final calendars = await svc.getCalendars();
      if (calendars.isEmpty) {
        if (!mounted) return;
        setState(() {
          _calError = 'No calendars found on this device.';
          _calDrafts = <_ImportedCourseDraft>[];
          _calSelected.clear();
        });
        return;
      }

      final pickedCal = await _pickCalendar(calendars);
      if (pickedCal == null || pickedCal.id == null) {
        if (!mounted) return;
        setState(() => _calLoading = false);
        return;
      }

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 120));

      final events = await svc.getUpcomingEvents(
        calendarId: pickedCal.id!,
        from: from,
        to: to,
      );

      final drafts = <_ImportedCourseDraft>[];
      final seen = <String>{};

      for (final e in events) {
        final title = (e.title ?? '').trim();
        final start = e.start;

        if (title.isEmpty || start == null) continue;

        final deadline = DateTime(start.year, start.month, start.day);
        final key = '${title.toLowerCase()}|${_formatDate(deadline)}';

        if (seen.contains(key)) continue;
        seen.add(key);

        drafts.add(
          _ImportedCourseDraft(
            name: title,
            deadline: deadline,
            difficulty: Difficulty.medium,
            studyHours: _suggestStudyHours(deadline),
          ),
        );
      }

      drafts.sort((a, b) => a.deadline.compareTo(b.deadline));

      if (!mounted) return;
      setState(() {
        _calDrafts = drafts;
        _calSelected
          ..clear()
          ..addAll(List<int>.generate(drafts.length, (i) => i)); // default: select all
        _calError = drafts.isEmpty ? 'No usable events found in the selected time range.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calError = 'Calendar import failed: $e';
        _calDrafts = <_ImportedCourseDraft>[];
        _calSelected.clear();
      });
    } finally {
      // IMPORTANT: Avoid `return` inside `finally` (control_flow_in_finally).
      if (mounted) {
        setState(() => _calLoading = false);
      }
    }
  }

  Future<void> _confirmAndAddCalendarDrafts() async {
    if (_calDrafts.isEmpty || _calSelected.isEmpty) return;

    final provider = context.read<CoursesProvider>();

    setState(() {
      _calLoading = true;
      _calError = null;
    });

    try {
      var added = 0;

      final selected = _calSelected.toList()..sort();
      for (final i in selected) {
        if (i < 0 || i >= _calDrafts.length) continue;
        await provider.addCourse(_calDrafts[i].toCourse());
        added++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $added course(s) from calendar.')),
      );

      context.go('/courses');
    } catch (e) {
      if (!mounted) return;
      setState(() => _calError = 'Failed to add imported courses: $e');
    } finally {
      // IMPORTANT: Avoid `return` inside `finally` (control_flow_in_finally).
      if (mounted) {
        setState(() => _calLoading = false);
      }
    }
  }

  // -------------------------
  // UI
  // -------------------------

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
              // AI Assistant
              // -------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add with AI (optional)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Paste a description of your courses/exams. The AI will validate your text and show a preview before adding.',
                      ),
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
                        Text(
                          'Preview (${_aiResult!.courses.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
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
              // Calendar import
              // -------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import from Calendar (Android/iOS)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Import upcoming events and convert them into courses. You can unselect items before adding.',
                      ),
                      const SizedBox(height: 12),
                      if (_calLoading) const LinearProgressIndicator(),
                      if (_calError != null) ...[
                        const SizedBox(height: 10),
                        Text(_calError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _calLoading ? null : _importFromCalendar,
                              icon: const Icon(Icons.calendar_month),
                              label: const Text('Import events'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _calLoading
                                ? null
                                : () {
                                    setState(() {
                                      _calDrafts = <_ImportedCourseDraft>[];
                                      _calSelected.clear();
                                      _calError = null;
                                    });
                                  },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      if (_calDrafts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        Text('Preview (${_calDrafts.length})', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        ...List.generate(_calDrafts.length, (i) {
                          final d = _calDrafts[i];
                          final checked = _calSelected.contains(i);

                          return CheckboxListTile(
                            value: checked,
                            contentPadding: EdgeInsets.zero,
                            onChanged: _calLoading
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _calSelected.add(i);
                                      } else {
                                        _calSelected.remove(i);
                                      }
                                    });
                                  },
                            title: Text(d.name),
                            subtitle: Text(
                              'Deadline: ${_formatDate(d.deadline)}  Difficulty: ${d.difficulty.displayName}  Hours: ${d.studyHours}',
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: (_calLoading || _calSelected.isEmpty) ? null : _confirmAndAddCalendarDrafts,
                            child: Text('Add selected (${_calSelected.length})'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -------------------------
              // Manual form
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
                  final numValue = double.tryParse(v.trim());
                  if (numValue == null || numValue <= 0) return 'Enter a valid positive number';
                  if (numValue > 200) return 'Too many hours (max 200)';
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
                        child: Text(d.name[0].toUpperCase() + d.name.substring(1)),
                      ),
                    )
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
