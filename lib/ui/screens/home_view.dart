import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/commute_model.dart';
import '../../services/traffic_service.dart';
import '../../services/weather_service.dart';
import '../widgets/commute_card.dart';
import 'settings_page.dart';
import '../styles.dart';

// ---------------------------------------------------------------------------
// HOME VIEW
// ---------------------------------------------------------------------------

class HomeView extends StatefulWidget {
  final List<Commute> commutes;
  final Position? currentPos;
  final Function(Commute) onEdit;
  final Function(int) onDelete;
  final Function(Commute, int) onUndo;
  final Function(Commute) onNavigate;
  final Function(Commute) onFavoriteToggle;

  const HomeView({
    super.key,
    required this.commutes,
    this.currentPos,
    required this.onEdit,
    required this.onDelete,
    required this.onUndo,
    required this.onNavigate,
    required this.onFavoriteToggle,
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
    // Re-fetch weather only if the user location changes.
    final oldPos = old.currentPos;
    final newPos = widget.currentPos;
    if (oldPos?.latitude != newPos?.latitude ||
        oldPos?.longitude != newPos?.longitude) {
      _weatherFuture = _fetchWeather();
    }
  }

  Future<Map<String, dynamic>> _fetchWeather() {
    final lat = widget.currentPos?.latitude ??
        (widget.commutes.isNotEmpty ? widget.commutes.first.lat : 28.6);
    final lon = widget.currentPos?.longitude ??
        (widget.commutes.isNotEmpty ? widget.commutes.first.lon : 77.2);
    return WeatherService().getWeatherInfo(lat, lon);
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Reach', style: ReachStyles.heading.copyWith(color: textColor)),
                      const Text('.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.orange)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                    },
                  ),
                ],
              ),
            );
          }

          // --- COMMUTE CARD ---
          final c = widget.commutes[index - 1];
          final useLat = widget.currentPos?.latitude ?? c.lat;
          final useLon = widget.currentPos?.longitude ?? c.lon;

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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                color: Colors.redAccent.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 25),
              child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
            ),
            child: _AsyncCommuteCard(
              key: ValueKey(c.id),
              commute: c,
              lat: useLat,
              lon: useLon,
              weatherFuture: _weatherFuture,
              onEdit: () => widget.onEdit(c),
              onNavigate: widget.onNavigate,
              onFavoriteToggle: widget.onFavoriteToggle,
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
  final Function(Commute) onNavigate;
  final Function(Commute) onFavoriteToggle;

  const _AsyncCommuteCard({
    super.key,
    required this.commute,
    required this.lat,
    required this.lon,
    required this.weatherFuture,
    required this.onEdit,
    required this.onNavigate,
    required this.onFavoriteToggle,
  });

  @override
  State<_AsyncCommuteCard> createState() => _AsyncCommuteCardState();
}

class _AsyncCommuteCardState extends State<_AsyncCommuteCard> {
  late Future<int> _trafficFuture;

  @override
  void initState() {
    super.initState();
    _trafficFuture = _fetchTraffic();
  }

  @override
  void didUpdateWidget(_AsyncCommuteCard old) {
    super.didUpdateWidget(old);
    // Re-fetch traffic if the destination or user position changed.
    if (old.commute.eLoc != widget.commute.eLoc ||
        old.lat != widget.lat ||
        old.lon != widget.lon) {
      setState(() {
        _trafficFuture = _fetchTraffic();
      });
    }
  }

  Future<int> _fetchTraffic() {
    return TrafficService()
        .getAdjustedTravelDuration(widget.lat, widget.lon, widget.commute.eLoc);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([widget.weatherFuture, _trafficFuture]),
      builder: (context, snapshot) {
        String leaveBy = '...';
        String readyBy = '...';
        String weatherEmoji = '';

        if (snapshot.hasData) {
          final weather = snapshot.data![0] as Map<String, dynamic>;
          final traffic = snapshot.data![1] as int;

          final rain = (weather['factor'] as num).toDouble();
          weatherEmoji = weather['emoji'] as String;

          // Swap sun emoji to moon at night.
          final hour = DateTime.now().hour;
          if ((hour >= 18 || hour < 6) &&
              (weatherEmoji.contains('☀️') ||
                  weatherEmoji.contains('🌤️') ||
                  weatherEmoji.contains('⛅'))) {
            weatherEmoji = '🌙';
          }

          final smart = TrafficService().calculateSmartTimes(
            widget.commute.title,
            widget.commute.time,
            traffic,
            rain,
            widget.commute.mode,
          );
          leaveBy = smart['leave']!;
          readyBy = smart['ready']!;
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
          onTap: () => widget.onNavigate(widget.commute),
          onDirections: () => widget.onNavigate(widget.commute),
          onDoubleTap: widget.onEdit,
          onFavoriteToggle: () => widget.onFavoriteToggle(widget.commute),
        );
      },
    );
  }
}