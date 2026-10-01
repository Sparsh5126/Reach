import 'package:flutter/material.dart';
import '../styles.dart';

/// In-app reference: features, gesture controls and terminology.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  static const _features = <_GuideItem>[
    _GuideItem(Icons.alarm_on_rounded, 'Smart leave alarms',
        'Reach works backwards from your arrival time and alerts you when it is time to leave.'),
    _GuideItem(Icons.traffic_rounded, 'Live traffic',
        'Travel time comes from live routing for your route and mode (car, bike, train or flight).'),
    _GuideItem(Icons.cloudy_snowing, 'Rain awareness',
        'If rain is forecast, extra travel time is added automatically.'),
    _GuideItem(Icons.history_edu_rounded, 'Commute history',
        'Check in with "Reached" after a trip and Reach learns how long it really takes you.'),
    _GuideItem(Icons.calendar_month_rounded, 'Calendar detection',
        'Events with a location in your calendar are detected and can be turned into a trip in one tap.'),
    _GuideItem(Icons.fullscreen_rounded, 'Full-screen alarm',
        'At "Leave by" time the screen wakes with a slide-to-stop alarm. Turn it off in Settings.'),
    _GuideItem(Icons.palette_outlined, 'Themes',
        'Dark mode, plus a dynamic theme whose background follows the time of day.'),
  ];

  static const _gestures = <_GuideItem>[
    _GuideItem(Icons.touch_app_rounded, 'Tap a trip card',
        'Opens the time breakdown: how Leave by was calculated.'),
    _GuideItem(Icons.ads_click_rounded, 'Double-tap a trip card', 'Edit the trip.'),
    _GuideItem(Icons.swipe_left_rounded, 'Swipe a card left',
        'Delete the trip. An Undo button appears for a few seconds.'),
    _GuideItem(Icons.favorite_border_rounded, 'Tap the heart',
        'Favourite a trip to pin it to the top of the list.'),
    _GuideItem(Icons.notifications_active_outlined, 'Tap the bell on a card',
        'Silence today\'s alarm for that trip. Tap again to turn it back on.'),
    _GuideItem(Icons.notifications_off_outlined, 'Bell at the top of Home',
        'Silences today\'s alarms for every trip. Tomorrow is unaffected.'),
    _GuideItem(Icons.directions_rounded, 'Go button',
        'Opens the route in the maps app you pick.'),
    _GuideItem(Icons.arrow_forward_rounded, 'Slide on the alarm', 'Drag the handle to the end to stop the alarm.'),
  ];

  static const _terms = <_GuideItem>[
    _GuideItem(Icons.flag_rounded, 'Arrive by', 'The time you need to be at the destination.'),
    _GuideItem(Icons.logout_rounded, 'Leave by',
        'When you must start moving: Arrive by minus travel time minus safety buffer.'),
    _GuideItem(Icons.coffee_outlined, 'Ready at',
        'When to start getting ready: Leave by minus your "Getting ready time" from Settings.'),
    _GuideItem(Icons.security_rounded, 'Safety buffer',
        'Extra minutes added on top of travel time to absorb small delays.'),
    _GuideItem(Icons.route_rounded, 'Estimated vs. actual',
        '"Estimated" is the routing service\'s prediction; "actual" is what your check-ins recorded.'),
    _GuideItem(Icons.auto_graph_rounded, 'History tier',
        'No history (0–2 trips): routing only. Some history (3–9): blended. Strong history (10+): mostly your own median.'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Features & Guide', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _Section(title: 'Features', items: _features, isDark: isDark),
          _Section(title: 'Gesture controls', items: _gestures, isDark: isDark),
          _Section(title: 'Terminology', items: _terms, isDark: isDark),
        ],
      ),
    );
  }
}

class _GuideItem {
  final IconData icon;
  final String title;
  final String body;
  const _GuideItem(this.icon, this.title, this.body);
}

class _Section extends StatelessWidget {
  final String title;
  final List<_GuideItem> items;
  final bool isDark;

  const _Section({required this.title, required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? Theme.of(context).cardColor : ReachStyles.lightCard;
    final txt = isDark ? ReachStyles.darkText : ReachStyles.lightText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: ReachStyles.primaryOrange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: ReachStyles.cardRadius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ReachStyles.primaryOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(items[i].icon, size: 20, color: ReachStyles.primaryOrange),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(items[i].title,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt)),
                              const SizedBox(height: 3),
                              Text(items[i].body,
                                  style: TextStyle(fontSize: 13, height: 1.35, color: Colors.grey[isDark ? 400 : 600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != items.length - 1)
                    Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? Colors.white10 : Colors.grey[200]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
