import 'package:flutter/material.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        actions: [
          IconButton(
            onPressed: null, // TODO: export CSV
            icon: const Icon(Icons.table_view),
            tooltip: 'Export CSV',
          ),
          IconButton(
            onPressed: null, // TODO: export ICS
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Export ICS',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Generated schedule',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This is a UI placeholder. Your generated StudyTasks will appear grouped by day.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.view_agenda_outlined, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No plan yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Generate a plan from the Courses tab.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Example day section',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('09:00 – 11:30'),
                subtitle: const Text(
                  'Mobile Application Development • Flutter basics and widgets',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: null, // TODO: open task details (optional)
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: null, // TODO: regenerate
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
