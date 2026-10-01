import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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
        if (response.payload?.startsWith('leave_alarm:') == true) {
          notifHandleLeave(response.payload!);
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

    // Only the in-app notification permission dialog here. Exact-alarms and
    // full-screen-intent both navigate straight to a system Settings screen
    // (no in-app dialog) — those are requested later via requestPermissions(),
    // after the privacy dialog has been accepted, not unconditionally at
    // cold start before any UI has even rendered.
    try {
      await androidPlugin?.requestNotificationsPermission();
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
      await androidPlugin?.requestFullScreenIntentPermission();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // TIMEZONE HELPERS
  // ---------------------------------------------------------------------------


  /// Converts an existing DateTime to TZDateTime.
  /// Used only for one-shot scheduling where the full date matters.
  tz.TZDateTime _toTzDateTime(DateTime dt) {
    return tz.TZDateTime.from(dt, tz.local);
  }

  /// Returns the next TZDateTime matching [dayOfWeek] (1=Mon…7=Sun),
  /// [hour], [minute]. If that moment today is still in the future, returns
  /// today. Otherwise adds 7 days to get next week's occurrence.
  tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    final DateTime deviceNow = DateTime.now();

    // Build candidate using standard local DateTime
    DateTime candidate = DateTime(
      deviceNow.year,
      deviceNow.month,
      deviceNow.day,
      hour,
      minute,
    );

    // Advance day-by-day until weekday matches (at most 6 iterations).
    int attempts = 0;
    while (candidate.weekday != dayOfWeek && attempts < 7) {
      candidate = candidate.add(const Duration(days: 1));
      attempts++;
    }

    // If the matched day+time is in the past, jump exactly 7 days ahead.
    if (!candidate.isAfter(deviceNow)) {
      candidate = candidate.add(const Duration(days: 7));
    }

    return tz.TZDateTime.from(candidate, tz.local);
  }

  // ---------------------------------------------------------------------------
  // DAY MAP (shared)
  // ---------------------------------------------------------------------------
  static const Map<String, int> _dayMap = {
    "Mon": 1, "Tue": 2, "Wed": 3, "Thu": 4,
    "Fri": 5, "Sat": 6, "Sun": 7,
  };

  // ---------------------------------------------------------------------------
  // LEAVE ALARM
  // ---------------------------------------------------------------------------

  /// [baseId]    — stable, unique base ID for this commute (caller's responsibility).
  /// [targetTime]— the computed leave time (must be a future DateTime or it will
  ///               be skipped for one-shot).
  /// [days]      — list of short day names e.g. ["Mon","Wed"]. Empty = one-shot.
  ///
  /// ID space used:
  ///   one-shot leave  → baseId
  ///   recurring leave → baseId + dayIndex  (0-6)
  Future<void> scheduleLeaveAlarm(
    int baseId,
    String commuteId,
    String mode,
    DateTime targetTime, {
    List<String> days = const [],
    bool isRaining = false,
    bool useFullScreen = false,
  }) async {
    await init();

    final String title =
        isRaining ? '🌧️ RAIN DELAY: LEAVE NOW' : 'LEAVE NOW';
    final String body = isRaining
        ? 'Rain detected! Traffic is slower. Leave immediately to reach on time.'
        : 'Traffic is active. Leave immediately to reach on time.';

    final String payload = 'leave_alarm:$commuteId:$mode';

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

      // If the leave time has already passed, cancel any stale notification
      // and skip. Do NOT fire immediately — that causes random spurious alarms.
      if (!scheduled.isAfter(now)) {
        debugPrint(
            '[NOTIF] scheduleLeaveAlarm ONE-SHOT SKIPPED (past) | id=$baseId '
            '| target=${targetTime.toLocal()} | now=$now');
        await _plugin.cancel(baseId);
        return;
      }

      debugPrint(
          '[NOTIF] scheduleLeaveAlarm ONE-SHOT | id=$baseId '
          '| fireAt=$scheduled (in ${scheduled.difference(now).inMinutes} min)');

      await _plugin.zonedSchedule(
        baseId,
        title,
        body,
        scheduled,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    }

    // Recurring: one notification per selected day.
    // IMPORTANT: Extract hour/minute from the computed time and use
    // _nextInstanceOfDayAndTime to find the correct future fire time.
    // This is independent of what date calculateSmartTimesRaw put on the DateTime.
    final localTime = targetTime.isUtc ? targetTime.toLocal() : targetTime;
    final int targetHour = localTime.hour;
    final int targetMinute = localTime.minute;

    for (int i = 0; i < days.length; i++) {
      final int? weekday = _dayMap[days[i]];
      if (weekday == null) continue;

      final int notifId = baseId + i; // leave IDs: baseId, baseId+1, … baseId+6
      final tz.TZDateTime scheduled =
          _nextInstanceOfDayAndTime(weekday, targetHour, targetMinute);

      debugPrint(
          '[NOTIF] scheduleLeaveAlarm RECURRING | id=$notifId | day=${days[i]}($weekday) '
          '| time=$targetHour:${targetMinute.toString().padLeft(2, '0')} | firstFire=$scheduled');

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
    const String packTitle = 'GET READY';
    const String packBody = 'Start preparing to leave. Traffic check initiated.';

    if (days.isEmpty) {
      final scheduled = _toTzDateTime(targetTime);
      final now = tz.TZDateTime.now(tz.local);
      final int notifId = baseId + 100;

      // Skip if already in the past — do not fire a spurious instant notification.
      if (!scheduled.isAfter(now)) {
        debugPrint(
            '[NOTIF] schedulePackNotification ONE-SHOT SKIPPED (past) | id=$notifId '
            '| target=${targetTime.toLocal()} | now=$now');
        await _plugin.cancel(notifId);
        return;
      }

      debugPrint(
          '[NOTIF] schedulePackNotification ONE-SHOT | id=$notifId '
          '| fireAt=$scheduled (in ${scheduled.difference(now).inMinutes} min)');

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
      );
      return;
    }

    // Recurring: use hour/minute from the computed pack time.
    final localTime = targetTime.isUtc ? targetTime.toLocal() : targetTime;
    final int targetHour = localTime.hour;
    final int targetMinute = localTime.minute;

    for (int i = 0; i < days.length; i++) {
      final int? weekday = _dayMap[days[i]];
      if (weekday == null) continue;

      final int notifId = baseId + 100 + i; // pack IDs: baseId+100, +101, … +106
      final tz.TZDateTime scheduled =
          _nextInstanceOfDayAndTime(weekday, targetHour, targetMinute);

      debugPrint(
          '[NOTIF] schedulePackNotification RECURRING | id=$notifId | day=${days[i]}($weekday) '
          '| time=$targetHour:${targetMinute.toString().padLeft(2, '0')} | firstFire=$scheduled');

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
    String mode,
    DateTime fireAt,          // for one-shot: exact fire time
    DateTime plannedArriveTime, {
    List<String> days = const [],
  }) async {
    await init();

    final String payload =
        'checkin:$commuteId:$mode:${plannedArriveTime.hour}:${plannedArriveTime.minute}';

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
            'Reached',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'almost',
            'Almost There',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'cancelled',
            'Trip Cancelled',
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

      // Skip if already in the past — do not fire a spurious instant notification.
      if (!scheduled.isAfter(now)) {
        debugPrint(
            '[NOTIF] scheduleCheckinNotification ONE-SHOT SKIPPED (past) | id=$notifId '
            '| target=${fireAt.toLocal()} | now=$now');
        await _plugin.cancel(notifId);
        return;
      }

      debugPrint(
          '[NOTIF] scheduleCheckinNotification ONE-SHOT | id=$notifId '
          '| fireAt=$scheduled (in ${scheduled.difference(now).inMinutes} min)');

      await _plugin.zonedSchedule(
        notifId,
        'Did you reach?',
        'Tap to confirm your arrival.',
        scheduled,
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
    final localFireAt = fireAt.isUtc ? fireAt.toLocal() : fireAt;
    final checkinHour = localFireAt.hour;
    final checkinMinute = localFireAt.minute;

    for (int i = 0; i < days.length; i++) {
      final int? weekday = _dayMap[days[i]];
      if (weekday == null) continue;

      final int notifId = baseId + 200 + i; // check-in IDs: baseId+200..baseId+206
      final tz.TZDateTime scheduled =
          _nextInstanceOfDayAndTime(weekday, checkinHour, checkinMinute);

      debugPrint(
          '[NOTIF] scheduleCheckinNotification RECURRING | id=$notifId | day=${days[i]}($weekday) '
          '| time=$checkinHour:${checkinMinute.toString().padLeft(2, '0')} | firstFire=$scheduled');

      await _plugin.zonedSchedule(
        notifId,
        'Did you reach?',
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

  /// Cancels ONLY today's notification slot(s) for a commute.
  ///
  /// For recurring commutes ([days] non-empty): finds the index of today's
  /// weekday in [days] and cancels that single slot for leave, pack, check-in.
  /// Future weekly occurrences are unaffected — Android's
  /// matchDateTimeComponents keeps the other day-slots active as normal.
  ///
  /// For one-shot commutes ([days] empty): cancels the base IDs (baseId,
  /// baseId+100, baseId+200).
  Future<void> cancelTodaysAlarms(int baseId, List<String> days) async {
    await init();
    final int today = DateTime.now().weekday; // 1 = Mon … 7 = Sun

    if (days.isEmpty) {
      // One-shot commute — just cancel the three single IDs.
      debugPrint('[NOTIF] cancelTodaysAlarms ONE-SHOT | cancelling ids: '
          '$baseId, ${baseId + 100}, ${baseId + 200}');
      await _plugin.cancel(baseId);
      await _plugin.cancel(baseId + 100);
      await _plugin.cancel(baseId + 200);
      return;
    }

    // Recurring — find the slot for today's weekday.
    for (int i = 0; i < days.length; i++) {
      final int? weekday = _dayMap[days[i]];
      if (weekday == today) {
        debugPrint('[NOTIF] cancelTodaysAlarms RECURRING | day=${days[i]} '
            '| cancelling ids: ${baseId + i}, ${baseId + 100 + i}, ${baseId + 200 + i}');
        await _plugin.cancel(baseId + i);
        await _plugin.cancel(baseId + 100 + i);
        await _plugin.cancel(baseId + 200 + i);
        return;
      }
    }
    debugPrint('[NOTIF] cancelTodaysAlarms | today (weekday=$today) not in days=$days — nothing to cancel');
  }


  // ---------------------------------------------------------------------------
  // DEBUG: List all pending notifications
  // ---------------------------------------------------------------------------

  /// Returns a list of all currently pending notification details for debugging.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('[NOTIF] === ${pending.length} PENDING NOTIFICATIONS ===');
    for (final n in pending) {
      debugPrint('[NOTIF]   id=${n.id} | title=${n.title} | payload=${n.payload}');
    }
    return pending;
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

Future<void> notifHandleLeave(String payload) async {
  if (!payload.startsWith('leave_alarm:')) return;
  final parts = payload.split(':');
  if (parts.length < 3) return;
  
  final commuteId = parts[1];
  final mode = parts[2];
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('reach_depart_time_${commuteId}_$mode', DateTime.now().millisecondsSinceEpoch);
  debugPrint('[NOTIF] Leave recorded for $commuteId ($mode) at ${DateTime.now()}');
}

/// Shared check-in response handler — works in both foreground and background.
/// Parses payload `checkin:<commuteId>:<mode>:<arriveHour>:<arriveMinute>` and saves outcome.
Future<void> notifHandleCheckin(NotificationResponse response) async {
  final payload = response.payload ?? '';
  if (!payload.startsWith('checkin:')) return;

  final parts = payload.split(':');
  if (parts.length < 5) return; // 'checkin', id, mode, HH, mm

  // parts[3]/parts[4] are the scheduled HH/mm. They are not read here: the
  // elapsed time comes from the stored 'reach_depart_time_*' timestamp below,
  // not from the scheduled time. Still required in the payload, hence the
  // length check above.
  final commuteId = parts[1];
  final mode = parts[2];

  final actionId = response.actionId ?? '';
  if (actionId == 'cancelled') {
    // The trip didn't happen: drop the departure timestamp so nothing is
    // recorded into history (it would otherwise skew the learned travel time).
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('reach_depart_time_${commuteId}_$mode');
    debugPrint('[NOTIF] Trip cancelled by user | commuteId=$commuteId | mode=$mode — not recorded.');
    return;
  }
  if (actionId != 'reached') {
    debugPrint('[NOTIF] Check-in tapped without "reached" action — ignoring tracking.');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final int? departTs = prefs.getInt('reach_depart_time_${commuteId}_$mode');
  
  if (departTs == null) {
    debugPrint('[NOTIF] No departure time found for $commuteId ($mode). Trip not recorded.');
    return;
  }

  final departTime = DateTime.fromMillisecondsSinceEpoch(departTs);
  final arriveTime = DateTime.now();
  
  // Calculate actual duration in minutes
  final actualMinutes = arriveTime.difference(departTime).inMinutes;

  // Since we don't have the exact mappls duration from when they left at hand,
  // we can use a baseline or we can clear this since our history doesn't strictly 
  // require mapplsMinutes for the actuals (it's stored for reference).
  // I'll just pass the actual minutes as both for now, or use a heuristic.
  // Wait, let's just use the median of history or standard map duration if needed, 
  // but let's just log it.
  await CommuteHistoryService.recordActualTravel(
    commuteId: commuteId,
    mode: mode,
    actualMinutes: actualMinutes,
    mapplsMinutes: actualMinutes, // Fallback if we don't track original map duration
  );
  
  // Clear the depart time
  await prefs.remove('reach_depart_time_${commuteId}_$mode');

  debugPrint(
      '[NOTIF] Check-in response | commuteId=$commuteId | mode=$mode | actual=$actualMinutes min');
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  if (response.payload?.startsWith('checkin:') == true) {
    notifHandleCheckin(response);
  } else if (response.payload?.startsWith('leave_alarm:') == true) {
    notifHandleLeave(response.payload!);
  }
}