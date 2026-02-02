import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/settings_provider.dart';

/// Settings screen for configuring study preferences
/// Allows customization of daily hours, break time, and weekend inclusion
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SettingsProvider>();
    final s = prov.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Daily study hours limit
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Study Limit',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Max hours per day: ${s.maxHoursPerDay.toStringAsFixed(0)}h'),
                    Slider(
                      value: s.maxHoursPerDay,
                      min: 1,
                      max: 12,
                      divisions: 11,
                      label: '${s.maxHoursPerDay.toInt()}h',
                      onChanged: (v) => prov.update(s.copyWith(maxHoursPerDay: v)),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 12),

            // Break time between study sessions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Break Time',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Break between sessions: ${s.breakMinutes} minutes'),
                    Slider(
                      value: s.breakMinutes.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label: '${s.breakMinutes}min',
                      onChanged: (v) => prov.update(s.copyWith(breakMinutes: v.toInt())),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Weekend inclusion toggle
            Card(
              child: SwitchListTile(
                value: s.includeWeekends,
                onChanged: (v) => prov.update(s.copyWith(includeWeekends: v)),
                title: const Text('Include weekends'),
                subtitle: const Text('Schedule study sessions on Saturday and Sunday'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
