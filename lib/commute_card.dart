import 'package:flutter/material.dart';

class CommuteCard extends StatelessWidget {
  final String title;
  final String arriveBy;
  final String leaveBy;
  final String readyBy;
  final String mode;
  final List<String> days;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final String? weatherEmoji;

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
    required this.weatherEmoji,
  });

  @override
  Widget build(BuildContext context) {
    // --- DYNAMIC COLORS ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Background: Dark Grey (Dark) vs White (Light)
    final cardBg = isDark ? const Color(0xFF161616) : Colors.white;
    // Border: Subtle white (Dark) vs None (Light)
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.transparent;
    // Text: White (Dark) vs Black (Light)
    final textColor = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    // Shadow: Only for Light Mode
    final List<BoxShadow> shadows = isDark ? [] : [
      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
    ];

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: shadows,
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildIcon(),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                      Text("Arrive $arriveBy • ${days.join('')}", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("LEAVE BY", style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.w900)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(leaveBy, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                        if (weatherEmoji != null && weatherEmoji!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(weatherEmoji!, style: const TextStyle(fontSize: 16)),
                        ]
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 25, color: isDark ? Colors.white10 : Colors.grey[200]),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text("Get Ready (Pack):", style: TextStyle(color: subText, fontSize: 12)),
                  ],
                ),
                Text(readyBy, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final m = mode.toLowerCase();
    IconData icon;
    
    if (m.contains('motor') || m.contains('bike')) icon = Icons.two_wheeler;
    else if (m.contains('train') || m.contains('metro')) icon = Icons.train;
    else if (m.contains('flight')) icon = Icons.flight;
    else if (m.contains('walk')) icon = Icons.directions_walk;
    else if (m.contains('cycle') && !m.contains('motor')) icon = Icons.directions_bike;
    else icon = Icons.directions_car;

    return Icon(icon, color: Colors.orange[800], size: 24);
  }
}