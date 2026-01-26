import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/settings_provider.dart';

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
            Text('Max hours/day: ${s.maxHoursPerDay.toStringAsFixed(0)}'),
            Slider(
              value: s.maxHoursPerDay,
              min: 1,
              max: 12,
              divisions: 11,
              onChanged: (v) => prov.update(s.copyWith(maxHoursPerDay: v)),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: s.includeWeekends,
              onChanged: (v) => prov.update(s.copyWith(includeWeekends: v)),
              title: const Text('Include weekends'),
            ),
          ],
        ),
      ),
    );
  }
}
