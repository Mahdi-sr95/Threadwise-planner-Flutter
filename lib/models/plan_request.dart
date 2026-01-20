import 'enums.dart';

class PlanRequest {
  final String userInput;
  final Strategy strategy;
  final double maxHoursPerDay;
  final int breakMinutes;
  final DateTime? startDate;

  PlanRequest({
    required this.userInput,
    required this.strategy,
    this.maxHoursPerDay = 8.0,
    this.breakMinutes = 15,
    this.startDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'userInput': userInput,
      'strategy': strategy.name,
      'maxHoursPerDay': maxHoursPerDay,
      'breakMinutes': breakMinutes,
      'startDate': startDate?.toIso8601String(),
    };
  }

  factory PlanRequest.fromJson(Map<String, dynamic> json) {
    return PlanRequest(
      userInput: json['userInput'] as String,
      strategy: Strategy.values.firstWhere(
        (e) => e.name == json['strategy'],
      ),
      maxHoursPerDay: (json['maxHoursPerDay'] as num).toDouble(),
      breakMinutes: json['breakMinutes'] as int,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
    );
  }
}
