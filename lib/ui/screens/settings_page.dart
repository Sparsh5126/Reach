import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../styles.dart';
import '../../services/notification_service.dart';
import 'learning_history_screen.dart';

class SettingsPage extends StatefulWidget {
  final ValueChanged<String?>? onNameChanged;

  const SettingsPage({super.key, this.onNameChanged});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = true;
  bool _fullScreenAlarmEnabled = true;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
      _fullScreenAlarmEnabled = prefs.getBool('fullscreen_alarm_enabled') ?? true;
      _userName = prefs.getString('user_name');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader("Preferences"),
          const SizedBox(height: 10),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_userName?.isNotEmpty == true ? _userName! : 'Not set'),
            onTap: _editName,
          ),

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

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Full-Screen Alarm",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("Wakes up the screen at 'Leave Now' time"),
            secondary: Icon(
              Icons.vibration_outlined,
              color: ReachStyles.primaryOrange,
            ),
            value: _fullScreenAlarmEnabled,
            activeColor: ReachStyles.primaryOrange,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('fullscreen_alarm_enabled', val);
              setState(() => _fullScreenAlarmEnabled = val);
            },
          ),
          const SizedBox(height: 32),

          _buildSectionHeader("Debug & Diagnostics"),
          const SizedBox(height: 10),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_edu_outlined, color: Colors.amber),
            ),
            title: const Text(
              'Learning History',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'View real commute history & adaptive buffers',
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LearningHistoryScreen(),
                ),
              );
            },
          ),

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
              if (context.mounted) {
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
              if (context.mounted) {
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

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_outlined, color: Colors.blue),
            ),
            title: const Text(
              "Test Check-in Notification",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              "Fires in ~5s — tests 'Reached' / 'Almost' buttons",
            ),
            onTap: () async {
              HapticFeedback.selectionClick();
              await NotificationService().testCheckinNotification();
            },
          ),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.clear_all, color: Colors.red),
            ),
            title: const Text(
              "Clear All Notifications",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              "Cancels all pending and active alarms",
            ),
            onTap: () async {
              HapticFeedback.selectionClick();
              await NotificationService().cancelAllNotifications();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All notifications cleared.")),
                );
              }
            },
          ),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history, color: Colors.orange),
            ),
            title: const Text(
              "Reset Learning History",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              "Clears your adaptive buffer & trip history",
            ),
            onTap: () {
              HapticFeedback.heavyImpact();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Reset History?"),
                  content: const Text("This will clear all learned traffic data and return buffers to 0. This cannot be undone."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final keys = prefs.getKeys().where((k) => k.startsWith('reach_')).toList();
                        for (final k in keys) {
                          await prefs.remove(k);
                        }
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Learning history cleared.")),
                          );
                        }
                      },
                      child: const Text("Reset", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          const SizedBox(height: 40),
          Center(
            child: Text(
              "v4.5.0 • Reach",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: ReachStyles.primaryOrange,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameEditDialog(initialName: _userName ?? ''),
    );
    if (name == null) return;
    final trimmedName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmedName.isEmpty) {
      await prefs.remove('user_name');
    } else {
      await prefs.setString('user_name', trimmedName);
    }
    if (mounted) setState(() => _userName = trimmedName.isEmpty ? null : trimmedName);
    widget.onNameChanged?.call(trimmedName.isEmpty ? null : trimmedName);
  }
}

class _NameEditDialog extends StatefulWidget {
  final String initialName;

  const _NameEditDialog({required this.initialName});

  @override
  State<_NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<_NameEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel',style: TextStyle(fontWeight: FontWeight.bold),)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save',style: TextStyle(fontWeight: FontWeight.bold),),
        ),
      ],
    );
  }
}