import 'package:device_calendar/device_calendar.dart';

/// Wrapper around [DeviceCalendarPlugin] to keep calendar access logic in one place.
class CalendarImportService {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  Future<bool> requestPermissions() async {
    final result = await _plugin.requestPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  Future<List<Calendar>> getCalendars() async {
    final result = await _plugin.retrieveCalendars();
    return (result.data ?? <Calendar>[]);
  }

  Future<List<Event>> getUpcomingEvents({
    required String calendarId,
    required DateTime from,
    required DateTime to,
  }) async {
    final params = RetrieveEventsParams(startDate: from, endDate: to);

    final result = await _plugin.retrieveEvents(calendarId, params);
    return (result.data ?? <Event>[]);
  }
}
