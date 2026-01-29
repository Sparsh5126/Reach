import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart'; // REQUIRED
import 'dart:io';
import 'dart:async';

@pragma('vm:entry-point')
void packCallback(int id) async {
  final plugin = FlutterLocalNotificationsPlugin();

  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

  await plugin.show(
    id,
    '🎒 GET READY',
    'Start preparing to leave',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'reach_alarm',
        'Critical Alarm',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    ),
  );

  // Chain Leave Alarm (15 mins later)
  final leaveTime = DateTime.now().add(const Duration(minutes: 15));
  await AndroidAlarmManager.oneShotAt(
    leaveTime,
    id + 1,
    leaveCallback,
    exact: true,
    wakeup: true,
    alarmClock: false,
  );
}

@pragma('vm:entry-point')
void leaveCallback(int id) async {
  final plugin = FlutterLocalNotificationsPlugin();
  
  // --- CHECK USER SETTINGS ---
  // We must load prefs here because this runs in the background
  final prefs = await SharedPreferences.getInstance();
  final bool useFullScreen = prefs.getBool('full_screen_alarm') ?? true; // Default: ON

  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

  await plugin.show(
    id,
    '🚀 LEAVE NOW',
    'Traffic is active. Leave immediately to reach on time.',
    NotificationDetails( // Removed 'const' to allow dynamic variable
      android: AndroidNotificationDetails(
        'reach_alarm',
        'Critical Alarm',
        importance: Importance.max,
        priority: Priority.high,
        
        // --- DYNAMIC TOGGLE ---
        fullScreenIntent: useFullScreen, 
        
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
      ),
    ),
    payload: 'ALARM', 
  );
}

class NotificationService {
  static final NotificationService _i = NotificationService._internal();
  factory NotificationService() => _i;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String?> payloadStream = StreamController<String?>.broadcast();
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        payloadStream.add(response.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      'reach_alarm',
      'Critical Alarm',
      importance: Importance.max,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
    }
  }

  Future<void> schedulePackNotification(int id, String title, DateTime targetTime) async {
    final now = DateTime.now();
    if (targetTime.isBefore(now.add(const Duration(minutes: 1)))) {
      targetTime = now.add(const Duration(minutes: 1));
    }
    await AndroidAlarmManager.oneShotAt(
      targetTime,
      id,
      packCallback,
      exact: true,
      wakeup: true,
      alarmClock: false,
    );
  }

  Future<void> scheduleLeaveAlarm(int id, DateTime targetTime) async {
    await AndroidAlarmManager.oneShotAt(
      targetTime,
      id,
      leaveCallback, 
      exact: true,
      wakeup: true,
      alarmClock: true, 
      allowWhileIdle: true,
    );
  }

  Future<void> stopAlarm(int id) async {
    await AndroidAlarmManager.cancel(id);
    await _plugin.cancel(id);
  }
}