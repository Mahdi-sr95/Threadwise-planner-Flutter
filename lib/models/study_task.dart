import 'enums.dart';

class StudyTask {
  final String subject;
  final String task;
  final DateTime dateTime;
  final double durationHours;
  final Difficulty difficulty;

  StudyTask({
    required this.subject,
    required this.task,
    required this.dateTime,
    required this.durationHours,
    required this.difficulty,
  });

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'task': task,
      'dateTime': dateTime.toIso8601String(),
      'durationHours': durationHours,
      'difficulty': difficulty.name,
    };
  }

  factory StudyTask.fromJson(Map<String, dynamic> json) {
    return StudyTask(
      subject: json['subject'] as String,
      task: json['task'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      durationHours: (json['durationHours'] as num).toDouble(),
      difficulty: Difficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
      ),
    );
  }

  String get formattedDuration {
    final hours = durationHours.floor();
    final minutes = ((durationHours - hours) * 60).round();
    if (hours == 0) {
      return '${minutes}m';
    } else if (minutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${minutes}m';
    }
  }

  String get formattedDateTime {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'StudyTask(subject: $subject, task: $task, dateTime: $dateTime, duration: $formattedDuration)';
  }
}
