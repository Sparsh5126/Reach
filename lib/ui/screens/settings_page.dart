import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../styles.dart';

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
          // 1. Full Screen Alarm
          SwitchListTile(
            title: const Text("Full Screen Alarm"),
            value: _fullScreenAlarm,
            activeColor: ReachStyles.primaryOrange,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('full_screen_alarm', val);
              setState(() => _fullScreenAlarm = val);
            },
          ),

          // 2. Dark Mode
          SwitchListTile(
            title: const Text("Dark Mode"),
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

          // 3. Dynamic Theme
          ValueListenableBuilder<bool>(
            valueListenable: dynamicThemeNotifier,
            builder: (context, isDynamic, _) {
              return SwitchListTile(
                title: const Text("Dynamic Theme"),
                subtitle: const Text("App background adapts to the time of day"),
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
        ],
      ),
    );
  }
}