import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'UI-only for now. Later this will persist to SQLite and drive scheduling.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Max hours per day',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('8 hours'),
                    Slider(
                      value: 8,
                      min: 1,
                      max: 12,
                      divisions: 11,
                      label: '8',
                      onChanged: null, // TODO: update setting
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Break duration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('30 minutes'),
                    Slider(
                      value: 30,
                      min: 0,
                      max: 90,
                      divisions: 18,
                      label: '30',
                      onChanged: null, // TODO: update setting
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Study day hours'),
                subtitle: const Text('09:00 - 21:00'),
                trailing: const Icon(Icons.chevron_right),
                onTap: null, // TODO: pick hours
              ),
            ),

            const SizedBox(height: 12),

            SwitchListTile(
              value: true,
              onChanged: null, // TODO: toggle weekends
              title: const Text('Include weekends'),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Theme'),
                subtitle: const Text('System'),
                trailing: const Icon(Icons.chevron_right),
                onTap: null, // TODO: choose theme
              ),
            ),
          ],
        ),
      ),
    );
  }
}
