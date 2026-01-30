import 'package:flutter/foundation.dart';

/// Model for user study preferences and constraints
/// Controls daily limits, break times, and weekend inclusion
class AppSettings {
  final double maxHoursPerDay;
  final int breakMinutes;
  final bool includeWeekends;

  const AppSettings({
    required this.maxHoursPerDay,
    required this.breakMinutes,
    required this.includeWeekends,
  });

  AppSettings copyWith({
    double? maxHoursPerDay,
    int? breakMinutes,
    bool? includeWeekends,
  }) {
    return AppSettings(
      maxHoursPerDay: maxHoursPerDay ?? this.maxHoursPerDay,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      includeWeekends: includeWeekends ?? this.includeWeekends,
    );
  }
}

/// Provider managing user settings state
class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings(
    maxHoursPerDay: 8,
    breakMinutes: 15,
    includeWeekends: true,
  );

  AppSettings get settings => _settings;

  void update(AppSettings s) {
    _settings = s;
    notifyListeners();
  }
}
