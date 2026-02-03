import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';

// -----------------------------------------------------------------------------
// BACKGROUND CALLBACKS
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
void packCallback(int id) async {
  final plugin = FlutterLocalNotificationsPlugin();
  
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

  // 1. Show the Pack Notification
  await plugin.show(
    id,
    '🎒 GET READY',
    'Start preparing to leave.',
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

  // 2. REDUNDANCY: Schedule/Reinforce Leave Alarm (15 mins later)
  // We assume PackID was (BaseID + 1), so LeaveID is (id - 1)
  final leaveTime = DateTime.now().add(const Duration(minutes: 15));
  
  await AndroidAlarmManager.oneShotAt(
    leaveTime,
    id - 1, // Target the main Leave Alarm ID
    leaveCallback,
    exact: true,
    wakeup: true,
    alarmClock: true,
    allowWhileIdle: true,
  );
}

@pragma('vm:entry-point')
void leaveCallback(int id) async {
  final plugin = FlutterLocalNotificationsPlugin();
  
  // --- CHECK USER SETTINGS ---
  // We must load prefs here because this runs in the background isolate
  final prefs = await SharedPreferences.getInstance();
  final bool useFullScreen = prefs.getBool('full_screen_alarm') ?? true; // Default: ON

  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));

  await plugin.show(
    id,
    '🚀 LEAVE NOW',
    'Traffic is active. Leave immediately to reach on time.',
    NotificationDetails(
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

  // Schedule PACK (Ready) Notification
  Future<void> schedulePackNotification(int id, String title, DateTime targetTime) async {
    final now = DateTime.now();
    // Ensure future time
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

  // Schedule LEAVE Alarm
  Future<void> scheduleLeaveAlarm(int id, DateTime targetTime) async {
    // Ensure future time (relative to now)
    final now = DateTime.now();
    if (targetTime.isBefore(now)) {
       // If time passed, assume tomorrow
       targetTime = targetTime.add(const Duration(days: 1));
    }

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