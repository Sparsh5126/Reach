import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/commute_model.dart';
import '../../services/traffic_service.dart';
import '../../services/travel_engine.dart';
import '../../services/weather_service.dart';
import '../widgets/commute_card.dart';
import 'settings_page.dart';
import '../styles.dart';

// ---------------------------------------------------------------------------
// HOME VIEW
// ---------------------------------------------------------------------------

class HomeView extends StatefulWidget {
  final List<Commute> commutes;
  final String? userName;
  final ValueChanged<String?> onNameChanged;
  final Position? currentPos;
  final Function(Commute) onEdit;
  final Function(int) onDelete;
  final Function(Commute, int) onUndo;
  final Function(Commute, TravelPrediction?) onTap;
  final Function(Commute) onNavigate;
  final Function(Commute) onFavoriteToggle;
  final Future<void> Function() onDisableAllToday;
  final Future<void> Function(Commute) onDisableToday;
  final Future<void> Function(Commute) onEnableToday;
  final double? savedLat;
  final double? savedLon;

  const HomeView({
    super.key,
    required this.commutes,
    this.userName,
    required this.onNameChanged,
    this.currentPos,
    required this.onEdit,
    required this.onDelete,
    required this.onUndo,
    required this.onTap,
    required this.onNavigate,
    required this.onFavoriteToggle,
    required this.onDisableAllToday,
    required this.onDisableToday,
    required this.onEnableToday,
    this.savedLat,
    this.savedLon,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // Shared weather fetched once for all cards, not once per card.
  late Future<Map<String, dynamic>> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchWeather();
  }

  @override
  void didUpdateWidget(HomeView old) {
    super.didUpdateWidget(old);
    // Re-fetch weather only if the origin _fetchWeather() resolves changes.
    // savedLat/savedLon are watched too: on a cold start they arrive from
    // prefs a frame or two before the first GPS fix, and without this the
    // reading stayed pinned to the Delhi default until the fix landed.
    final oldPos = old.currentPos;
    final newPos = widget.currentPos;
    if (oldPos?.latitude != newPos?.latitude ||
        oldPos?.longitude != newPos?.longitude ||
        old.savedLat != widget.savedLat ||
        old.savedLon != widget.savedLon) {
      _weatherFuture = _fetchWeather();
    }
  }

  Future<Map<String, dynamic>> _fetchWeather() {
    // Falls back live fix -> last persisted fix -> Delhi. It deliberately does
    // NOT fall back to commutes.first.lat/lon: those are 0.0 for anything
    // saved from Places autosuggest (the response carries no coordinates), and
    // 0.0 is not null, so that branch used to swallow the Delhi default and
    // fetch weather for the Gulf of Guinea instead.
    final lat = widget.currentPos?.latitude ?? widget.savedLat ?? 28.6;
    final lon = widget.currentPos?.longitude ?? widget.savedLon ?? 77.2;
    return WeatherService().getWeatherInfo(lat, lon);
  }

  String _commuteCount() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final today = dayNames[now.weekday - 1];
    final nowMinutes = now.hour * 60 + now.minute;

    final count = widget.commutes.where((commute) {
      final matchesToday = commute.days.isEmpty || commute.days.contains(today);
      if (!matchesToday) return false;
      return commute.timeInMinutes >= nowMinutes;
    }).length;

    if (count == 0) return 'No commutes today';
    return '$count commute${count == 1 ? '' : 's'} today';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? ReachStyles.darkText : ReachStyles.lightText;

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
        itemCount: widget.commutes.length + 1,
        itemBuilder: (context, index) {
          // --- HEADER ---
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Reach',
                            style: ReachStyles.heading.copyWith(color: textColor),
                          ),
                          const Text(
                            '.',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                      // × Disable all today — only shown when commutes exist
                      if (widget.commutes.isNotEmpty)
                        Tooltip(
                          message: 'Disable All Alarms Today',
                          child: IconButton(
                            icon: const Icon(Icons.notifications_off_outlined),
                            iconSize: 20,
                            color: Colors.grey,
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              await widget.onDisableAllToday();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                  ..clearSnackBars()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content: Text('All alarms disabled for today. Tomorrow\'s alarms are unchanged.'),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                              }
                            },
                          ),
                        ),
                        IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsPage(
                                onNameChanged: widget.onNameChanged,
                              ),
                            ),
                          );
                        },
                      ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text.rich(
                    TextSpan(
                      text: 'Good ${DateTime.now().hour < 12 ? 'Morning' : (DateTime.now().hour < 17 ? 'Afternoon' : 'Evening')}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      children: widget.userName == null || widget.userName!.isEmpty
                          ? [
                              TextSpan(
                                text: '.',
                                style: TextStyle(color: ReachStyles.primaryOrange),
                              ),
                            ]
                          : [
                              const TextSpan(text: ', '),
                              TextSpan(
                                text: widget.userName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                              ),
                              TextSpan(
                                text: '.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_commuteCount(), style: TextStyle(color: Colors.grey[600])),
                    ],
              ),
            );
          }

          // --- COMMUTE CARD ---
          final c = widget.commutes[index - 1];
          // Origin only — never falls back to c.lat/c.lon. That is the
          // *destination*: using it as the origin asks for a route from a
          // place to itself (~0 min), and for autosuggest-saved commutes it is
          // 0.0 anyway. 0.0 here is the "no fix yet" sentinel TrafficService
          // already recognises, and it reports an estimate rather than a
          // route from the middle of the Atlantic.
          final useLat = widget.currentPos?.latitude ?? widget.savedLat ?? 0.0;
          final useLon = widget.currentPos?.longitude ?? widget.savedLon ?? 0.0;

          return Dismissible(
            key: Key(c.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              HapticFeedback.heavyImpact();
              final deletedIndex = index - 1;
              widget.onDelete(deletedIndex);
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text('${c.customTitle ?? c.title} deleted'),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    action: SnackBarAction(
                      label: 'Undo',
                      textColor: ReachStyles.primaryOrange,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onUndo(c, deletedIndex);
                      },
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
            },
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 25),
              child: const Icon(
                Icons.delete_forever,
                color: Colors.white,
                size: 30,
              ),
            ),
            child: _AsyncCommuteCard(
              key: ValueKey(c.id),
              commute: c,
              lat: useLat,
              lon: useLon,
              weatherFuture: _weatherFuture,
              onEdit: () => widget.onEdit(c),
              onTap: widget.onTap,
              onNavigate: widget.onNavigate,
              onFavoriteToggle: widget.onFavoriteToggle,
              onDisableToday: widget.onDisableToday,
              onEnableToday: widget.onEnableToday,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ASYNC CARD WRAPPER
// Fetches only traffic (weather is shared from parent). Correctly re-fetches
// when the commute destination or user location changes via didUpdateWidget.
// ---------------------------------------------------------------------------

class _AsyncCommuteCard extends StatefulWidget {
  final Commute commute;
  final double lat;
  final double lon;
  final Future<Map<String, dynamic>> weatherFuture;
  final VoidCallback onEdit;
  final Function(Commute, TravelPrediction?) onTap;
  final Function(Commute) onNavigate;
  final Function(Commute) onFavoriteToggle;
  final Future<void> Function(Commute) onDisableToday;
  final Future<void> Function(Commute) onEnableToday;

  const _AsyncCommuteCard({
    super.key,
    required this.commute,
    required this.lat,
    required this.lon,
    required this.weatherFuture,
    required this.onEdit,
    required this.onTap,
    required this.onNavigate,
    required this.onFavoriteToggle,
    required this.onDisableToday,
    required this.onEnableToday,
  });

  @override
  State<_AsyncCommuteCard> createState() => _AsyncCommuteCardState();
}

class _AsyncCommuteCardState extends State<_AsyncCommuteCard> {
  late Future<TravelPrediction> _predictionFuture;
  bool _disabledToday = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadDisabledFlag();
  }

  Future<void> _loadDisabledFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final disabled = prefs.getString('reach_disabled_today_${widget.commute.id}') == today ||
        prefs.getString('reach_disabled_all_today') == today;
    if (mounted && disabled != _disabledToday) {
      setState(() => _disabledToday = disabled);
    }
  }

  Future<void> _toggleToday() async {
    if (_disabledToday) {
      await widget.onEnableToday(widget.commute);
    } else {
      await widget.onDisableToday(widget.commute);
    }
    if (mounted) setState(() => _disabledToday = !_disabledToday);
  }

  @override
  void didUpdateWidget(_AsyncCommuteCard old) {
    super.didUpdateWidget(old);
    // Re-fetch whenever anything TravelEngine.compute() actually reads has
    // changed — not just destination/position. Editing only the time (or
    // mode, or safety buffer) previously left the cached leaveBy/readyAt
    // prediction stale since none of those fields were being watched.
    if (old.commute.eLoc != widget.commute.eLoc ||
        old.commute.time != widget.commute.time ||
        old.commute.mode != widget.commute.mode ||
        old.commute.safetyBufferMinutes != widget.commute.safetyBufferMinutes ||
        old.lat != widget.lat ||
        old.lon != widget.lon) {
      setState(() {
        _fetchData();
      });
    }
  }

  void _fetchData() {
    _predictionFuture = Future.wait([
      widget.weatherFuture,
      TrafficService().getMapplsDuration(
        widget.lat,
        widget.lon,
        widget.commute.eLoc,
        destLat: widget.commute.lat,
        destLon: widget.commute.lon,
        mode: widget.commute.mode,
      ),
    ]).then((results) async {
      final weather = results[0] as Map<String, dynamic>;
      final rainFactor = (weather['factor'] as num).toDouble();
      final trafficResult = results[1] as TrafficResult;
      final mapplsDuration = trafficResult.duration;

      return await TravelEngine.compute(
        commute: widget.commute,
        mapplsDuration: mapplsDuration,
        rainFactor: rainFactor,
        isFallback: trafficResult.isFallback,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TravelPrediction>(
      future: _predictionFuture,
      builder: (context, snapshot) {
        String leaveBy = '...';
        String readyBy = '...';
        String weatherEmoji = '';
        bool isPassedToday = false;

        String formatTimeStr(DateTime dt) {
          int h = dt.hour;
          int m = dt.minute;
          String period = "AM";
          if (h >= 12) {
            period = "PM";
            if (h > 12) h -= 12;
          }
          if (h == 0) h = 12;
          return "$h:${m.toString().padLeft(2, '0')} $period";
        }

        if (snapshot.hasData) {
          final prediction = snapshot.data!;
          leaveBy = formatTimeStr(prediction.leaveBy);
          readyBy = formatTimeStr(prediction.readyAt);
          isPassedToday = prediction.readyAt.day != DateTime.now().day;

          if (prediction.weatherAdjustment > 0) {
            weatherEmoji = '🌧️';
          }

          final hour = DateTime.now().hour;
          if (weatherEmoji.isEmpty && (hour >= 18 || hour < 6)) {
            weatherEmoji = '🌙';
          }
        }

        return CommuteCard(
          title: widget.commute.customTitle ?? widget.commute.title,
          arriveBy: widget.commute.time,
          leaveBy: leaveBy,
          readyBy: readyBy,
          mode: widget.commute.mode,
          days: List<String>.from(widget.commute.days),
          weatherEmoji: weatherEmoji,
          isFavorite: widget.commute.isFavorite,
          onTap: () => widget.onTap(widget.commute, snapshot.data),
          onDirections: () => widget.onNavigate(widget.commute),
          onDoubleTap: widget.onEdit,
          onFavoriteToggle: () => widget.onFavoriteToggle(widget.commute),
          isDisabledToday: _disabledToday,
          onToggleToday: (isPassedToday && !_disabledToday) ? null : _toggleToday,
        );
      },
    );
  }
}
