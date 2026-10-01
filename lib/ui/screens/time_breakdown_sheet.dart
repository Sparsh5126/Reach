import 'package:flutter/material.dart';
import '../../services/travel_engine.dart';
import '../styles.dart';

class TimeBreakdownSheet extends StatelessWidget {
  final TravelPrediction prediction;
  final String title;
  final String arriveBy;

  const TimeBreakdownSheet({
    super.key,
    required this.prediction,
    required this.title,
    required this.arriveBy,
  });

  String _formatTime(DateTime dt) {
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? ReachStyles.darkText : ReachStyles.lightText;
    final Color secColor = isDark ? Colors.white70 : Colors.black54;
    final Color bgColor = isDark ? ReachStyles.dynamicDarkCard : ReachStyles.lightCard;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // LEAVE BY — orange, matching the in-app CommuteCard's label style
            Text(
              "LEAVE BY",
              style: TextStyle(color: ReachStyles.primaryOrange, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(prediction.leaveBy),
              style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.w900),
            ),
            
            const SizedBox(height: 24),
            
            // Breakdown Grid
            _buildRow("Arrive by", arriveBy, textColor, secColor),
            const SizedBox(height: 12),
            _buildRow(
              "Travel",
              "${prediction.isFallback ? '≈ ' : ''}${prediction.predictedTravel - prediction.weatherAdjustment} min",
              textColor,
              secColor,
            ),
            if (prediction.isFallback) ...[
              const SizedBox(height: 4),
              Text(
                "Distance estimate — routing unavailable",
                style: TextStyle(color: secColor, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
            if (prediction.weatherAdjustment > 0) ...[
              const SizedBox(height: 12),
              _buildRow("Weather", "+${prediction.weatherAdjustment} min", ReachStyles.accentRed, secColor),
            ],
            const SizedBox(height: 12),
            _buildRow("Safety buffer", "+${prediction.safetyBuffer} min", ReachStyles.primaryOrange, secColor),

            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white12 : Colors.black12),
            const SizedBox(height: 16),

            _buildRow("Getting ready", "${prediction.gettingReadyTime} min", secColor, secColor),
            
            const SizedBox(height: 24),
            
            // READY AT
            Text(
              "READY AT",
              style: TextStyle(color: secColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(prediction.readyAt),
              style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            
            if (prediction.historyEstimate != null) ...[
              const SizedBox(height: 32),
              Text(
                "YOUR HISTORY",
                style: TextStyle(color: secColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              Text(
                "$title · ${prediction.historyEstimate!.sampleCount} trips recorded",
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Usually ${prediction.historyEstimate!.predictedMinutes} min",
                style: TextStyle(color: secColor, fontSize: 14),
              ),
              Text(
                prediction.historyEstimate!.explanation,
                style: TextStyle(color: secColor, fontSize: 14),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor, Color labelColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: labelColor),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}
