import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/commute_model.dart';
import '../../services/traffic_service.dart';
import '../../services/weather_service.dart';
import '../widgets/commute_card.dart';
import 'settings_page.dart';
import '../styles.dart';

class HomeView extends StatelessWidget {
  final List<Commute> commutes;
  final Position? currentPos;
  final Function(Commute) onEdit;
  final Function(int) onDelete;
  final Function(Commute, int) onUndo;
  final Function(Commute) onNavigate;

  const HomeView({
    super.key,
    required this.commutes,
    this.currentPos,
    required this.onEdit,
    required this.onDelete,
    required this.onUndo,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? ReachStyles.darkText : ReachStyles.lightText;

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
        itemCount: commutes.length + 1,
        itemBuilder: (context, index) {
          // HEADER
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text("Reach", style: ReachStyles.heading.copyWith(color: textColor)),
                      const Text(".", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.orange)),
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

          // COMMUTE CARD
          final c = commutes[index - 1];
          final useLat = currentPos?.latitude ?? c.lat;
          final useLon = currentPos?.longitude ?? c.lon;

          return Dismissible(
            key: Key(c.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              HapticFeedback.heavyImpact(); 
              
              // 1. Capture details BEFORE deleting
              final deletedItem = c;
              final deletedIndex = index - 1;

              // 2. Perform Delete
              onDelete(deletedIndex);

              // 3. Show Undo SnackBar
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("${deletedItem.title} deleted"),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: ReachStyles.primaryOrange,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onUndo(deletedItem, deletedIndex);
                    },
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(24)),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 25),
              child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
            ),
            child: _AsyncCommuteCard(
              commute: c, 
              lat: useLat, 
              lon: useLon, 
              onEdit: () => onEdit(c),
              onNavigate: onNavigate,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ASYNC CARD WRAPPER
// ---------------------------------------------------------------------------
class _AsyncCommuteCard extends StatefulWidget {
  final Commute commute;
  final double lat;
  final double lon;
  final VoidCallback onEdit;
  final Function(Commute) onNavigate;

  const _AsyncCommuteCard({
    required this.commute,
    required this.lat,
    required this.lon,
    required this.onEdit,
    required this.onNavigate,
  });

  @override
  State<_AsyncCommuteCard> createState() => _AsyncCommuteCardState();
}

class _AsyncCommuteCardState extends State<_AsyncCommuteCard> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = Future.wait([
      WeatherService().getWeatherInfo(widget.lat, widget.lon),
      TrafficService().getAdjustedTravelDuration(widget.lat, widget.lon, widget.commute.eLoc),
    ]).then((res) => {'weather': res[0], 'traffic': res[1]});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        String leaveBy = "...";
        String readyBy = "...";
        String weatherEmoji = "";

        if (snapshot.hasData) {
          final rain = (snapshot.data!['weather']['factor'] as num).toDouble();
          final traffic = snapshot.data!['traffic'] as int;
          weatherEmoji = snapshot.data!['weather']['emoji'];
          
          final smart = TrafficService().calculateSmartTimes(
            widget.commute.title, 
            widget.commute.time, 
            traffic, 
            rain, 
            widget.commute.mode
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
        );
      },
    );
  }
}