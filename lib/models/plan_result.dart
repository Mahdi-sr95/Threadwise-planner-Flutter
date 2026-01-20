import 'enums.dart';
import 'study_task.dart';

class PlanResult {
  final List<StudyTask> tasks;
  final InputStatus status;
  final String? errorMessage;
  final DateTime generatedAt;

  PlanResult({
    required this.tasks,
    required this.status,
    this.errorMessage,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  bool get isSuccess => status == InputStatus.complete && errorMessage == null;

  Map<String, dynamic> toJson() {
    return {
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'status': status.name,
      'errorMessage': errorMessage,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  factory PlanResult.fromJson(Map<String, dynamic> json) {
    return PlanResult(
      tasks: (json['tasks'] as List)
          .map((t) => StudyTask.fromJson(t as Map<String, dynamic>))
          .toList(),
      status: InputStatus.values.firstWhere(
        (e) => e.name == json['status'],
      ),
      errorMessage: json['errorMessage'] as String?,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  factory PlanResult.error(String message, InputStatus status) {
    return PlanResult(
      tasks: [],
      status: status,
      errorMessage: message,
    );
  }

  factory PlanResult.success(List<StudyTask> tasks) {
    return PlanResult(
      tasks: tasks,
      status: InputStatus.complete,
    );
  }
}
