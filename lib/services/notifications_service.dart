import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/study_task.dart';
import 'notifications_timezone.dart';

class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance = NotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'study_sessions';
  static const String _channelName = 'Study sessions';
  static const String _channelDesc = 'Reminders when a study session starts';

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.max,
  );

  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    if (!isSupportedPlatform) return;

    await NotificationsTimezone.init();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // در 17.2.4 پارامتر macOS هم وجود دارد
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);

    // Ensure Android channel exists
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_androidChannel);
    }

    _initialized = true;
  }

  Future<bool> requestPermissionsIfNeeded() async {
    if (!isSupportedPlatform) return false;
    if (!_initialized) await init();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      return await mac?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Android 13+ runtime permission
      return await android?.requestNotificationsPermission() ?? true;
    }

    return false;
  }

  NotificationDetails _details() {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  int _idFromKey(String key) {
    final h = key.hashCode & 0x7fffffff;
    return h == 0 ? 1 : h;
  }

  Future<void> scheduleTaskStart({
    required String taskKey,
    required StudyTask task,
    Duration? notifyBefore,
  }) async {
    if (!isSupportedPlatform) return;
    if (!_initialized) await init();

    final now = DateTime.now();
    final whenLocal = task.dateTime.subtract(notifyBefore ?? Duration.zero);
    if (!whenLocal.isAfter(now)) return;

    final tzWhen = NotificationsTimezone.toLocalTzDateTime(whenLocal);
    final id = _idFromKey(taskKey);

    await _plugin.zonedSchedule(
      id,
      'Study session starting',
      '${task.subject}: ${task.task}',
      tzWhen,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTask(String taskKey) async {
    if (!isSupportedPlatform) return;
    if (!_initialized) await init();
    await _plugin.cancel(_idFromKey(taskKey));
  }

  Future<void> cancelAll() async {
    if (!isSupportedPlatform) return;
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }

  Future<void> rescheduleAll({
    required List<StudyTask> tasks,
    required String Function(StudyTask) taskKeyOf,
    Duration? notifyBefore,
  }) async {
    if (!isSupportedPlatform) return;
    if (!_initialized) await init();

    try {
      await cancelAll();

      for (final t in tasks) {
        await scheduleTaskStart(
          taskKey: taskKeyOf(t),
          task: t,
          notifyBefore: notifyBefore,
        );
      }
    } catch (e) {
      // Never crash callers
      debugPrint('rescheduleAll failed: $e');
    }
  }

  Future<void> showNow({required String title, required String body}) async {
    if (!isSupportedPlatform) return;
    if (!_initialized) await init();
    await _plugin.show(999999, title, body, _details());
  }
}
