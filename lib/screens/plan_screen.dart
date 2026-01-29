import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/plan_provider.dart';

/// Main screen that displays the generated study plan as a list of tasks.
/// This screen listens to PlanProvider for state changes (loading, error, tasks).
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch PlanProvider to rebuild when state changes
    final planProv = context.watch<PlanProvider>();

    return Scaffold(
      // AppBar shows current strategy label
      appBar: AppBar(title: Text('Plan (${planProv.strategy.label})')),
      body: SafeArea(
        child: planProv.loading
            // Show loading indicator while generating plan
            ? const Center(child: CircularProgressIndicator())
            : planProv.error != null
                // Show error message if generation failed
                ? Center(child: Text(planProv.error!))
                : planProv.tasks.isEmpty
                    // Show empty state message when no tasks exist
                    ? const Center(
                        child: Text(
                          'No tasks yet. Generate a plan from Courses tab.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    // Display list of tasks when available
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: planProv.tasks.length,
                        itemBuilder: (context, index) {
                          final task = planProv.tasks[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              // Task number badge
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Task description as title
                              title: Text(
                                task.task,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              // Task details as subtitle
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Subject name
                                    Text(
                                      'Subject: ${task.subject}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    // Scheduled date and time
                                    Text(
                                      'Date: ${task.formattedDateTime}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    // Duration in hours and minutes
                                    Text(
                                      'Duration: ${task.formattedDuration}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    // Difficulty level
                                    Text(
                                      'Difficulty: ${task.difficulty.name}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _getDifficultyColor(task.difficulty.name),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  /// Helper method to assign color based on difficulty level
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
