import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart'; // REQUIRED FOR METHOD CHANNEL

class AlarmScreen extends StatefulWidget {
  final String payload;
  
  const AlarmScreen({super.key, required this.payload});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final AudioPlayer _player = AudioPlayer();
  
  // NATIVE CHANNEL
  static const platform = MethodChannel('com.example.reach/vibration');
  
  // SLIDER STATE
  double _dragValue = 0.0;
  final double _maxWidth = 280.0; 
  bool _isUnlocked = false;
  bool _isAlarmActive = true; 

  @override
  void initState() {
    super.initState();
    _startAlarm();
  }

  Future<void> _startAlarm() async {
    // 1. Play Sound (Looping) - Uncomment if you have assets
    // await _player.setSource(AssetSource('alarm.mp3'));
    // await _player.setReleaseMode(ReleaseMode.loop);
    // await _player.resume();

    // 2. Vibrate Loop (Using Native Bridge)
    while (_isAlarmActive && mounted) {
      try {
        // Calls the Kotlin code we just wrote
        await platform.invokeMethod('vibrate');
      } on PlatformException catch (e) {
        print("Failed to vibrate: '${e.message}'.");
      }
      
      // Wait 1s (vibrate time) + 1s (pause) = 2s total loop
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _stopAlarm() async {
    if (!_isAlarmActive) return;
    
    setState(() {
      _isAlarmActive = false; // Stops the loop
      _isUnlocked = true;
    });

    _player.stop();
    
    // Stop Native Vibration
    try {
      await platform.invokeMethod('cancel');
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _isAlarmActive = false;
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeString = "${now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour}:${now.minute.toString().padLeft(2, '0')}";
    final amPm = now.hour >= 12 ? "PM" : "AM";

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            
            Column(
              children: [
                const Icon(Icons.commute_outlined, color: Colors.white70, size: 48),
                const SizedBox(height: 20),
                Text(
                  "Time to Leave",
                  style: TextStyle(
                    color: Colors.orange[800], 
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      timeString,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 80,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amPm,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Traffic is Active.",
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),

            const Spacer(),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              child: Container(
                width: _maxWidth,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(35),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        _isUnlocked ? "Have a safe trip!" : "Slide to stop",
                        style: TextStyle(
                          color: _isUnlocked ? Colors.orange : Colors.white30,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Positioned(
                      left: _dragValue, 
                      top: 5,
                      bottom: 5,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          if (_isUnlocked) return;
                          setState(() {
                            _dragValue += details.delta.dx;
                            _dragValue = _dragValue.clamp(0.0, _maxWidth - 70); 
                          });
                        },
                        onHorizontalDragEnd: (details) {
                          if (_isUnlocked) return;
                          if (_dragValue > (_maxWidth - 70) * 0.7) {
                            setState(() => _dragValue = _maxWidth - 70); 
                            _stopAlarm();
                          } else {
                            setState(() => _dragValue = 0.0);
                          }
                        },
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isUnlocked ? Colors.white : Colors.orange[800],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          ),
                          child: Icon(
                            _isUnlocked ? Icons.check : Icons.chevron_right, 
                            color: _isUnlocked ? Colors.orange[800] : Colors.white, 
                            size: 32
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}