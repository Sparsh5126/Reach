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
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: Colors.green,
              ),
            ),
            title: const Text(
              "Instant Notification Test",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              "Fires immediately — confirms permissions are granted",
            ),
            onTap: () async {
              HapticFeedback.selectionClick();
              await NotificationService().showTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Notification sent! Check your shade."),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          const Divider(height: 16),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_outlined, color: Colors.purple),
            ),
            title: const Text(
              "Scheduled Alarm Simulation",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              "Fires in ~15s — lock your screen after tapping",
            ),
            onTap: () async {
              HapticFeedback.selectionClick();
              await NotificationService().startSimulation();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Scheduled! Lock your screen and wait ~15s."),
                    backgroundColor: ReachStyles.primaryOrange,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
          ),
          const Divider(height: 30),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Dark Mode",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            value: _isDarkMode,
            activeColor: ReachStyles.primaryOrange,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_dark_mode', val);
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              setState(() => _isDarkMode = val);
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: dynamicThemeNotifier,
            builder: (context, isDynamic, _) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Dynamic Theme",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("App background adapts to time of day"),
                secondary: Icon(
                  Icons.auto_awesome,
                  color: ReachStyles.primaryOrange,
                ),
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
              "v3.5.0 • Reach",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}