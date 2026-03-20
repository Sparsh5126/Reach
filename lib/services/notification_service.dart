import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _i = NotificationService._internal();
  factory NotificationService() => _i;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String?> payloadStream = StreamController<String?>.broadcast();

  Future<void> init() async {
    // 1. CRITICAL: Initialize Timezone Database to fix the "random time" bug
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        payloadStream.add(response.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      'reach_alarm',
      'Critical Alarm',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestPermissions() async {
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  // --- TIME ZONE HELPERS FOR REPEATING ALARMS ---
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
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

  // ---------------------------------------------------------------------------
  // SMART WEEKLY REPEATING ALARM (Fixes "Never Again" bug)
  // ---------------------------------------------------------------------------
  
  // SCHEDULE "LEAVE NOW"
  Future<void> scheduleLeaveAlarm(int id, DateTime targetTime, {List<String> days = const [], bool isRaining = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final bool useFullScreen = prefs.getBool('full_screen_alarm') ?? true;
    final dayMap = {"Mon": 1, "Tue": 2, "Wed": 3, "Thu": 4, "Fri": 5, "Sat": 6, "Sun": 7};

    // Dynamic Rain Warning
    String title = isRaining ? '🌧️ RAIN DELAY: LEAVE NOW' : '🚀 LEAVE NOW';
    String body = isRaining 
        ? 'Rain detected! Traffic is slower. Leave immediately to reach on time.' 
        : 'Traffic is active. Leave immediately to reach on time.';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reach_alarm', 'Critical Alarm',
        importance: Importance.max, priority: Priority.high,
        playSound: true, enableVibration: true, fullScreenIntent: useFullScreen,
        category: AndroidNotificationCategory.alarm,
      ),
    );

    // If no days selected, default to daily repeat
    if (days.isEmpty) {
      await _plugin.zonedSchedule(
        id, title, body,
        _nextInstanceOfTime(targetTime.hour, targetTime.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeats Daily
      );
      return;
    }

    // Schedule a separate recurring alarm for EACH selected day
    for (int i = 0; i < days.length; i++) {
      int? weekday = dayMap[days[i]];
      if (weekday == null) continue;

      int uniqueId = id + i; // Offset ID for each day to avoid overwriting

      await _plugin.zonedSchedule(
        uniqueId, title, body,
        _nextInstanceOfDayAndTime(weekday, targetTime.hour, targetTime.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock, // Wakes phone up
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeats Weekly!
      );
    }
  }

  // SCHEDULE "PACK UP" (Must also repeat on the selected days)
  Future<void> schedulePackNotification(int id, String title, DateTime targetTime, {List<String> days = const []}) async {
    final dayMap = {"Mon": 1, "Tue": 2, "Wed": 3, "Thu": 4, "Fri": 5, "Sat": 6, "Sun": 7};
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'reach_alarm', 'Critical Alarm',
        importance: Importance.max, priority: Priority.high,
      ),
    );

    if (days.isEmpty) {
      await _plugin.zonedSchedule(
        id + 100, // Offset to not clash with Leave alarms
        '🎒 GET READY', 'Start preparing to leave. Traffic check initiated.',
        _nextInstanceOfTime(targetTime.hour, targetTime.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return;
    }

    for (int i = 0; i < days.length; i++) {
      int? weekday = dayMap[days[i]];
      if (weekday == null) continue;

      await _plugin.zonedSchedule(
        id + 100 + i, 
        '🎒 GET READY', 'Start preparing to leave. Traffic check initiated.',
        _nextInstanceOfDayAndTime(weekday, targetTime.hour, targetTime.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS & SIMULATION
  // ---------------------------------------------------------------------------
  Future<void> startSimulation() async {
    await _plugin.zonedSchedule(
      777,
      '🧪 TEST: LEAVE NOW',
      'Simulation Complete. Timezones and Alarms are accurate!',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reach_alarm', 'Critical Alarm',
          importance: Importance.max, priority: Priority.high,
          fullScreenIntent: true, category: AndroidNotificationCategory.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> stopAlarm(int id) async {
    // Cancel the base ID and up to 10 potential day offsets for both Leave and Pack alarms
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(id + i);
      await _plugin.cancel(id + 100 + i);
    }
  }

  Future<void> showTestNotification() async {
    await _plugin.show(
      888, '🔔 Instant Test', 'Permissions are working perfectly.',
      const NotificationDetails(android: AndroidNotificationDetails('reach_alarm', 'Critical Alarm', importance: Importance.max, priority: Priority.high)),
    );
  }
}