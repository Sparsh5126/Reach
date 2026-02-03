import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../styles.dart';
import '../../services/notification_service.dart'; 

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
      appBar: AppBar(
        title: const Text("Settings"), 
        centerTitle: true, 
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // -------------------------------------------------------------------
          // 1. SIMULATION BUTTON
          // -------------------------------------------------------------------
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1), 
                shape: BoxShape.circle
              ),
              child: const Icon(Icons.timer_outlined, color: Colors.purple),
            ),
            title: const Text("Run Alarm Simulation (20s)", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Tests: Future Schedule -> Pack -> Trigger Leave"),
            onTap: () async {
              HapticFeedback.selectionClick();
              
              // Start the chain
              await NotificationService().startSimulation();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Simulation Started! Wait 10 seconds..."),
                    backgroundColor: ReachStyles.primaryOrange,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
          ),
          const Divider(height: 30),

          // -------------------------------------------------------------------
          // 2. FULL SCREEN ALARM
          // -------------------------------------------------------------------
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Full Screen Alarm", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Show critical alerts over lockscreen"),
            value: _fullScreenAlarm,
            activeColor: ReachStyles.primaryOrange,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('full_screen_alarm', val);
              setState(() => _fullScreenAlarm = val);
            },
          ),

          // -------------------------------------------------------------------
          // 3. DARK MODE
          // -------------------------------------------------------------------
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold)),
            value: _isDarkMode,
            activeColor: ReachStyles.primaryOrange,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_dark_mode', val);
              
              // Update Global Theme
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              
              setState(() => _isDarkMode = val);
            },
          ),

          // -------------------------------------------------------------------
          // 4. DYNAMIC THEME (Time Based)
          // -------------------------------------------------------------------
          ValueListenableBuilder<bool>(
            valueListenable: dynamicThemeNotifier,
            builder: (context, isDynamic, _) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Dynamic Theme", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("App background adapts to time of day"),
                secondary: Icon(Icons.auto_awesome, color: ReachStyles.primaryOrange),
                value: isDynamic,
                activeColor: ReachStyles.primaryOrange,
                onChanged: (val) async {
                  HapticFeedback.lightImpact();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_dynamic_theme', val);
                  dynamicThemeNotifier.value = val;
                },
              );
            },
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
              "v1.0.0 • Reach", 
              style: TextStyle(color: Colors.grey[600], fontSize: 12)
            ),
          ),
        ],
      ),
    );
  }
}