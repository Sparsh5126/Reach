import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

import 'alarm_screen.dart';
import 'commute_model.dart';
import 'add_commute_page.dart';
import 'commute_card.dart';
import 'sliding_nav_bar.dart';
import 'notification_service.dart';
import 'traffic_service.dart';
import 'weather_service.dart';
import 'calendar_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Env load failed: $e");
  }
  await NotificationService().init();
  await CalendarService.init();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  runApp(const ReachApp());
}

class ReachApp extends StatelessWidget {
  const ReachApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme.dark(primary: Colors.orange, secondary: Colors.orangeAccent),
          ),
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
            colorScheme: const ColorScheme.light(primary: Colors.orange, secondary: Colors.orangeAccent, surface: Colors.white),
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

class _MainContainerState extends State<MainContainer> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Commute> myCommutes = [];
  bool _ready = false;
  Position? _currentPosition;
  List<String> _ignoredEventIds = []; // Stores IDs of events we've already handled

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCalendar();
    }
  }

  Future<void> _init() async {
    await _load();
    await [Permission.notification, Permission.locationWhenInUse, Permission.systemAlertWindow, Permission.calendar].request();
    await _determinePosition();
    setState(() => _ready = true);
    // Check calendar after a short delay to ensure UI is ready
    Future.delayed(const Duration(seconds: 1), _checkCalendar);
  }

  Future<void> _checkCalendar() async {
    if (!_ready) return;

    // 1. Fetch upcoming events
    final events = await CalendarService.getUpcomingTravelEvents();
    
    // 2. Filter out events that are EITHER:
    //    a) Already added as a commute (matching title or location)
    //    b) In our "ignored" list
    final newEvents = events.where((e) {
      final isAlreadyAdded = myCommutes.any((c) => c.title == e.location); 
      final isIgnored = _ignoredEventIds.contains(e.eventId);
      return !isAlreadyAdded && !isIgnored;
    }).toList();

    if (newEvents.isNotEmpty && mounted) {
      // Only show popup if no other modal is likely open
      if (Navigator.of(context).canPop() == false) { 
         // Safe to show
      }
      _showEventPopup(newEvents.first);
    }
  }

  // --- Helper to ignore events ---
  Future<void> _ignoreEvent(String eventId) async {
    setState(() {
      _ignoredEventIds.add(eventId);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ignored_events', _ignoredEventIds);
  }

  void _showEventPopup(CalendarEventResult event) {
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const CircleAvatar(radius: 30, backgroundColor: Colors.orange, child: Icon(Icons.calendar_month_rounded, color: Colors.white, size: 30)),
            const SizedBox(height: 20),
            Text("New Event Detected", style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 8),
            Text(event.title, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Flexible(child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800]))),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _ignoreEvent(event.eventId); // Save to ignore list
                      Navigator.pop(context);
                    },
                    child: Text("Ignore", style: TextStyle(color: Colors.grey[600])),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () {
                      _ignoreEvent(event.eventId); // Mark processed
                      Navigator.pop(context);
                      _addCalendarCommute(event);
                    },
                    child: const Text("Set Reach Alert", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      backgroundColor: Colors.transparent, // Allow dynamic sheet styling
      builder: (context) => AddCommutePage(
        isSheet: true, // <--- IMPORTANT: Show as Popup
        onSave: (c) {
          _saveCommute(c);
          Navigator.pop(context);
        },
        existingCommute: Commute(
          id: const Uuid().v4(),
          title: event.location, 
          // Use event title as custom title so user sees "Coffee with John"
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

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position pos = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = pos);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load ignored events
    _ignoredEventIds = prefs.getStringList('ignored_events') ?? [];

    final data = prefs.getString('commutes');
    if (data != null) {
      try {
        setState(() {
          myCommutes = (json.decode(data) as List).map((e) => Commute.fromJson(e)).toList();
          // Sort on load as well
          myCommutes.sort((a, b) {
            if (a.isFavorite != b.isFavorite) {
              return a.isFavorite ? -1 : 1;
            }
            return a.timeInMinutes.compareTo(b.timeInMinutes);
          });
        });
      } catch (e) {
        debugPrint("Load error: $e");
      }
    }
  }

  void _openMapPicker(Commute c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(title: Text("Navigate with", style: TextStyle(fontWeight: FontWeight.bold))),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text("Google Maps"),
              onTap: () async {
                Navigator.pop(context);
                final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(c.title)}");
                if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: const Icon(Icons.explore, color: Colors.redAccent),
              title: const Text("Mappls (MapMyIndia)"),
              onTap: () async {
                Navigator.pop(context);
                final navUrl = Uri.parse("mappls://navigation?destination=${c.eLoc}&destinationName=${Uri.encodeComponent(c.title)}");
                final webFallback = Uri.parse("https://mappls.com/${c.eLoc}");
                try {
                  if (await canLaunchUrl(navUrl)) {
                    await launchUrl(navUrl, mode: LaunchMode.externalApplication);
                  } else {
                    await launchUrl(webFallback, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  await launchUrl(webFallback, mode: LaunchMode.externalApplication);
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
      backgroundColor: Colors.transparent, // NEW: Needed for the new Add Page design
      builder: (context) => AddCommutePage(
        isSheet: true, // <--- IMPORTANT: Show as Popup
        existingCommute: c,
        onSave: (updated) {
          _saveCommute(updated);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _saveCommute(Commute c) async {
    if (!_ready) return;
    int traffic = 35;
    double rain = 0.0;
    double startLat = _currentPosition?.latitude ?? c.lat;
    double startLon = _currentPosition?.longitude ?? c.lon;

    try {
      final res = await Future.wait([
        WeatherService().getWeatherInfo(startLat, startLon),
        TrafficService().getAdjustedTravelDuration(startLat, startLon, c.eLoc),
      ]);
      rain = (res[0] as Map<String, dynamic>)['factor'] ?? 0.0;
      traffic = res[1] as int;
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myCommutes.removeWhere((e) => e.id == c.id);
      myCommutes.add(c);
      
      // NEW SORTING LOGIC: Favorites First, then Time
      myCommutes.sort((a, b) {
        if (a.isFavorite != b.isFavorite) {
          return a.isFavorite ? -1 : 1; // True (Favorite) comes first
        }
        return a.timeInMinutes.compareTo(b.timeInMinutes);
      });
    });
    await prefs.setString('commutes', json.encode(myCommutes.map((e) => e.toMap()).toList()));
  }

  void _deleteCommute(int index) async {
    final c = myCommutes[index];
    setState(() => myCommutes.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('commutes', json.encode(myCommutes.map((e) => e.toMap()).toList()));
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
                    currentPos: _currentPosition, 
                    onDirections: _openMapPicker,
                    onDoubleTap: _editCommute,
                    onDelete: _deleteCommute,
                  )
                : AddCommutePage( // <--- CHANGED: No Align wrapper, full page
                    isSheet: false, // <--- IMPORTANT: Show as Full Page
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

class HomePage extends StatelessWidget {
  final List<Commute> commutes;
  final Position? currentPos;
  final Function(Commute) onDirections;
  final Function(Commute) onDoubleTap;
  final Function(int) onDelete;

  const HomePage({
    super.key,
    required this.commutes,
    this.currentPos,
    required this.onDirections,
    required this.onDoubleTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
        itemCount: commutes.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 25), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text("Reach", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor)),
                      Text(".", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.orange[800])),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                  ),
                ],
              ),
            );
          }
          final c = commutes[index - 1];
          final useLat = currentPos?.latitude ?? c.lat;
          final useLon = currentPos?.longitude ?? c.lon;

          return Dismissible(
            key: Key(c.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => onDelete(index - 1),
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(24)),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 25),
              child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
            ),
            child: _AsyncCommuteCard(commute: c, lat: useLat, lon: useLon, onDirections: onDirections, onDoubleTap: onDoubleTap),
          );
        },
      ),
    );
  }
}

class _AsyncCommuteCard extends StatefulWidget {
  final Commute commute;
  final double lat;
  final double lon;
  final Function(Commute) onDirections;
  final Function(Commute) onDoubleTap;
  const _AsyncCommuteCard({required this.commute, required this.lat, required this.lon, required this.onDirections, required this.onDoubleTap});
  @override
  State<_AsyncCommuteCard> createState() => _AsyncCommuteCardState();
}

class _AsyncCommuteCardState extends State<_AsyncCommuteCard> {
  late Future<Map<String, dynamic>> _dataFuture;
  @override
  void initState() {
    super.initState();
    _dataFuture = Future.wait([
      WeatherService().getWeatherInfo(widget.lat, widget.lon),
      TrafficService().getAdjustedTravelDuration(widget.lat, widget.lon, widget.commute.eLoc),
    ]).then((res) => {'weather': res[0], 'traffic': res[1]});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CommuteCard(
            title: widget.commute.customTitle ?? widget.commute.title,
            arriveBy: widget.commute.time,
            leaveBy: "...",
            readyBy: "...",
            mode: widget.commute.mode,
            days: widget.commute.days,
            weatherEmoji: "",
            isFavorite: widget.commute.isFavorite, // <--- PASSING FAVORITE STATUS
            onTap: () {},
            onDirections: () {},
            onDoubleTap: () {},
          );
        }
        final rain = (snapshot.data!['weather']['factor'] as num).toDouble();
        final traffic = snapshot.data!['traffic'] as int;
        final smart = TrafficService().calculateSmartTimes(widget.commute.title, widget.commute.time, traffic, rain, widget.commute.mode);
        
        return CommuteCard(
          title: widget.commute.customTitle ?? widget.commute.title,
          arriveBy: widget.commute.time,
          leaveBy: smart['leave']!,
          readyBy: smart['ready']!,
          mode: widget.commute.mode,
          days: List<String>.from(widget.commute.days),
          weatherEmoji: snapshot.data!['weather']['emoji'],
          isFavorite: widget.commute.isFavorite, // <--- PASSING FAVORITE STATUS
          onTap: () => widget.onDirections(widget.commute),
          onDirections: () => widget.onDirections(widget.commute),
          onDoubleTap: () => widget.onDoubleTap(widget.commute),
        );
      },
    );
  }
}

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true, backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            title: const Text("Full Screen Alarm"),
            value: _fullScreenAlarm,
            onChanged: (val) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('full_screen_alarm', val);
              setState(() => _fullScreenAlarm = val);
            },
          ),
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: _isDarkMode,
            onChanged: (val) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_dark_mode', val);
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              setState(() => _isDarkMode = val);
            },
          ),
        ],
      ),
    );
  }
}