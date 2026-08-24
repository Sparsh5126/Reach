import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/commute_model.dart';
import '../../services/calendar_service.dart';
import '../../services/commute_history_service.dart';
import '../../services/notification_service.dart';
import '../../services/traffic_service.dart';
import '../../services/weather_service.dart';

import '../styles.dart';
import '../widgets/sliding_nav_bar.dart';
import '../widgets/privacy_dialog.dart';
import 'home_view.dart';
import 'add_edit_sheet.dart';
import 'alarm_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Commute> myCommutes = [];
  String? _userName;
  bool _ready = false;
  Position? _currentPosition;
  List<String> _ignoredEventIds = [];
  StreamSubscription<String?>? _notificationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    _notificationSub = NotificationService().payloadStream.stream.listen((
      payload,
    ) {
      if (payload == 'ALARM' && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AlarmScreen(payload: payload!)),
        );
      }
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCalendar();
      _refreshAllAlarms(); // Silent Refresh on resume
    }
  }

  Future<void> _initApp() async {
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint("Notification init error: $e");
    }

    await _loadData();

    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name');
    if (!(prefs.getBool('user_name_prompted') ?? false) && _userName == null) {
      await WidgetsBinding.instance.endOfFrame;
      await _showNamePrompt(prefs);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;
    final hasAcceptedPrivacy = prefs.getBool('has_accepted_privacy') ?? false;

    if (!hasAcceptedPrivacy) {
      if (mounted) {
        await Future.delayed(Duration.zero);
        await PrivacyDialog.show(context);
        await prefs.setBool('has_accepted_privacy', true);
      }
    }

    try {
      await NotificationService().requestPermissions();
    } catch (e) {
      debugPrint("Notification permission request error: $e");
    }

    try {
      await [
        Permission.locationWhenInUse,
        Permission.systemAlertWindow,
        Permission.calendar,
      ].request();
    } catch (e) {
      debugPrint("Permission request error: $e");
    }

    await _determinePosition();
    if (!mounted) return;
    setState(() => _ready = true);

    // Initial Silent Refresh on app start
    _refreshAllAlarms();

    Future.delayed(const Duration(seconds: 1), _checkCalendar);
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    if (mounted) setState(() => _currentPosition = pos);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _ignoredEventIds = prefs.getStringList('ignored_events') ?? [];

    final data = prefs.getString('commutes');
    if (data != null) {
      try {
        if (!mounted) return;
        setState(() {
          myCommutes = (json.decode(data) as List)
              .map((e) => Commute.fromJson(e))
              .toList();
          _sortCommutes();
        });
      } catch (e) {
        debugPrint("Load error: $e");
      }
    }
  }

  Future<void> _showNamePrompt(SharedPreferences prefs) async {
    if (!mounted) return;
    var enteredName = '';
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("What should we call you?"),
        content: _NamePromptField(
          onChanged: (value) => enteredName = value,
          onSubmitted: (name) => Navigator.pop(context, name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              enteredName,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    await prefs.setBool('user_name_prompted', true);
    final trimmedName = name?.trim() ?? '';
    if (trimmedName.isNotEmpty) {
      await prefs.setString('user_name', trimmedName);
      if (mounted) setState(() => _userName = trimmedName);
    }
  }

  static DateTime _nextOccurrence(Commute commute, DateTime now) {
    final time = commute.timeInMinutes;
    final configuredDays = commute.days;
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (var offset = 0; offset < 7; offset++) {
      final date = DateTime(now.year, now.month, now.day + offset);
      if (configuredDays.isNotEmpty &&
          !configuredDays.contains(dayNames[date.weekday - 1])) {
        continue;
      }
      final occurrence = DateTime(date.year, date.month, date.day,
          time ~/ 60, time % 60);
      if (occurrence.isAfter(now)) return occurrence;
    }

    return DateTime(now.year, now.month, now.day + 7, time ~/ 60, time % 60);
  }

  /// Maps weekday int (1=Mon…7=Sun) → short name used in commute.days.
  static const List<String> _weekdayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  String get _todayDayName => _weekdayNames[DateTime.now().weekday - 1];

  /// Derives a stable, bounded notification base ID from a commute's string ID.
  /// Uses a simple djb2-style hash so the result is consistent across app restarts
  /// (unlike Dart's String.hashCode which is randomized per-process).
  /// The result is kept in the range [1, 2^20) to leave plenty of headroom for
  /// the +100 pack offset without overflowing a 32-bit signed int.
  int _stableNotifId(String commuteId) {
    int hash = 5381;
    for (final int codeUnit in commuteId.codeUnits) {
      hash = ((hash << 5) + hash) ^ codeUnit; // hash * 33 ^ c
    }
    // Map to [1, 1_048_576) so we never return 0 and stay far below 2^31.
    return (hash.abs() % 1048576) + 1;
  }

  Future<void> _refreshAllAlarms() async {
    if (!_ready || myCommutes.isEmpty) return;
    debugPrint(
      '[SCHED] Starting silent refresh for ${myCommutes.length} commutes...',
    );
    for (final c in myCommutes) {
      try {
        await _updateCommuteAlarms(c);
      } catch (e) {
        debugPrint(
          '[SCHED] Silent refresh failed for "${c.customTitle ?? c.title}": $e',
        );
      }
    }
    debugPrint('[SCHED] Silent refresh complete.');
  }

  Future<void> _updateCommuteAlarms(Commute c) async {
    if (!_ready) return;

    double startLat = _currentPosition?.latitude ?? c.lat;
    double startLon = _currentPosition?.longitude ?? c.lon;

    // Fetch live data (TrafficService handles 5-min caching internally)
    final results = await Future.wait([
      WeatherService().getWeatherInfo(startLat, startLon),
      TrafficService().getAdjustedTravelDuration(
        startLat,
        startLon,
        c.eLoc,
        destLat: c.lat,
        destLon: c.lon,
        mode: c.mode,
      ),
    ]);

    double rainFactor = ((results[0] as Map)['factor'] as num).toDouble();
    int trafficBuffer = results[1] as int;

    // Apply personalized buffer learned from past commute history.
    final int learnedBuffer = await CommuteHistoryService.getLearnedBuffer(
      c.id,
    );
    if (learnedBuffer > 0) {
      debugPrint(
        '[SCHED] Applying learned buffer: +$learnedBuffer min for "${c.customTitle ?? c.title}"',
      );
      trafficBuffer += learnedBuffer;
    }

    // Use the raw DateTime version to preserve full date context.
    final times = TrafficService().calculateSmartTimesRaw(
      c.title,
      c.time,
      trafficBuffer,
      rainFactor,
      c.mode,
    );

    final DateTime leaveTime = times['leave']!;
    final DateTime readyTime = times['ready']!;
    final DateTime arriveTime = times['arrive']!;
    final bool isRaining = rainFactor > 1.0;

    final int baseId = _stableNotifId(c.id);

    // ── Check if today's alarms are disabled ─────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final bool isDisabledToday =
        prefs.getString('reach_disabled_today_${c.id}') == today ||
        prefs.getString('reach_disabled_all_today') == today;

    // For one-shot commutes (no recurring days) disabled today, skip entirely.
    if (isDisabledToday && c.days.isEmpty) {
      debugPrint(
        '[SCHED] Today disabled for "${c.customTitle ?? c.title}" (one-shot) — skipping scheduling',
      );
      await NotificationService().stopAlarm(baseId);
      return;
    }

    // For recurring commutes, exclude today's day so _nextInstanceOfDayAndTime
    // doesn't re-create an alarm that was just cancelled.
    final List<String> scheduleDays = (isDisabledToday && c.days.isNotEmpty)
        ? c.days.where((d) => d != _todayDayName).toList()
        : c.days;

    // ─────────────────────────────────────────────────────────────────────────

    debugPrint(
      '[SCHED] Updating Alarms: "${c.customTitle ?? c.title}" | baseId=$baseId '
      '| leave=$leaveTime | ready=$readyTime | arrive=$arriveTime '
      '| days=${c.days} | scheduleDays=$scheduleDays | traffic=${trafficBuffer}min | rain=$rainFactor',
    );

    // CRITICAL: Cancel ALL existing notifications for this commute before
    // re-scheduling. Without this, re-scheduling with the same ID but a
    // different time causes Android to silently drop the alarm (the old alarm
    // is cancelled but the new one may not register if the system considers
    // the notification "already scheduled").
    await NotificationService().stopAlarm(baseId);

    // Persist standard preferences (e.g. fullscreen toggle)
    final bool fsEnabled = prefs.getBool('fullscreen_alarm_enabled') ?? true;

    // 1. LEAVE ALARMS (0..6)
    await NotificationService().scheduleLeaveAlarm(
      baseId,
      leaveTime,
      days: scheduleDays,
      isRaining: isRaining,
      useFullScreen: fsEnabled,
    );

    // 2. PACK REMINDERS (100..106)
    await NotificationService().schedulePackNotification(
      baseId,
      c.title,
      readyTime,
      days: scheduleDays,
    );

    // 3. CHECK-IN NOTIFICATIONS (200..206)
    final checkinFireAt = arriveTime.subtract(const Duration(minutes: 5));
    await NotificationService().scheduleCheckinNotification(
      baseId,
      c.id,
      checkinFireAt,
      arriveTime,
      days: scheduleDays,
    );

    // Log pending notifications for this commute (diagnostic)
    await NotificationService().getPendingNotifications();
  }

  Future<void> _saveCommute(Commute c) async {
    // 1. Immediately update UI state and persist to SharedPreferences for zero-latency feedback
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myCommutes.removeWhere((e) => e.id == c.id);
      myCommutes.add(c);
      _sortCommutes();
    });

    await prefs.setString(
      'commutes',
      json.encode(myCommutes.map((e) => e.toMap()).toList()),
    );

    // 2. Schedule live alarms asynchronously in the background, catching any platform/permission errors safely
    try {
      await _updateCommuteAlarms(c);
    } catch (e) {
      debugPrint(
        '[SCHED] Failed to update alarms for "${c.customTitle ?? c.title}": $e',
      );
    }
  }

  void _deleteCommute(int index) async {
    final c = myCommutes[index];
    setState(() => myCommutes.removeAt(index));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'commutes',
      json.encode(myCommutes.map((e) => e.toMap()).toList()),
    );

    final int baseId = _stableNotifId(c.id);
    debugPrint(
      '[SCHED] deleteCommute "${c.customTitle ?? c.title}" | cancelling baseId=$baseId',
    );
    // stopAlarm now also cancels the check-in notification (baseId + 200).
    await NotificationService().stopAlarm(baseId);
    // Clear learned history so deleted commutes don't pollute re-added ones.
    await CommuteHistoryService.clearHistory(c.id);
  }

  void _handleUndo(Commute c, int index) {
    _saveCommute(c);
  }

  /// Cancels today's alarm for a single commute and stores a date-keyed flag
  /// so _updateCommuteAlarms won't re-create it until tomorrow.
  Future<void> _disableTodaysAlarm(Commute c) async {
    final int baseId = _stableNotifId(c.id);
    await NotificationService().cancelTodaysAlarms(baseId, c.days);
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('reach_disabled_today_${c.id}', today);
    debugPrint('[SCHED] Disabled today\'s alarms for "${c.customTitle ?? c.title}"');
  }

  /// Cancels today's alarms for ALL commutes and stores a global date-keyed flag.
  Future<void> _disableAllAlarmsToday() async {
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reach_disabled_all_today', today);
    for (final c in myCommutes) {
      final int baseId = _stableNotifId(c.id);
      await NotificationService().cancelTodaysAlarms(baseId, c.days);
    }
    debugPrint('[SCHED] Disabled all today\'s alarms (${myCommutes.length} commutes)');
  }

  void _toggleFavorite(Commute c) async {
    final updated = c.copyWith(isFavorite: !c.isFavorite);
    // Update state instantly — no network calls needed for a favorite toggle.
    setState(() {
      myCommutes.removeWhere((e) => e.id == updated.id);
      myCommutes.add(updated);
      _sortCommutes();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'commutes',
      json.encode(myCommutes.map((e) => e.toMap()).toList()),
    );
  }

  void _sortCommutes() {
    final now = DateTime.now();
    myCommutes.sort((a, b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return _nextOccurrence(a, now).compareTo(_nextOccurrence(b, now));
    });
  }

  Future<void> _checkCalendar() async {
    if (!_ready) return;
    final events = await CalendarService.getUpcomingTravelEvents();
    final newEvents = events.where((e) {
      final isAlreadyAdded = myCommutes.any((c) => c.title == e.location);
      final isIgnored = _ignoredEventIds.contains(e.eventId);
      return !isAlreadyAdded && !isIgnored;
    }).toList();
    if (newEvents.isNotEmpty && mounted) {
      if (Navigator.of(context).canPop()) return;
      _showEventPopup(newEvents.first);
    }
  }

  void _showEventPopup(CalendarEventResult event) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 30,
              backgroundColor: ReachStyles.primaryOrange,
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "New Event Detected",
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: ReachStyles.primaryOrange,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    event.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _ignoreEvent(event.eventId);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Ignore",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ReachStyles.primaryOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _ignoreEvent(event.eventId);
                      Navigator.pop(context);
                      _addCalendarCommute(event);
                    },
                    child: const Text(
                      "Set Reach Alert",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _addCalendarCommute(CalendarEventResult event) {
    final fullDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final dayIndex = event.startTime.weekday - 1;
    final specificDay = fullDays[dayIndex];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditSheet(
        isSheet: true,
        onSave: (c) {
          _saveCommute(c);
          Navigator.pop(context);
        },
        existingCommute: Commute(
          id: const Uuid().v4(),
          title: event.location,
          customTitle: event.title,
          time: TimeOfDay.fromDateTime(event.startTime).format(context),
          mode: "car",
          days: [specificDay],
          lat: 0.0,
          lon: 0.0,
          eLoc: null,
        ),
      ),
    );
  }

  Future<void> _ignoreEvent(String eventId) async {
    setState(() => _ignoredEventIds.add(eventId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ignored_events', _ignoredEventIds);
  }

  void _openMapPicker(Commute c) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                "Navigate with",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text("Google Maps"),
              onTap: () async {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);

                final title = Uri.encodeComponent(c.title.split(',')[0]);
                Uri url;

                if (c.lat != 0.0 && c.lon != 0.0) {
                  url = Uri.parse("google.navigation:q=${c.lat},${c.lon}");
                } else {
                  url = Uri.parse("geo:0,0?q=$title");
                }

                try {
                  await launchUrl(
                    url,
                    mode: LaunchMode.externalNonBrowserApplication,
                  );
                } catch (e) {
                  final webFallback = Uri.parse(
                    "https://www.google.com/maps/search/?api=1&query=$title",
                  );
                  await launchUrl(
                    webFallback,
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.explore, color: Colors.redAccent),
              title: const Text("Mappls (MapMyIndia)"),
              onTap: () async {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);

                final String dest = (c.eLoc != null && c.eLoc!.isNotEmpty)
                    ? c.eLoc!
                    : "${c.lat},${c.lon}";
                final navUrl = Uri.parse(
                  "mappls://navigation?destination=$dest&destinationName=${Uri.encodeComponent(c.title)}",
                );
                final webFallback = Uri.parse("https://mappls.com/$dest");

                try {
                  if (await canLaunchUrl(navUrl)) {
                    await launchUrl(
                      navUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    await launchUrl(
                      webFallback,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                } catch (e) {
                  await launchUrl(
                    webFallback,
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _editCommute(Commute c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditSheet(
        isSheet: true,
        existingCommute: c,
        onSave: (updated) {
          _saveCommute(updated);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _selectedIndex == 0
                ? HomeView(
                    commutes: myCommutes,
                  userName: _userName,
                    onNameChanged: (name) => setState(() => _userName = name),
                    currentPos: _currentPosition,
                    onEdit: _editCommute,
                    onDelete: _deleteCommute,
                    onUndo: _handleUndo,
                    onNavigate: _openMapPicker,
                    onFavoriteToggle: _toggleFavorite,
                    onDisableAllToday: _disableAllAlarmsToday,
                    onDisableToday: _disableTodaysAlarm,
                  )
                : AddEditSheet(
                    isSheet: false,
                    onSave: (c) {
                      _saveCommute(c);
                      setState(() => _selectedIndex = 0);
                    },
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: SlidingNavBar(
                selectedIndex: _selectedIndex,
                onTabChange: (i) => setState(() => _selectedIndex = i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NamePromptField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _NamePromptField({
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  State<_NamePromptField> createState() => _NamePromptFieldState();
}

class _NamePromptFieldState extends State<_NamePromptField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(hintText: 'Name'),
      onChanged: widget.onChanged,
      onSubmitted: (value) => widget.onSubmitted(value),
    );
  }
}
