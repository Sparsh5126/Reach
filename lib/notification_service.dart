import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true);

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(settings);
    
    final platform = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await platform?.requestNotificationsPermission();
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  static Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required TimeOfDay time,
    required bool isUrgent,
  }) async {
    
    final AndroidNotificationDetails androidDetails = isUrgent
        ? const AndroidNotificationDetails(
            'reach_alarm_channel',
            'High Priority Alarms',
            channelDescription: 'Urgent alerts for leaving time',
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            playSound: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          )
        : const AndroidNotificationDetails(
            'reach_standard_channel',
            'Standard Reminders',
            channelDescription: 'Gentle reminders to pack up',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            enableVibration: false,
          );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfDayAndTime(dayOfWeek, time),
      NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }
}