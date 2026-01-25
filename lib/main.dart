import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'commute_model.dart';
import 'add_commute_screen.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const ReachApp());
}

class ReachApp extends StatelessWidget {
  const ReachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.orange,
        
        colorScheme: const ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.orangeAccent,
          surface: Color(0xFF1E1E1E),
          onPrimary: Colors.white,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: Colors.white
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.orange, 
        ),
        
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Commute> _myCommutes = [];

  @override
  void initState() {
    super.initState();
    _loadCommutes();
  }

  Future<void> _loadCommutes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? commutesString = prefs.getString('commutes_key');
    if (commutesString != null) {
      setState(() {
        _myCommutes = Commute.decode(commutesString);
      });
      _rescheduleAllNotifications();
    }
  }

  Future<void> _saveCommutes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = Commute.encode(_myCommutes);
    await prefs.setString('commutes_key', encodedData);
    _rescheduleAllNotifications();
  }

  void _rescheduleAllNotifications() async {
    await NotificationService.cancelAll();
    
    int notificationId = 0;

    for (var commute in _myCommutes) {
      TimeOfDay arrival = _parseTime(commute.arrivalTime);
      
      int leaveMinutes = commute.durationMinutes + 15;
      TimeOfDay leaveTime = _subtractMinutes(arrival, leaveMinutes);
      
      TimeOfDay packTime = _subtractMinutes(leaveTime, 15);

      for (String day in commute.days) {
        int dayNum = _dayStringToInt(day);
        
        await NotificationService.scheduleWeeklyNotification(
          id: notificationId++,
          title: "Pack Up! 🎒",
          body: "Get ready for ${commute.destination}. Leave in 15 mins.",
          dayOfWeek: dayNum,
          time: packTime,
          isUrgent: false,
        );

        await NotificationService.scheduleWeeklyNotification(
          id: notificationId++,
          title: "Leave Now! 🚀",
          body: "Time to go to ${commute.destination}. Traffic is about ${commute.durationMinutes} mins.",
          dayOfWeek: dayNum,
          time: leaveTime,
          isUrgent: true,
        );
      }
    }
  }

  int _dayStringToInt(String day) {
    switch (day) {
      case "Mon": return 1;
      case "Tue": return 2;
      case "Wed": return 3;
      case "Thu": return 4;
      case "Fri": return 5;
      case "Sat": return 6;
      case "Sun": return 7;
      default: return 1;
    }
  }

  Future<void> _openMap(String destination, String mode) async {
    final query = Uri.encodeComponent(destination);
    String googleMode = mode == 'two_wheeler' ? 'l' : 'd';
    final urlString = "google.navigation:q=$query&mode=$googleMode";
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        final webUrl = "https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving";
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open Maps")),
      );
    }
  }

  String _calculateLeaveTime(String arrivalTimeStr, int travelMinutes) {
    TimeOfDay arrival = _parseTime(arrivalTimeStr);
    int totalSubtract = travelMinutes + 15; 
    TimeOfDay leaveTime = _subtractMinutes(arrival, totalSubtract);
    return _formatTime(leaveTime);
  }

  String _calculatePackTime(String arrivalTimeStr, int travelMinutes) {
    TimeOfDay arrival = _parseTime(arrivalTimeStr);
    int totalSubtract = travelMinutes + 30; 
    TimeOfDay packTime = _subtractMinutes(arrival, totalSubtract);
    return _formatTime(packTime);
  }

  TimeOfDay _subtractMinutes(TimeOfDay time, int minutes) {
    int totalMinutes = time.hour * 60 + time.minute;
    int newTotal = totalMinutes - minutes;
    if (newTotal < 0) newTotal += 24 * 60;
    return TimeOfDay(hour: newTotal ~/ 60, minute: newTotal % 60);
  }

  TimeOfDay _parseTime(String s) {
    try {
      final parts = s.split(" ");
      final timeParts = parts[0].split(":");
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1] == "PM" && hour != 12) hour += 12;
      if (parts.length > 1 && parts[1] == "AM" && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  String _formatTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    String hour = dt.hour > 12 ? (dt.hour - 12).toString() : (dt.hour == 0 ? "12" : dt.hour.toString());
    String minute = dt.minute.toString().padLeft(2, '0');
    String period = dt.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  void _navigateToAddScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddCommuteScreen()),
    );
    if (result != null && result is Commute) {
      setState(() {
        _myCommutes.add(result);
      });
      _saveCommutes();
    }
  }

  void _editCommute(int index) async {
    final existingCommute = _myCommutes[index];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCommuteScreen(commuteToEdit: existingCommute),
      ),
    );
    if (result != null && result is Commute) {
      setState(() {
        _myCommutes[index] = result;
      });
      _saveCommutes();
    }
  }

  void _deleteCommute(int index) {
    setState(() => _myCommutes.removeAt(index));
    _saveCommutes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Reach",
          style: GoogleFonts.lobsterTwo( 
            fontSize: 45,                
            fontWeight: FontWeight.w400, 
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
      ),
      body: _myCommutes.isEmpty
          ? Center(
              child: Text(
                "No commutes saved.\nTap + to add one.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _myCommutes.length,
              itemBuilder: (context, index) {
                final commute = _myCommutes[index];
                final leaveTime = _calculateLeaveTime(commute.arrivalTime, commute.durationMinutes);
                final packTime = _calculatePackTime(commute.arrivalTime, commute.durationMinutes);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    commute.destination,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        commute.transportMode == 'two_wheeler' ? Icons.two_wheeler : Icons.directions_car,
                                        size: 16, color: Colors.grey
                                      ),
                                      const SizedBox(width: 4),
                                      Text("${commute.durationMinutes} mins", style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.map, color: Colors.blueAccent),
                                  onPressed: () => _openMap(commute.destination, commute.transportMode),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _editCommute(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _deleteCommute(index),
                                ),
                              ],
                            )
                          ],
                        ),
                        const Divider(color: Colors.grey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTimeInfo("Pack Up", packTime, Colors.orangeAccent),
                            Icon(Icons.arrow_right_alt, color: Colors.grey[600]),
                            _buildTimeInfo("Leave", leaveTime, Colors.redAccent),
                            Icon(Icons.arrow_right_alt, color: Colors.grey[600]),
                            _buildTimeInfo("Arrive", commute.arrivalTime, Colors.greenAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddScreen,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(time, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}