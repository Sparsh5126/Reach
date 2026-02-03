import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/notification_service.dart';
import 'services/calendar_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/styles.dart';

// GLOBAL KEYS & NOTIFIERS
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<bool> dynamicThemeNotifier = ValueNotifier(true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Env load failed: $e");
  }
  
  await NotificationService().init();
  await CalendarService.init();
  
  final prefs = await SharedPreferences.getInstance();
  
  final isDark = prefs.getBool('is_dark_mode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  final isDynamic = prefs.getBool('is_dynamic_theme') ?? true;
  dynamicThemeNotifier.value = isDynamic;
  
  runApp(const ReachApp());
}

class ReachApp extends StatelessWidget {
  const ReachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder2<ThemeMode, bool>(
      first: themeNotifier,
      second: dynamicThemeNotifier,
      builder: (context, currentMode, isDynamic, _) {
        
        // ---------------------------------------------------------------------
        // FIX: NAVY DEFAULT WHEN DYNAMIC IS OFF
        // ---------------------------------------------------------------------
        // If Dynamic is ON -> Use Time-based Color
        // If Dynamic is OFF -> Use ReachStyles.navyBackground (Default)
        final darkBg = isDynamic ? ReachStyles.dynamicDarkBg : ReachStyles.navyBackground;
        
        // If Dynamic is ON -> Use Time-based Card
        // If Dynamic is OFF -> Use ReachStyles.navyCard (Default)
        final darkCard = isDynamic ? ReachStyles.dynamicDarkCard : ReachStyles.navyCard;
        
        final lightBg = isDynamic ? ReachStyles.dynamicLightBg : ReachStyles.lightBackground;
        final lightCard = ReachStyles.lightCard;
        final orange = ReachStyles.primaryOrange;

        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          
          // DARK THEME
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: darkBg,
            cardColor: darkCard,
            colorScheme: ColorScheme.dark(
              primary: orange, 
              secondary: orange,
              surface: darkCard,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: orange),
            ),
          ),

          // LIGHT THEME
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: lightBg,
            cardColor: ReachStyles.lightCard,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent, 
              foregroundColor: Colors.black, 
              elevation: 0
            ),
            colorScheme: ColorScheme.light(
              primary: orange,
              secondary: orange,
              surface: ReachStyles.lightCard,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: orange),
            ),
          ),
          
          home: const MainScreen(),
        );
      },
    );
  }
}

// HELPER: Listens to two values at once
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const ValueListenableBuilder2({
    super.key, 
    required this.first, 
    required this.second, 
    required this.builder
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, _) {
            return builder(context, a, b, null);
          },
        );
      },
    );
  }
}