import 'enums.dart';

/// A reusable course template derived ONLY from previously saved plans.
class SavedCourse {
  /// Stable id based on normalized name -> avoids duplicates.
  final String id;

  final String name;
  final Difficulty difficulty;
  final double studyHours;

  final int timesUsed;
  final DateTime lastUsedAt;
  final DateTime createdAt;

  SavedCourse({
    String? id,
    required this.name,
    required this.difficulty,
    required this.studyHours,
    int? timesUsed,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  }) : id = id ?? _makeId(name),
       timesUsed = timesUsed ?? 1,
       lastUsedAt = lastUsedAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  static String _makeId(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  SavedCourse copyWith({
    String? id,
    String? name,
    Difficulty? difficulty,
    double? studyHours,
    int? timesUsed,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  }) {
    return SavedCourse(
      id: id ?? this.id,
      name: name ?? this.name,
      difficulty: difficulty ?? this.difficulty,
      studyHours: studyHours ?? this.studyHours,
      timesUsed: timesUsed ?? this.timesUsed,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'difficulty': difficulty.name,
    'studyHours': studyHours,
    'timesUsed': timesUsed,
    'lastUsedAt': lastUsedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedCourse.fromJson(Map<String, dynamic> json) {
    return SavedCourse(
      id: json['id'] as String,
      name: json['name'] as String,
      difficulty: Difficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
      ),
      studyHours: (json['studyHours'] as num).toDouble(),
      timesUsed: (json['timesUsed'] as num?)?.toInt() ?? 1,
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
