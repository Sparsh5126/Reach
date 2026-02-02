import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles.dart';

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
    required this.weatherEmoji,
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

  // ---------------------------------------------------------------------------
  // HELPER: SMART TITLE SECTION
  // ---------------------------------------------------------------------------
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
                  overflow: TextOverflow.ellipsis
                ),
              ),
              if (isFavorite) 
                const Padding(
                  padding: EdgeInsets.only(left: 6), 
                  child: Icon(Icons.favorite, size: 14, color: ReachStyles.accentRed)
                ),
            ],
          ),
          // USE THE NEW SMART FORMATTER HERE
          Text(
            "Arrive $arriveBy • ${_formatDays()}", 
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGIC: SMART DAY FORMATTER
  // ---------------------------------------------------------------------------
  String _formatDays() {
    if (days.isEmpty) return "Today";
    if (days.length == 7) return "Everyday";

    // 1. SMART CHECK: 6 Days (Daily except X)
    // Example: "Daily except Sat" (much shorter than listing 6 days)
    if (days.length == 6) {
      final allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      final missing = allDays.firstWhere((d) => !days.contains(d), orElse: () => "");
      if (missing.isNotEmpty) return "Daily except $missing";
    }

    // 2. Weekdays (Mon-Fri)
    final isWeekdays = days.length == 5 && !days.contains("Sat") && !days.contains("Sun");
    if (isWeekdays) return "Weekdays";

    // 3. Weekends (Sat-Sun)
    final isWeekends = days.length == 2 && days.contains("Sat") && days.contains("Sun");
    if (isWeekends) return "Weekends";

    // 4. Fallback: Sort and List
    // We sort them so "Fri Mon" becomes "Mon Fri"
    final ref = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final sorted = List<String>.from(days);
    sorted.sort((a, b) => ref.indexOf(a).compareTo(ref.indexOf(b)));

    return sorted.join(" ");
  }

  Widget _buildLeaveBySection(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text("LEAVE BY", style: TextStyle(color: ReachStyles.primaryOrange, fontSize: 9, fontWeight: FontWeight.w900)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(leaveBy, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            if (weatherEmoji != null) Text(weatherEmoji!, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomRow(bool isDark, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.coffee_outlined, size: 14, color: ReachStyles.primaryOrange),
            const SizedBox(width: 6),
            Text("Ready at $readyBy", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
          ],
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
          label: Text("Go", style: TextStyle(color: ReachStyles.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildModeIcon() {
    IconData icon;
    final m = mode.toLowerCase();
    if (m.contains('motor') || m.contains('bike')) icon = Icons.two_wheeler;
    else if (m.contains('train')) icon = Icons.train;
    else if (m.contains('flight')) icon = Icons.flight;
    else icon = Icons.directions_car;
    return Icon(icon, color: Colors.orange[800], size: 24);
  }
}