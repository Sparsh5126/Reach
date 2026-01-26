import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Added for permissions
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'commute_model.dart';
import 'add_commute_page.dart';
import 'commute_card.dart';
import 'sliding_nav_bar.dart';
import 'notification_service.dart';
import 'weather_service.dart';
import 'traffic_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const ReachApp());
}

class ReachApp extends StatelessWidget {
  const ReachApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
    home: const MainContainer(),
  );
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});
  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;
  List<Commute> myCommutes = [];

  @override
  void initState() {
    super.initState();
    _loadFromDisk();
    _checkPermissions(); // Request permission on startup
  }

  // FIXED: Explicitly request Exact Alarm permission to stop the crash
  Future<void> _checkPermissions() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('commutes');
    if (data != null) {
      setState(() {
        myCommutes = (json.decode(data) as List).map((i) => Commute.fromJson(i)).toList();
        myCommutes.sort((a, b) => a.timeInMinutes.compareTo(b.timeInMinutes));
      });
    }
  }

  Future<void> _handleScheduling(Commute c) async {
    try {
      // Ensure we have permission before scheduling
      if (await Permission.scheduleExactAlarm.isGranted) {
        double rain = await WeatherService().getWeatherBuffer(c.lat, c.lon, c.mode);
        int traffic = await TrafficService().getAdjustedTravelDuration(c.lat, c.lon);
        final times = TrafficService().calculateSmartTimes(c.title, c.time, traffic, rain);
        
        DateTime parse(String t) {
          final match = RegExp(r'(\d+):(\d+)\s+(AM|PM)').firstMatch(t);
          int h = int.parse(match!.group(1)!);
          int m = int.parse(match.group(2)!);
          if (match.group(3) == "PM" && h < 12) h += 12;
          if (match.group(3) == "AM" && h == 12) h = 0;
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day, h, m);
        }

        int id = c.title.hashCode;
        await NotificationService().schedulePackNotification(id, c.title, parse(times['ready']!));
        await NotificationService().scheduleLeaveAlarm(id, c.title, parse(times['leave']!));
      } else {
        debugPrint("Permission for exact alarms not granted.");
      }
    } catch (e) {
      debugPrint("Scheduling failed: $e");
    }
  }

  void _saveCommute(Commute commute) async {
    setState(() {
      myCommutes.removeWhere((c) => c.title == commute.title);
      myCommutes.add(commute);
      myCommutes.sort((a, b) => a.timeInMinutes.compareTo(b.timeInMinutes));
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('commutes', json.encode(myCommutes.map((c) => c.toJson()).toList()));
    
    await _handleScheduling(commute);
    
    if (mounted) {
      setState(() => _selectedIndex = 0);
    }
  }

  void _deleteCommute(int index) async {
    final commuteToDelete = myCommutes[index];
    int id = commuteToDelete.title.hashCode;
    
    setState(() {
      myCommutes.removeAt(index);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('commutes', json.encode(myCommutes.map((c) => c.toJson()).toList()));
    await NotificationService().stopAlarm(id); 
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${commuteToDelete.title} deleted"), backgroundColor: Colors.orange[900]),
      );
    }
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
                onTabChange: (index) => setState(() => _selectedIndex = index),
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
    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
        itemCount: commutes.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("Reach", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text(".", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.orange[800])),
                  ],
                ),
                const SizedBox(height: 25),
              ],
            );
          }

          final c = commutes[index - 1];
          
          return Dismissible(
            key: Key(c.title + c.time),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) => onDelete(index - 1),
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 25),
              child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FutureBuilder<Map<String, dynamic>>(
                future: Future.wait([
                  WeatherService().getWeatherBuffer(c.lat, c.lon, c.mode),
                  TrafficService().getAdjustedTravelDuration(c.lat, c.lon),
                ]).then((res) => {'rain': res[0] as double, 'traffic': res[1] as int}),
                builder: (context, snapshot) {
                  final double rain = snapshot.data?['rain'] ?? 0.0;
                  final int traffic = snapshot.data?['traffic'] ?? 35;
                  final smartTimes = TrafficService().calculateSmartTimes(c.title, c.time, traffic, rain);

                  return CommuteCard(
                    title: c.title,
                    arriveBy: c.time,
                    leaveBy: smartTimes['leave']!,
                    readyBy: smartTimes['ready']!,
                    mode: c.mode,
                    days: c.days,
                    onTap: () async => await launchUrl(Uri.parse("google.navigation:q=${c.lat},${c.lon}")),
                    onDoubleTap: () => showModalBottomSheet(
                      context: context, 
                      isScrollControlled: true,
                      builder: (context) => AddCommutePage(
                        existingCommute: c, 
                        onSave: (u) { onSave(u); Navigator.pop(context); }
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}