import 'study_task.dart';
import 'enums.dart';

/// Saved plan model with timestamp and strategy
/// Allows users to compare different planning strategies
class SavedPlan {
  final String id;
  final Strategy strategy;
  final List<StudyTask> tasks;
  final DateTime createdAt;
  final String? notes;

  SavedPlan({
    String? id,
    required this.strategy,
    required this.tasks,
    DateTime? createdAt,
    this.notes,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'strategy': strategy.name,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  /// Create from JSON
  factory SavedPlan.fromJson(Map<String, dynamic> json) {
    return SavedPlan(
      id: json['id'] as String,
      strategy: Strategy.values.firstWhere(
        (e) => e.name == json['strategy'],
      ),
      tasks: (json['tasks'] as List)
          .map((t) => StudyTask.fromJson(t as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      notes: json['notes'] as String?,
    );
  }

  /// Get formatted date for display
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  /// Get total study hours
  double get totalHours {
    return tasks.fold(0.0, (sum, task) => sum + task.durationHours);
  }

  SavedPlan copyWith({
    String? id,
    Strategy? strategy,
    List<StudyTask>? tasks,
    DateTime? createdAt,
    String? notes,
  }) {
    return SavedPlan(
      id: id ?? this.id,
      strategy: strategy ?? this.strategy,
      tasks: tasks ?? this.tasks,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }
}
