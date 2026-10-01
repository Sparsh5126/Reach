import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/commute_model.dart';
import '../styles.dart';

class AlarmScreen extends StatefulWidget {
  final String payload;
  final bool launchedByAlarm;

  const AlarmScreen({super.key, required this.payload, this.launchedByAlarm = false});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.reach/vibration');

  static const double _trackHeight = 72;
  static const double _thumbSize = 60;

  late final AnimationController _pulse;

  double _dragValue = 0.0;
  bool _isUnlocked = false;
  bool _isAlarmActive = true;
  String? _tripName;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _loadTripName();
    _startAlarm();
  }

  /// Payload format: `leave_alarm:<commuteId>:<mode>`. Anything else (e.g. the
  /// bare `ALARM`) has no trip to show.
  Future<void> _loadTripName() async {
    final parts = widget.payload.split(':');
    if (parts.length < 2 || parts[0] != 'leave_alarm') return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('commutes');
      if (raw == null) return;
      final commutes = (json.decode(raw) as List).map((e) => Commute.fromJson(e));
      final match = commutes.where((c) => c.id == parts[1]);
      if (match.isNotEmpty && mounted) {
        final c = match.first;
        setState(() => _tripName = c.customTitle ?? c.title);
      }
    } catch (e) {
      debugPrint('[ALARM] Could not load trip name: $e');
    }
  }

  Future<void> _startAlarm() async {
    while (_isAlarmActive && mounted) {
      try {
        await platform.invokeMethod('vibrate');
      } on PlatformException catch (e) {
        debugPrint("Failed to vibrate: '${e.message}'.");
      }
      // 1s vibration + 1s pause
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _stopAlarm() async {
    if (!_isAlarmActive) return;

    setState(() {
      _isAlarmActive = false;
      _isUnlocked = true;
    });
    _pulse.stop();
    HapticFeedback.mediumImpact();

    try {
      await platform.invokeMethod('cancel');
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (widget.launchedByAlarm) {
      // Woken by the alarm notification: send the app back to the background.
      await SystemNavigator.pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _isAlarmActive = false;
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final timeString = '$hour12:${now.minute.toString().padLeft(2, '0')}';
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final orange = ReachStyles.primaryOrange;

    return PopScope(
      canPop: false, // the alarm can only be dismissed with the slider
      child: Scaffold(
        backgroundColor: ReachStyles.dynamicDarkBg,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildPulsingIcon(orange),
              const SizedBox(height: 32),
              Text(
                'TIME TO LEAVE',
                style: TextStyle(
                  color: orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    timeString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amPm,
                    style: const TextStyle(color: Colors.white54, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTripChip(),
              const Spacer(flex: 3),
              _buildSlider(orange),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingIcon(Color orange) {
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 88 + 52 * t,
                height: 88 + 52 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: orange.withValues(alpha: 0.22 * (1 - t)),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: orange.withValues(alpha: 0.15),
            border: Border.all(color: orange.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Icon(Icons.directions_run_rounded, color: orange, size: 44),
        ),
      ),
    );
  }

  Widget _buildTripChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: ReachStyles.dynamicDarkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 16, color: ReachStyles.primaryOrange),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
            child: Text(
              _tripName ?? 'Traffic is active',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(Color orange) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = (constraints.maxWidth - 48).clamp(0.0, 340.0);
        final double maxDrag = trackWidth - _thumbSize - 12;
        final double progress = maxDrag <= 0 ? 0 : (_dragValue / maxDrag).clamp(0.0, 1.0);

        return Container(
          width: trackWidth,
          height: _trackHeight,
          decoration: BoxDecoration(
            color: ReachStyles.dynamicDarkCard,
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Fill that follows the thumb
              Container(
                width: 6 + _thumbSize + _dragValue,
                height: _trackHeight,
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: _isUnlocked ? 1 : (1 - progress).clamp(0.0, 1.0),
                  child: Text(
                    _isUnlocked ? 'Have a safe trip!' : 'Slide to stop',
                    style: TextStyle(
                      color: _isUnlocked ? orange : Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6 + _dragValue,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isUnlocked) return;
                    setState(() => _dragValue = (_dragValue + details.delta.dx).clamp(0.0, maxDrag));
                  },
                  onHorizontalDragEnd: (_) {
                    if (_isUnlocked) return;
                    if (_dragValue > maxDrag * 0.7) {
                      setState(() => _dragValue = maxDrag);
                      _stopAlarm();
                    } else {
                      setState(() => _dragValue = 0.0);
                    }
                  },
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isUnlocked ? Colors.white : orange,
                      boxShadow: [
                        BoxShadow(color: orange.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: 1),
                      ],
                    ),
                    child: Icon(
                      _isUnlocked ? Icons.check_rounded : Icons.chevron_right_rounded,
                      color: _isUnlocked ? orange : Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
