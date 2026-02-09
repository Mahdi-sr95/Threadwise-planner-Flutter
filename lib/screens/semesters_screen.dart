import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/semesters_provider.dart';

class SemestersScreen extends StatefulWidget {
  const SemestersScreen({super.key});

  @override
  State<SemestersScreen> createState() => _SemestersScreenState();
}

class _SemestersScreenState extends State<SemestersScreen> {
  String? _pendingSelectedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize pending selection from provider once
    final semProv = context.read<SemestersProvider>();
    _pendingSelectedId ??= semProv.selectedSemesterId;
  }

  @override
  Widget build(BuildContext context) {
    final semProv = context.watch<SemestersProvider>();
    final semesters = semProv.semesters;

    final selectedId = semProv.selectedSemesterId;
    final pendingId = _pendingSelectedId ?? selectedId;
    final pendingChanged = pendingId != selectedId;

    return Scaffold(
      appBar: AppBar(title: const Text('Semesters')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Current semester',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.school),
                title: Text(semProv.selectedSemester?.name ?? 'Default'),
                subtitle: Text('ID: $selectedId'),
              ),
            ),

            const SizedBox(height: 16),

            // Big central "Add semester" button
            Center(
              child: SizedBox(
                width: 280,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add semester'),
                  onPressed: () => _showAddDialog(context),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'All semesters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            ...semesters.map((s) {
              final isPending = s.id == pendingId;
              final isSelected = s.id == selectedId;

              return Card(
                child: ListTile(
                  leading: Icon(
                    isPending
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(s.name),
                  subtitle: _datesText(s.startDate, s.endDate),
                  onTap: () => setState(() => _pendingSelectedId = s.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Chip(label: Text('Active')),
                        ),
                      if (s.id != SemestersProvider.defaultSemesterId)
                        IconButton(
                          tooltip: 'Delete semester',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await semProv.deleteSemester(s.id);
                            // If we deleted the pending one, reset
                            if (_pendingSelectedId == s.id) {
                              setState(
                                () => _pendingSelectedId =
                                    semProv.selectedSemesterId,
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Confirm + Back row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    onPressed: () => context.go('/courses'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(pendingChanged ? 'Confirm' : 'Continue'),
                    onPressed: () {
                      // Apply selection (even if same), then go back to courses
                      semProv.selectSemester(pendingId);
                      context.go('/courses');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _datesText(DateTime? start, DateTime? end) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (start == null && end == null) return const Text('No dates set');
    if (start != null && end == null) return Text('From ${fmt(start)}');
    if (start == null && end != null) return Text('Until ${fmt(end)}');
    return Text('${fmt(start!)} → ${fmt(end!)}');
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    Future<void> pickStart(StateSetter setState) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 5),
        initialDate: startDate ?? now,
      );
      if (picked != null) {
        setState(
          () => startDate = DateTime(picked.year, picked.month, picked.day),
        );
      }
    }

    Future<void> pickEnd(StateSetter setState) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 5),
        initialDate: endDate ?? now,
      );
      if (picked != null) {
        setState(
          () => endDate = DateTime(picked.year, picked.month, picked.day),
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add semester'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g., Spring 2026',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        startDate == null ? 'Start date' : _d(startDate!),
                      ),
                      onPressed: () => pickStart(setState),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(endDate == null ? 'End date' : _d(endDate!)),
                      onPressed: () => pickEnd(setState),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                await context.read<SemestersProvider>().addSemester(
                  name: name,
                  startDate: startDate,
                  endDate: endDate,
                );

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
