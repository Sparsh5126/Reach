import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';

class NotificationService {
  static final NotificationService _i = NotificationService._internal();
  factory NotificationService() => _i;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String?> payloadStream =
      StreamController<String?>.broadcast();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        payloadStream.add(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    const alarmChannel = AndroidNotificationChannel(
      'reach_alarm',
      'Leave Now Alarm',
      description: 'Full-screen alarm when it is time to leave',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    const reminderChannel = AndroidNotificationChannel(
      'reach_reminder',
      'Pack Up Reminder',
      description: 'Reminder to start getting ready',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(alarmChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);

    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}

    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  tz.TZDateTime _toTzDateTime(DateTime dt) {
    return tz.TZDateTime.from(dt, tz.local);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleLeaveAlarm(
    int id,
    DateTime targetTime, {
    List<String> days = const [],
    bool isRaining = false,
    bool useFullScreen = false,
  }) async {
    await init();

    final dayMap = {
      "Mon": 1, "Tue": 2, "Wed": 3, "Thu": 4,
      "Fri": 5, "Sat": 6, "Sun": 7,
    };

    final String title =
        isRaining ? '🌧️ RAIN DELAY: LEAVE NOW' : '🚀 LEAVE NOW';
    final String body = isRaining
        ? 'Rain detected! Traffic is slower. Leave immediately to reach on time.'
        : 'Traffic is active. Leave immediately to reach on time.';

    const String payload = 'leave_alarm';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reach_alarm',
        'Leave Now Alarm',
        importance: Importance.max,
        priority: Priority.max, // was Priority.high — needs max for alarms
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        // FIX 8: fullScreenIntent so it shows on lock screen & breaks DND
        fullScreenIntent: useFullScreen,
        // Keeps notification visible even if user swipes (alarm behavior)
        ongoing: useFullScreen,
        autoCancel: !useFullScreen,
      ),
    );

    if (days.isEmpty) {
      final scheduled = _toTzDateTime(targetTime);
      final safeTime = scheduled.isAfter(tz.TZDateTime.now(tz.local))
          ? scheduled
          : tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        safeTime,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    }

    for (int i = 0; i < days.length; i++) {
      final int? weekday = dayMap[days[i]];
      if (weekday == null) continue;

      await _plugin.zonedSchedule(
        id + i,
        title,
        body,
        _nextInstanceOfDayAndTime(weekday, targetTime.hour, targetTime.minute),
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> schedulePackNotification(
    int id,
    String title,
    DateTime targetTime, {
    List<String> days = const [],
  }) async {
    await init();

    final dayMap = {
      "Mon": 1, "Tue": 2, "Wed": 3, "Thu": 4,
      "Fri": 5, "Sat": 6, "Sun": 7,
    };

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reach_reminder',
        'Pack Up Reminder',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    const String payload = 'pack_alarm';

    if (days.isEmpty) {
      final scheduled = _toTzDateTime(targetTime);
      final safeTime = scheduled.isAfter(tz.TZDateTime.now(tz.local))
          ? scheduled
          : tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));

      await _plugin.zonedSchedule(
        id + 100,
        '🎒 GET READY',
        'Start preparing to leave. Traffic check initiated.',
        safeTime,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    }

    for (int i = 0; i < days.length; i++) {
      final int? weekday = dayMap[days[i]];
      if (weekday == null) continue;

      await _plugin.zonedSchedule(
        id + 100 + i,
        '🎒 GET READY',
        'Start preparing to leave. Traffic check initiated.',
        _nextInstanceOfDayAndTime(weekday, targetTime.hour, targetTime.minute),
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> startSimulation() async {
    await init();

    await _plugin.zonedSchedule(
      777,
      '🧪 TEST: LEAVE NOW',
      'Simulation complete. Timezones and alarms are accurate!',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reach_alarm',
          'Leave Now Alarm',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: 'leave_alarm',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> stopAlarm(int id) async {
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(id + i);
      await _plugin.cancel(id + 100 + i);
    }
  }

  Future<void> showTestNotification() async {
    await init();

    await _plugin.show(
      888,
      '🔔 Instant Test',
      'Permissions are working perfectly.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reach_reminder',
          'Pack Up Reminder',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
}