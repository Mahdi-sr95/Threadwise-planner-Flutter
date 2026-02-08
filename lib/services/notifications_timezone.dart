import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Initializes timezone database + sets local location, calls one the app starts

class NotificationsTimezone {
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;

    tz.initializeTimeZones();

    final String localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    _ready = true;
  }

  static tz.TZDateTime toLocalTzDateTime(DateTime dt) {
    // dt is assumed local time
    final loc = tz.local;
    return tz.TZDateTime.from(dt, loc);
  }
}
