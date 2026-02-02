import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';
import 'services/calendar_service.dart';
import 'ui/screens/main_screen.dart';

// GLOBAL KEYS
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Env load failed: $e");
  }
  
  // Initialize Core Services
  await NotificationService().init();
  await CalendarService.init();
  
  // Load User Preference
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  runApp(const ReachApp());
}

class ReachApp extends StatelessWidget {
  const ReachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // Dark Theme
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange, 
              secondary: Colors.orangeAccent
            ),
          ),
          // Light Theme
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white, 
              foregroundColor: Colors.black, 
              elevation: 0
            ),
            colorScheme: const ColorScheme.light(
              primary: Colors.orange, 
              secondary: Colors.orangeAccent, 
              surface: Colors.white
            ),
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}