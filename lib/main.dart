import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alarm_screen.dart';
import 'commute_model.dart';
import 'add_commute_page.dart';
import 'commute_card.dart';
import 'sliding_nav_bar.dart';
import 'notification_service.dart';
import 'traffic_service.dart';
import 'weather_service.dart';

// --- GLOBAL KEYS & NOTIFIERS ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  
  // Load saved theme
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const ReachApp());
}

class ReachApp extends StatelessWidget {
  const ReachApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap with ValueListenableBuilder to listen for theme changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          
          // --- THEME CONFIGURATION ---
          themeMode: currentMode,
          
          // 1. Dark Theme (Original)
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              secondary: Colors.orangeAccent,
            ),
          ),
          
          // 2. Light Theme (New)
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF5F5F7), // Soft grey/white
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              secondary: Colors.orangeAccent,
              surface: Colors.white,
            ),
          ),
          
          home: const MainContainer(),
        );
      },
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;
  List<Commute> myCommutes = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _load();
    await [
      Permission.notification,
      Permission.scheduleExactAlarm,
      Permission.ignoreBatteryOptimizations,
      Permission.locationWhenInUse,
      Permission.systemAlertWindow,
    ].request();

    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await NotificationService().plugin.getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
      if (payload == 'ALARM') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const AlarmScreen(payload: 'ALARM'))
          );
        });
      }
    }

    NotificationService().payloadStream.stream.listen((payload) {
      if (payload == 'ALARM') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const AlarmScreen(payload: 'ALARM'))
        );
      }
    });

    setState(() => _ready = true);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('commutes');
    if (data != null) {
      setState(() {
        myCommutes = (json.decode(data) as List).map((e) => Commute.fromJson(e)).toList();
        myCommutes.sort((a, b) => a.timeInMinutes.compareTo(b.timeInMinutes));
      });
    }
  }

  Future<void> _saveCommute(Commute c) async {
    if (!_ready) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Calculating Traffic..."), duration: Duration(milliseconds: 800))
      );
    }

    final int internalId = c.id.hashCode;
    int traffic = 35;
    double rain = 0.0;

    try {
      final res = await Future.wait([
        WeatherService().getWeatherInfo(c.lat, c.lon),
        TrafficService().getAdjustedTravelDuration(c.lat, c.lon),
      ]);
      rain = (res[0] as Map<String, dynamic>)['factor'] ?? 0.0;
      traffic = res[1] as int;
    } catch (_) {}

    final times = TrafficService().calculateSmartTimes(
      c.title,
      c.time,
      traffic,
      rain,
      c.mode,
    );

    DateTime parseTime(String t) {
        final match = RegExp(r'(\d+):(\d+)\s+(AM|PM)').firstMatch(t);
        if (match == null) return DateTime.now().add(const Duration(minutes: 10));

        int h = int.parse(match.group(1)!);
        int m = int.parse(match.group(2)!);
        if (match.group(3) == "PM" && h < 12) h += 12;
        if (match.group(3) == "AM" && h == 12) h = 0;

        final now = DateTime.now();
        DateTime d = DateTime(now.year, now.month, now.day, h, m);
        if (d.isBefore(now)) d = d.add(const Duration(days: 1)); 
        return d;
    }

    final DateTime leaveTime = parseTime(times['leave']!);
    final DateTime packTime = parseTime(times['ready']!);

    // 1. Pack
    await NotificationService().schedulePackNotification(
      internalId,
      c.title,
      packTime,
    );

    // 2. Leave
    await NotificationService().scheduleLeaveAlarm(
      internalId,
      leaveTime,
    );

    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      myCommutes.removeWhere((e) => e.id == c.id);
      myCommutes.add(c);
      myCommutes.sort((a, b) => a.timeInMinutes.compareTo(b.timeInMinutes));
    });
    
    await prefs.setString(
      'commutes',
      json.encode(myCommutes.map((e) => e.toJson()).toList()),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => _selectedIndex = 0);
    }
  }

  void _deleteCommute(int index) async {
    final c = myCommutes[index];
    setState(() => myCommutes.removeAt(index));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'commutes',
      json.encode(myCommutes.map((e) => e.toJson()).toList()),
    );
    
    await NotificationService().stopAlarm(c.id.hashCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _selectedIndex == 0
                ? HomePage(
                    commutes: myCommutes,
                    onSave: _saveCommute,
                    onDelete: _deleteCommute,
                  )
                : AddCommutePage(onSave: _saveCommute),
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

// ===================================================================
// SETTINGS PAGE
// ===================================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _fullScreenAlarm = true;
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fullScreenAlarm = prefs.getBool('full_screen_alarm') ?? true;
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    });
  }

  Future<void> _toggleAlarmType(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('full_screen_alarm', value);
    setState(() => _fullScreenAlarm = value);
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    setState(() => _isDarkMode = value);
    
    // Update global app theme
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: Colors.transparent, 
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "PREFERENCES",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          
          // 1. FULL SCREEN ALARM TOGGLE
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: SwitchListTile(
              title: const Text("Full Screen Alarm"),
              subtitle: const Text("Wake up screen when alarm fires"),
              secondary: const Icon(Icons.screen_lock_portrait),
              value: _fullScreenAlarm,
              activeColor: Colors.orange,
              onChanged: _toggleAlarmType,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 2. THEME TOGGLE
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: SwitchListTile(
              title: const Text("Dark Mode"),
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              value: _isDarkMode,
              activeColor: Colors.purpleAccent,
              onChanged: _toggleTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final List<Commute> commutes;
  final Function(Commute) onSave;
  final Function(int) onDelete;

  const HomePage({
    super.key,
    required this.commutes,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Check theme for text color logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
        itemCount: commutes.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text("Reach", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor)),
                        Text(".", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.orange[800])),
                      ],
                    ),
                    
                    // --- SETTINGS BUTTON ---
                    IconButton(
                      icon: Icon(Icons.settings, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 25),
              ],
            );
          }

          final c = commutes[index - 1];

          return Dismissible(
            key: Key(c.id),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) => onDelete(index - 1),
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(24)),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 25),
              child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
            ),
            child: FutureBuilder<Map<String, dynamic>>(
               future: Future.wait<dynamic>([
                  WeatherService().getWeatherInfo(c.lat, c.lon),
                  TrafficService().getAdjustedTravelDuration(c.lat, c.lon),
                ]).then((res) {
                  return {'weather': res[0], 'traffic': res[1]};
                }),
              builder: (context, snapshot) {
                  double rain = 0.0;
                  int traffic = 35;
                  String emoji = "";
                  
                  if (snapshot.hasData) {
                    final w = snapshot.data!['weather'] as Map<String, dynamic>;
                    rain = (w['factor'] as num).toDouble();
                    emoji = w['emoji'] ?? "";
                    traffic = snapshot.data!['traffic'] as int;
                  }

                  final smart = TrafficService().calculateSmartTimes(
                    c.title, c.time, traffic, rain, c.mode
                  );

                  return CommuteCard(
                  title: c.title,
                  arriveBy: c.time,
                  leaveBy: smart['leave']!,
                  readyBy: smart['ready']!,
                  mode: c.mode,
                  days: c.days is List ? List<String>.from(c.days) : [c.days.toString()],
                  weatherEmoji: emoji,
                  onTap: () async {
                    final uri = Uri.parse("google.navigation:q=${c.lat},${c.lon}");
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  onDoubleTap: () {
                    showModalBottomSheet(
                      context: context, 
                      isScrollControlled: true,
                      builder: (context) => AddCommutePage(
                        existingCommute: c, 
                        onSave: (u) { onSave(u); Navigator.pop(context); }
                      ),
                    );
                  },
                );
              }
            ),
          );
        },
      ),
    );
  }
}