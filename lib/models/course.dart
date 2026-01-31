import 'enums.dart';

/// Course model representing a subject with study requirements
/// Stored locally with custom serialization
class Course {
  final String id;
  final String name;
  final DateTime deadline;
  final Difficulty difficulty;
  final double studyHours;
  final DateTime createdAt;

  Course({
    String? id,
    required this.name,
    required this.deadline,
    required this.difficulty,
    required this.studyHours,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'deadline': deadline.toIso8601String(),
      'difficulty': difficulty.name,
      'studyHours': studyHours,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      name: json['name'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      difficulty: Difficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
      ),
      studyHours: (json['studyHours'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Course copyWith({
    String? id,
    String? name,
    DateTime? deadline,
    Difficulty? difficulty,
    double? studyHours,
    DateTime? createdAt,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      deadline: deadline ?? this.deadline,
      difficulty: difficulty ?? this.difficulty,
      studyHours: studyHours ?? this.studyHours,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Course(id: $id, name: $name, deadline: $deadline, difficulty: ${difficulty.name}, studyHours: $studyHours)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Course && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
