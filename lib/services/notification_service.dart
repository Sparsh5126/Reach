import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'commute_history_service.dart';

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
      debugPrint('[NOTIF] Timezone set to: $tzName');
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      debugPrint('[NOTIF] Timezone fallback to Asia/Kolkata (error: $e)');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[NOTIF] Tapped: id=${response.id}, action=${response.actionId}, payload=${response.payload}');
        // Handle check-in action buttons in the foreground.
        if (response.payload?.startsWith('checkin:') == true) {
          notifHandleCheckin(response);
          return;
        }
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

    const checkinChannel = AndroidNotificationChannel(
      'reach_checkin',
      'Arrival Check-in',
      description: 'Asks whether you reached your destination on time',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(alarmChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);
    await androidPlugin?.createNotificationChannel(checkinChannel);

    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}

    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}

    _isInitialized = true;
    debugPrint('[NOTIF] Service initialized successfully.');
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
    // dt may be a plain DateTime (local). Convert to TZDateTime in tz.local.
    return tz.TZDateTime.from(dt, tz.local);
  }

  /// Returns the next TZDateTime matching [dayOfWeek] (1=Mon…7=Sun),
  /// [hour], [minute]. If that moment today is still in the future, returns
  /// today. Otherwise adds 7 days to get next week's occurrence.
  tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Build candidate: this week, at the target weekday + time.
    // Start from today and walk forward until we hit the right weekday.
    tz.TZDateTime candidate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Advance day-by-day until weekday matches (at most 6 iterations).
    int attempts = 0;
    while (candidate.weekday != dayOfWeek && attempts < 7) {
      candidate = candidate.add(const Duration(days: 1));
      attempts++;
    }

    // If the matched day+time is in the past, jump exactly 7 days ahead.
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }

    return candidate;
  }

  // ---------------------------------------------------------------------------
  // LEAVE ALARM
  // ---------------------------------------------------------------------------

  /// [baseId]    — stable, unique base ID for this commute (caller's responsibility).
  /// [targetTime]— the computed leave time (must be a future DateTime or it will
  ///               be clamped to +5s).
  /// [days]      — list of short day names e.g. ["Mon","Wed"]. Empty = one-shot.
  ///
  /// ID space used:
  ///   one-shot leave  → baseId
  ///   recurring leave → baseId + dayIndex  (0-6)
  Future<void> scheduleLeaveAlarm(
    int baseId,
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
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: useFullScreen,
        ongoing: useFullScreen,
        autoCancel: !useFullScreen,
      ),
    );

    if (days.isEmpty) {
      // One-shot: schedule at exact targetTime.
      final scheduled = _toTzDateTime(targetTime);
      final now = tz.TZDateTime.now(tz.local);
      final safeTime =
          scheduled.isAfter(now) ? scheduled : now.add(const Duration(seconds: 5));

      debugPrint(
          '[NOTIF] scheduleLeaveAlarm ONE-SHOT | id=$baseId | local=${targetTime.toLocal()} | tz=$safeTime');

      await _plugin.zonedSchedule(
        baseId,
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

    // Recurring: one notification per selected day.
    for (int i = 0; i < days.length; i++) {
      final int? weekday = dayMap[days[i]];
      if (weekday == null) continue;

      final int notifId = baseId + i; // leave IDs: baseId, baseId+1, … baseId+6
      final tz.TZDateTime scheduled =
          _nextInstanceOfDayAndTime(weekday, targetTime.hour, targetTime.minute);

      debugPrint(
          '[NOTIF] scheduleLeaveAlarm RECURRING | id=$notifId | day=${days[i]}($weekday) '
          '| time=${targetTime.hour}:${targetTime.minute} | firstFire=$scheduled');

      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        scheduled,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PACK NOTIFICATION
  // ---------------------------------------------------------------------------

  /// [baseId]    — same stable base ID as the leave alarm for this commute.
  ///               Pack IDs are offset by +100 to guarantee separation.
  ///   one-shot pack  → baseId + 100
  ///   recurring pack → baseId + 100 + dayIndex  (0-6)
  Future<void> schedulePackNotification(
    int baseId,
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
    const String packTitle = '🎒 GET READY';
    const String packBody = 'Start preparing to leave. Traffic check initiated.';

    if (days.isEmpty) {
      final scheduled = _toTzDateTime(targetTime);
      final now = tz.TZDateTime.now(tz.local);
      final safeTime =
          scheduled.isAfter(now) ? scheduled : now.add(const Duration(seconds: 5));

      final int notifId = baseId + 100;
      debugPrint(
          '[NOTIF] schedulePackNotification ONE-SHOT | id=$notifId | local=${targetTime.toLocal()} | tz=$safeTime');

      await _plugin.zonedSchedule(
        notifId,
        packTitle,
        packBody,
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

      final int notifId = baseId + 100 + i; // pack IDs: baseId+100, +101, … +106
      final tz.TZDateTime scheduled =
          _nextInstanceOfDayAndTime(weekday, targetTime.hour, targetTime.minute);

      debugPrint(
          '[NOTIF] schedulePackNotification RECURRING | id=$notifId | day=${days[i]}($weekday) '
          '| time=${targetTime.hour}:${targetTime.minute} | firstFire=$scheduled');

      await _plugin.zonedSchedule(
        notifId,
        packTitle,
        packBody,
        scheduled,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // CHECK-IN NOTIFICATION  ("Did you reach?")  — ID: baseId + 200
  // ---------------------------------------------------------------------------

  /// Schedule "Did you reach?" check-in notification(s).
  ///
  /// [days] empty  → one-shot at [fireAt]  (ID: baseId + 200)
  /// [days] non-empty → one recurring notification per weekday
  ///                    (IDs: baseId + 200 .. baseId + 206)
  ///                    Each repeats weekly via matchDateTimeComponents.
  ///
  /// Payload: `checkin:<commuteId>:<arriveEpochMs>`
  Future<void> scheduleCheckinNotification(
    int baseId,
    String commuteId,
    DateTime fireAt,          // for one-shot: exact fire time
    DateTime plannedArriveTime, {
    List<String> days = const [],
  }) async {
    await init();

    final dayMap = {
      "Mon": 1, "Tue": 2, "Wed": 3, "Thu": 4,
      "Fri": 5, "Sat": 6, "Sun": 7,
    };

    final String payload =
        'checkin:$commuteId:${plannedArriveTime.hour}:${plannedArriveTime.minute}';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reach_checkin',
        'Arrival Check-in',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
        actions: [
          AndroidNotificationAction(
            'reached',
            '✅ Reached',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'almost',
            '🕐 Almost There',
            cancelNotification: true,
          ),
        ],
      ),
    );

    if (days.isEmpty) {
      // ONE-SHOT: fires once at the exact computed time.
      final int notifId = baseId + 200;
      final scheduled = _toTzDateTime(fireAt);
      final now = tz.TZDateTime.now(tz.local);
      final safeTime =
          scheduled.isAfter(now) ? scheduled : now.add(const Duration(seconds: 10));

      debugPrint(
          '[NOTIF] scheduleCheckinNotification ONE-SHOT | id=$notifId | fireAt=$safeTime');

      await _plugin.zonedSchedule(
        notifId,
        '📍 Did you reach?',
        'Tap to confirm your arrival.',
        safeTime,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    }

    // RECURRING: one notification per selected weekday, repeats every week.
    // fireAt carries the correct H:M for arrival-5min; we use that time + weekday.
    final checkinHour = fireAt.hour;
    final checkinMinute = fireAt.minute;

    for (int i = 0; i < days.length; i++) {
      final int? weekday = dayMap[days[i]];
      if (weekday == null) continue;

      final int notifId = baseId + 200 + i; // check-in IDs: baseId+200..baseId+206
      final tz.TZDateTime scheduled =
          _nextInstanceOfDayAndTime(weekday, checkinHour, checkinMinute);

      debugPrint(
          '[NOTIF] scheduleCheckinNotification RECURRING | id=$notifId | day=${days[i]}($weekday) '
          '| time=$checkinHour:$checkinMinute | firstFire=$scheduled');

      await _plugin.zonedSchedule(
        notifId,
        '📍 Did you reach?',
        'Tap to confirm your arrival.',
        scheduled,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Cancel all pending check-in notifications for a commute.
  /// Covers both one-shot (baseId+200) and all 7 recurring slots (baseId+200..206).
  Future<void> cancelCheckinNotification(int baseId) async {
    debugPrint('[NOTIF] cancelCheckinNotification | cancelling ${baseId + 200}..${baseId + 206}');
    for (int i = 0; i <= 6; i++) {
      await _plugin.cancel(baseId + 200 + i);
    }
  }

  // ---------------------------------------------------------------------------
  // CANCELLATION
  // ---------------------------------------------------------------------------

  /// Cancels ALL notifications (leave + pack + check-in) for a commute.
  Future<void> stopAlarm(int baseId) async {
    debugPrint('[NOTIF] stopAlarm | baseId=$baseId — cancelling IDs: '
        '$baseId..${baseId + 6}, ${baseId + 100}..${baseId + 106}, ${baseId + 200}..${baseId + 206}');
    // Leave slots: baseId + 0..6
    for (int i = 0; i <= 6; i++) {
      await _plugin.cancel(baseId + i);
    }
    // Pack slots: baseId + 100..106
    for (int i = 0; i <= 6; i++) {
      await _plugin.cancel(baseId + 100 + i);
    }
    // Check-in slots: baseId + 200..206
    for (int i = 0; i <= 6; i++) {
      await _plugin.cancel(baseId + 200 + i);
    }
  }

  // ---------------------------------------------------------------------------
  // INSTANT TEST
  // ---------------------------------------------------------------------------

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

  Future<void> startSimulation() async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    final fireAt = now.add(const Duration(seconds: 15));

    debugPrint('[DEBUG] Starting simulation in 15s (at $fireAt)');

    await _plugin.zonedSchedule(
      999,
      '🚀 SIMULATION: Leave Now',
      'This is a test of the full-screen alarm system.',
      fireAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reach_alarm',
          'Leave Now Alarm',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'ALARM',
    );
  }

  Future<void> testCheckinNotification() async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    final fireAt = now.add(const Duration(seconds: 5));

    // For testing, we set planned arrival to 5 mins ago so 'Reached' shows a delay.
    final plannedArrive = DateTime.now().subtract(const Duration(minutes: 5));

    debugPrint('[DEBUG] Testing Check-in in 5s');

    await scheduleCheckinNotification(
      777,
      'test_commute_id',
      fireAt,
      plannedArrive,
    );
  }

  Future<void> cancelAllNotifications() async {
    await init();
    await _plugin.cancelAll();
    debugPrint('[DEBUG] All notifications cancelled.');
  }
}

// ---------------------------------------------------------------------------
// TOP-LEVEL HANDLERS (must be top-level for background isolate access)
// ---------------------------------------------------------------------------

/// Shared check-in response handler — works in both foreground and background.
/// Parses payload `checkin:<commuteId>:<arriveEpochMs>` and saves outcome.
Future<void> notifHandleCheckin(NotificationResponse response) async {
  final payload = response.payload ?? '';
  if (!payload.startsWith('checkin:')) return;

  final parts = payload.split(':');
  if (parts.length < 4) return; // 'checkin', id, HH, mm

  final commuteId = parts[1];
  final hour = int.tryParse(parts[2]) ?? 0;
  final minute = int.tryParse(parts[3]) ?? 0;

  final now = DateTime.now();
  // Reconstruct planned arrival for the current day.
  DateTime plannedArrive = DateTime(now.year, now.month, now.day, hour, minute);

  // Handle midnight rollover: snap to the occurrence closest to 'now'.
  // If planned is 11:55 PM but it's 12:05 AM, plannedArrive should be 'yesterday'.
  if (plannedArrive.difference(now).inHours > 12) {
    plannedArrive = plannedArrive.subtract(const Duration(days: 1));
  } else if (now.difference(plannedArrive).inHours > 12) {
    plannedArrive = plannedArrive.add(const Duration(days: 1));
  }

  final actionId = response.actionId ?? '';
  final String outcome;
  final int delayMinutes;

  if (actionId == 'reached') {
    outcome = 'reached';
    // Positive = arrived after planned time, negative = early.
    delayMinutes = DateTime.now().difference(plannedArrive).inMinutes;
  } else if (actionId == 'almost') {
    outcome = 'almost';
    // User said "almost" — treat as approximately 10 min late.
    delayMinutes = 10;
  } else {
    // Bare notification tap (no action button) — don't record ambiguous data.
    debugPrint('[NOTIF] Check-in tapped without action — ignoring');
    return;
  }

  debugPrint(
      '[NOTIF] Check-in response | commuteId=$commuteId | outcome=$outcome | delay=$delayMinutes min');

  await CommuteHistoryService.saveOutcome(
    commuteId: commuteId,
    outcome: outcome,
    delayMinutes: delayMinutes,
  );
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Handle check-in action buttons when the app is killed / in background.
  if (response.payload?.startsWith('checkin:') == true) {
    notifHandleCheckin(response);
  }
}