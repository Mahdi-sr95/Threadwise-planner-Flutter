import 'package:flutter/foundation.dart';

@immutable
class Semester {
  final String id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  Semester({
    String? id,
    required this.name,
    this.startDate,
    this.endDate,
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  Semester copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) {
    return Semester(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: json['id'] as String,
      name: json['name'] as String,
      startDate: (json['startDate'] as String?) == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: (json['endDate'] as String?) == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  String toString() => 'Semester(id: $id, name: $name)';
}
