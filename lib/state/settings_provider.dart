import 'package:flutter/foundation.dart';

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

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings(
    maxHoursPerDay: 8,
    breakMinutes: 30,
    includeWeekends: true,
  );

  AppSettings get settings => _settings;

  void update(AppSettings s) {
    _settings = s;
    notifyListeners();
  }
}
