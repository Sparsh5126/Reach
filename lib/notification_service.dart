import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);

    // Requesting permission for Android 13+ notifications
    if (Platform.isAndroid) {
      await _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
  }

  // 🎒 PACK NOTIFICATION (Gentle)
  Future<void> schedulePackNotification(int id, String title, DateTime time) async {
    try {
      await _plugin.zonedSchedule(
        id,
        '🎒 Get Ready: $title',
        'Time to pack! You leave in 10 minutes.',
        tz.TZDateTime.from(time, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'pack_channel', 'Pack Alerts',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint("Pack scheduling failed: $e");
    }
  }

  // 🚀 LEAVE ALARM (High Priority)
  Future<void> scheduleLeaveAlarm(int id, String title, DateTime time) async {
    try {
      await _plugin.zonedSchedule(
        id + 100,
        '🚀 LEAVE NOW: $title',
        'Traffic is moving. Time to hit the road!',
        tz.TZDateTime.from(time, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_channel', 'Leave Alarms',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('dismiss_id', 'Dismiss', showsUserInterface: false),
            ],
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Fails here without permission
      );
    } catch (e) {
      debugPrint("Leave alarm failed: $e");
    }
  }

  Future<void> cancelAll() async => await _plugin.cancelAll();
  
  Future<void> stopAlarm(int id) async {
    await _plugin.cancel(id + 100);
  }
}