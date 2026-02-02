import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

// MODELS & SERVICES
import '../../models/commute_model.dart';
import '../../services/calendar_service.dart';
import '../../services/notification_service.dart';
import '../../services/traffic_service.dart';
import '../../services/weather_service.dart';

// UI COMPONENTS
import '../styles.dart';
import '../widgets/sliding_nav_bar.dart';
import 'home_view.dart';
import 'add_edit_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  // STATE VARIABLES
  int _selectedIndex = 0;
  List<Commute> myCommutes = [];
  bool _ready = false;
  Position? _currentPosition;
  List<String> _ignoredEventIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // APP LIFECYCLE: Check calendar when app resumes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCalendar();
    }
  }

  // -------------------------------------------------------------------------
  // INITIALIZATION LOGIC
  // -------------------------------------------------------------------------
  Future<void> _initApp() async {
    await _loadData();
    await [
      Permission.notification, 
      Permission.locationWhenInUse, 
      Permission.systemAlertWindow, 
      Permission.calendar
    ].request();
    
    await _determinePosition();
    
    setState(() => _ready = true);
    
    // Slight delay to ensure UI is ready for popups
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

    // BATTERY OPTIMIZED SETTING
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium
    );
    setState(() => _currentPosition = pos);
  }

  // -------------------------------------------------------------------------
  // DATA MANAGEMENT (Load/Save/Delete)
  // -------------------------------------------------------------------------
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _ignoredEventIds = prefs.getStringList('ignored_events') ?? [];
    
    final data = prefs.getString('commutes');
    if (data != null) {
      try {
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

  Future<void> _saveCommute(Commute c) async {
    // 1. Prefetch Data for Cache
    if (_ready) {
      double startLat = _currentPosition?.latitude ?? c.lat;
      double startLon = _currentPosition?.longitude ?? c.lon;
      
      // Fire and forget (populates cache)
      Future.wait([
        WeatherService().getWeatherInfo(startLat, startLon),
        TrafficService().getAdjustedTravelDuration(startLat, startLon, c.eLoc),
      ]);
    }

    // 2. Save to Local Storage
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myCommutes.removeWhere((e) => e.id == c.id);
      myCommutes.add(c);
      _sortCommutes();
    });
    
    await prefs.setString(
      'commutes', 
      json.encode(myCommutes.map((e) => e.toMap()).toList())
    );
  }

  void _deleteCommute(int index) async {
    final c = myCommutes[index];
    setState(() => myCommutes.removeAt(index));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'commutes', 
      json.encode(myCommutes.map((e) => e.toMap()).toList())
    );
    
    await NotificationService().stopAlarm(c.id.hashCode);
  }

  void _sortCommutes() {
    myCommutes.sort((a, b) {
      // Favorites first
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1; 
      }
      // Then by time
      return a.timeInMinutes.compareTo(b.timeInMinutes);
    });
  }

  // -------------------------------------------------------------------------
  // CALENDAR LOGIC
  // -------------------------------------------------------------------------
  Future<void> _checkCalendar() async {
    if (!_ready) return;
    final events = await CalendarService.getUpcomingTravelEvents();
    
    final newEvents = events.where((e) {
      final isAlreadyAdded = myCommutes.any((c) => c.title == e.location);
      final isIgnored = _ignoredEventIds.contains(e.eventId);
      return !isAlreadyAdded && !isIgnored;
    }).toList();

    if (newEvents.isNotEmpty && mounted) {
      // Don't interrupt if user is doing something else (e.g. editing)
      if (Navigator.of(context).canPop()) return; 
      _showEventPopup(newEvents.first);
    }
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
            // HEADER ICON
            CircleAvatar(radius: 30, backgroundColor: ReachStyles.primaryOrange, child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 30)),
            const SizedBox(height: 20),
            
            // TITLE
            Text("New Event Detected", style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 8),
            Text(event.title, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            // LOCATION ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 16, color: ReachStyles.primaryOrange),
                const SizedBox(width: 4),
                Flexible(child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800]))),
              ],
            ),
            const SizedBox(height: 30),
            
            // ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _ignoreEvent(event.eventId);
                      Navigator.pop(context);
                    },
                    child: const Text("Ignore", style: TextStyle(color: Colors.grey)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: ReachStyles.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () {
                      _ignoreEvent(event.eventId);
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
          lat: 0.0, lon: 0.0, eLoc: null,
        ),
      ),
    );
  }

  Future<void> _ignoreEvent(String eventId) async {
    setState(() => _ignoredEventIds.add(eventId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ignored_events', _ignoredEventIds);
  }

  // -------------------------------------------------------------------------
  // NAVIGATION LOGIC (Map Picker)
  // -------------------------------------------------------------------------
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

  // -------------------------------------------------------------------------
  // UI BUILD
  // -------------------------------------------------------------------------
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
          // MAIN CONTENT
          Positioned.fill(
            child: _selectedIndex == 0
                ? HomeView(
                    commutes: myCommutes,
                    currentPos: _currentPosition,
                    onEdit: _editCommute,
                    onDelete: _deleteCommute,
                    onNavigate: _openMapPicker, 
                  )
                : AddEditSheet( 
                    isSheet: false, 
                    onSave: (c) {
                      _saveCommute(c);
                      setState(() => _selectedIndex = 0); // Switch back to Home
                    },
                  ),
          ),
          
          // BOTTOM NAV
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