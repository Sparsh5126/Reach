import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'services/notification_service.dart';
import 'services/calendar_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/alarm_screen.dart';
import 'ui/styles.dart';

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

  final prefs = await SharedPreferences.getInstance();

  final isDark = prefs.getBool('is_dark_mode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  final isDynamic = prefs.getBool('is_dynamic_theme') ?? true;
  dynamicThemeNotifier.value = isDynamic;

  try {
    await NotificationService().init();
    await NotificationService().requestPermissions();
  } catch (e, st) {
    debugPrint("Notification init failed: $e\n$st");
  }

  try {
    await CalendarService.init();
  } catch (e, st) {
    debugPrint("Calendar init failed: $e\n$st");
  }

  final plugin = FlutterLocalNotificationsPlugin();
  final launchDetails = await plugin.getNotificationAppLaunchDetails();

  runApp(ReachApp(
    launchPayload: launchDetails?.notificationResponse?.payload,
    launchedByAlarm:
        (launchDetails?.didNotificationLaunchApp ?? false) &&
        launchDetails?.notificationResponse?.payload == 'leave_alarm',
  ));
}

class ReachApp extends StatefulWidget {
  final String? launchPayload;
  final bool launchedByAlarm;
  const ReachApp({super.key, this.launchPayload, this.launchedByAlarm = false});

  @override
  State<ReachApp> createState() => _ReachAppState();
}

class _ReachAppState extends State<ReachApp> with WidgetsBindingObserver {
  bool _wasBackground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Foreground notification taps — app already running.
    // If it was in the background recently, treat it as launched by alarm.
    NotificationService().payloadStream.stream.listen((payload) {
      _handlePayload(payload, launchedByAlarm: _wasBackground);
    });

    if (widget.launchPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePayload(
          widget.launchPayload,
          launchedByAlarm: widget.launchedByAlarm,
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      _wasBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      // Delay resetting the flag so the payload stream has time to process
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _wasBackground = false;
      });
    }
  }

  void _handlePayload(String? payload, {bool launchedByAlarm = false}) {
    if (payload == null) return;

    if (payload == 'leave_alarm' || payload == 'ALARM') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AlarmScreen(
            payload: payload,
            launchedByAlarm: launchedByAlarm,
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder2<ThemeMode, bool>(
      first: themeNotifier,
      second: dynamicThemeNotifier,
      builder: (context, currentMode, isDynamic, _) {
        final darkBg =
            isDynamic ? ReachStyles.dynamicDarkBg : ReachStyles.navyBackground;
        final darkCard =
            isDynamic ? ReachStyles.dynamicDarkCard : ReachStyles.navyCard;
        final lightBg =
            isDynamic ? ReachStyles.dynamicLightBg : ReachStyles.lightBackground;
        final orange = ReachStyles.primaryOrange;

        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
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
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: lightBg,
            cardColor: ReachStyles.lightCard,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              elevation: 0,
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

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
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