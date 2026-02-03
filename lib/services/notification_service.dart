import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';

// -----------------------------------------------------------------------------
// REAL COMMUTE CALLBACKS (Do Not Touch)
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
void packCallback(int id) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

  await plugin.show(
    id,
    '🎒 GET READY',
    'Start preparing to leave. Traffic check initiated.',
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

  // REAL LOGIC: Schedule Leave Alarm 15 mins later
  final leaveTime = DateTime.now().add(const Duration(minutes: 15));
  await AndroidAlarmManager.oneShotAt(
    leaveTime,
    id - 1, 
    leaveCallback,
    exact: true,
    wakeup: true,
    alarmClock: true, 
    allowWhileIdle: true,
  );
}

@pragma('vm:entry-point')
void leaveCallback(int id) async {
  _triggerFullAlarm(id, "🚀 LEAVE NOW", "Traffic is active. Leave immediately.");
}

// -----------------------------------------------------------------------------
// 🧪 SIMULATION CALLBACKS (For Testing Only)
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
void testPackCallback(int id) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

  await plugin.show(
    id,
    '🧪 TEST: GET READY',
    'This simulates the Pack Alarm. Next alarm in 10s...',
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

  // TEST LOGIC: Schedule Leave Alarm 10 SECONDS later (instead of 15 mins)
  final leaveTime = DateTime.now().add(const Duration(seconds: 10));
  await AndroidAlarmManager.oneShotAt(
    leaveTime,
    id - 1, 
    testLeaveCallback, // Calls the test version
    exact: true,
    wakeup: true,
    alarmClock: true, 
    allowWhileIdle: true,
  );
}

@pragma('vm:entry-point')
void testLeaveCallback(int id) async {
  _triggerFullAlarm(id, "🧪 TEST: LEAVE NOW", "Simulation Complete. The chain works!");
}

// Helper to avoid duplicate code
Future<void> _triggerFullAlarm(int id, String title, String body) async {
  final plugin = FlutterLocalNotificationsPlugin();
  final prefs = await SharedPreferences.getInstance();
  final bool useFullScreen = prefs.getBool('full_screen_alarm') ?? true;

  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

  await plugin.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'reach_alarm',
        'Critical Alarm',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: useFullScreen, 
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
      ),
    ),
    payload: 'ALARM', 
  );
}

// -----------------------------------------------------------------------------
// SERVICE CLASS
// -----------------------------------------------------------------------------
class NotificationService {
  static final NotificationService _i = NotificationService._internal();
  factory NotificationService() => _i;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String?> payloadStream = StreamController<String?>.broadcast();

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
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
  }

  // --- START SIMULATION ---
  Future<void> startSimulation() async {
    // Schedules the "Pack" test for 10 seconds from now
    await AndroidAlarmManager.oneShotAt(
      DateTime.now().add(const Duration(seconds: 10)),
      777, // Test ID
      testPackCallback,
      exact: true,
      wakeup: true,
      alarmClock: true,
    );
  }

  Future<void> schedulePackNotification(int id, String title, DateTime targetTime) async {
    final now = DateTime.now();
    if (targetTime.isBefore(now)) targetTime = targetTime.add(const Duration(days: 1));
    await AndroidAlarmManager.oneShotAt(targetTime, id, packCallback, exact: true, wakeup: true, alarmClock: false);
  }

  Future<void> scheduleLeaveAlarm(int id, DateTime targetTime) async {
    final now = DateTime.now();
    if (targetTime.isBefore(now)) targetTime = targetTime.add(const Duration(days: 1));
    await AndroidAlarmManager.oneShotAt(targetTime, id, leaveCallback, exact: true, wakeup: true, alarmClock: true, allowWhileIdle: true);
  }

  Future<void> stopAlarm(int id) async {
    await AndroidAlarmManager.cancel(id);
    await _plugin.cancel(id);
  }
  
  Future<void> showTestNotification() async {
     // Kept for simple instant testing if needed
     await _plugin.show(888, '🔔 Instant Test', 'Permissions are good.', const NotificationDetails(android: AndroidNotificationDetails('reach_alarm', 'Critical Alarm', importance: Importance.max, priority: Priority.high)));
  }
}