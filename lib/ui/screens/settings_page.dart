import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../styles.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/commute_history_service.dart';
import 'commute_history_screen.dart';
import 'guide_screen.dart';

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
  int _gettingReadyTime = 15;

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
      _gettingReadyTime = prefs.getInt('getting_ready_time') ?? 15;
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

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Getting ready time", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("$_gettingReadyTime minutes"),
            onTap: _editGettingReadyTime,
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Dark Mode",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            value: _isDarkMode,
            activeThumbColor: ReachStyles.primaryOrange,
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
                activeThumbColor: ReachStyles.primaryOrange,
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
            activeThumbColor: ReachStyles.primaryOrange,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('fullscreen_alarm_enabled', val);
              setState(() => _fullScreenAlarmEnabled = val);
            },
          ),
          const SizedBox(height: 32),

          _buildSectionHeader("Data"),
          const SizedBox(height: 10),

          _iconTile(
            icon: Icons.history_edu_outlined,
            color: Colors.amber,
            title: 'Commute History',
            subtitle: 'Your recorded trips & adaptive buffers',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CommuteHistoryScreen()),
            ),
          ),
          _iconTile(
            icon: Icons.history,
            color: Colors.orange,
            title: 'Reset Commute History',
            subtitle: 'Clears your adaptive buffer & trip history',
            onTap: _confirmReset,
          ),
          const SizedBox(height: 32),

          _buildSectionHeader("Help & About"),
          const SizedBox(height: 10),

          _iconTile(
            icon: Icons.menu_book_outlined,
            color: ReachStyles.primaryOrange,
            title: 'Features & Guide',
            subtitle: 'Features, gesture controls and terminology',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GuideScreen()),
            ),
          ),
          _iconTile(
            icon: Icons.code_rounded,
            color: Colors.blue,
            title: 'Reach on GitHub',
            subtitle: 'Source code, issues and updates',
            onTap: _openRepo,
          ),
          const SizedBox(height: 32),

          const SizedBox(height: 40),
          Center(
            child: Text(
              "v5.0.0 • Reach",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static const _repoUrl = 'https://github.com/Sparsh5126/Reach';

  Widget _iconTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }

  Future<void> _openRepo() async {
    final ok = await launchUrl(Uri.parse(_repoUrl), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the link.")),
      );
    }
  }

  void _confirmReset() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Commute History?"),
        content: const Text("This will clear all learned traffic data and return buffers to 0. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await CommuteHistoryService.clearAllHistory();
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text("Commute history cleared.")),
                );
              }
            },
            child: const Text("Reset", style: TextStyle(color: Colors.red)),
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

  Future<void> _editGettingReadyTime() async {
    int? newTime = await showDialog<int>(
      context: context,
      builder: (context) {
        int tempTime = _gettingReadyTime;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("Getting Ready Time", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("How long do you usually need to get ready before leaving?"),
                const SizedBox(height: 16),
                DropdownButton<int>(
                  value: tempTime,
                  isExpanded: true,
                  underline: Container(height: 2, color: ReachStyles.primaryOrange),
                  items: [0, 5, 10, 15, 20, 25, 30, 45, 60].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text("$value minutes"),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setDialogState(() => tempTime = newValue);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, tempTime),
                child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (newTime != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('getting_ready_time', newTime);
      setState(() => _gettingReadyTime = newTime);
    }
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