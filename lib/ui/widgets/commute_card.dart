import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles.dart';

// ---------------------------------------------------------------------------
// COMMUTE CARD
// ---------------------------------------------------------------------------

class CommuteCard extends StatelessWidget {
  final String title;
  final String arriveBy;
  final String leaveBy;
  final String readyBy;
  final String mode;
  final List<String> days;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onDirections;
  final VoidCallback onFavoriteToggle;
  final Future<void> Function()? onDisableToday;
  final String? weatherEmoji;
  final bool isFavorite;

  const CommuteCard({
    super.key,
    required this.title,
    required this.arriveBy,
    required this.leaveBy,
    required this.readyBy,
    required this.mode,
    required this.days,
    required this.onTap,
    required this.onDoubleTap,
    required this.onDirections,
    required this.onFavoriteToggle,
    required this.weatherEmoji,
    this.onDisableToday,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Theme.of(context).cardColor : ReachStyles.lightCard;
    final txtColor = isDark ? ReachStyles.darkText : ReachStyles.lightText;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        onDoubleTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: ReachStyles.cardRadius,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildModeIcon(),
                const SizedBox(width: 15),
                _buildTitleSection(txtColor),
                _buildLeaveBySection(txtColor),
              ],
            ),
            Divider(height: 25, color: isDark ? Colors.white10 : Colors.grey[200]),
            _buildBottomRow(isDark, txtColor),
          ],
        ),
      ),
    );
  }

  Widget _buildModeIcon() {
    final m = mode.toLowerCase();
    final IconData icon;
    if (m.contains('motor') || m.contains('bike')) {
      icon = Icons.two_wheeler;
    } else if (m.contains('train')) {
      icon = Icons.train;
    } else if (m.contains('flight')) {
      icon = Icons.flight;
    } else {
      icon = Icons.directions_car;
    }
    return Icon(icon, color: Colors.orange[800], size: 24);
  }

  Widget _buildTitleSection(Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: ReachStyles.cardTitle.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Tappable favorite heart
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onFavoriteToggle();
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 14,
                    color: isFavorite ? ReachStyles.accentRed : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Arrive $arriveBy • ${_formatDays()}',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBySection(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'LEAVE BY',
          style: TextStyle(color: ReachStyles.primaryOrange, fontSize: 9, fontWeight: FontWeight.w900),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(leaveBy, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            if (weatherEmoji != null && weatherEmoji!.isNotEmpty)
              Text(weatherEmoji!, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomRow(bool isDark, Color color) {
    // Show the × disable-today button only when today is a scheduled day
    // (or the commute has no recurring days — i.e. it's a one-shot/today commute).
    const List<String> _weekdayNames = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    final String todayName = _weekdayNames[DateTime.now().weekday - 1];
    final bool isToday = days.isEmpty || days.contains(todayName);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.coffee_outlined, size: 14, color: ReachStyles.primaryOrange),
            const SizedBox(width: 6),
            Text(
              'Ready at $readyBy',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // × Disable today button — only visible for today's commutes
            if (isToday && onDisableToday != null)
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await onDisableToday!();
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('"$title" alarm disabled for today.'),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.notifications_off_outlined,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onDirections();
              },
              style: TextButton.styleFrom(
                backgroundColor: ReachStyles.primaryOrange.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.directions_rounded, size: 16, color: ReachStyles.primaryOrange),
              label: Text('Go', style: TextStyle(color: ReachStyles.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDays() {
    if (days.isEmpty) return 'Today';
    if (days.length == 7) return 'Everyday';

    if (days.length == 6) {
      const allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final missing = allDays.firstWhere((d) => !days.contains(d), orElse: () => '');
      if (missing.isNotEmpty) return 'Daily except $missing';
    }

    if (days.length == 5 && !days.contains('Sat') && !days.contains('Sun')) return 'Weekdays';
    if (days.length == 2 && days.contains('Sat') && days.contains('Sun')) return 'Weekends';

    const ref = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = List<String>.from(days)..sort((a, b) => ref.indexOf(a).compareTo(ref.indexOf(b)));
    return sorted.join(' ');
  }
}