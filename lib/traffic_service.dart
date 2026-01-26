import 'dart:convert';
import 'package:http/http.dart' as http;

class TrafficService {
  Future<int> getAdjustedTravelDuration(double destLat, double destLon) async {
    try {
      double startLat = 30.3165; 
      double startLon = 78.0322;
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$startLon,$startLat;$destLon,$destLat?overview=false');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      int baseTraffic = 20;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        baseTraffic = ((data['routes'][0]['duration'] as num) / 60).round();
      }
      return baseTraffic + 15; // 15-min safety cushion
    } catch (_) {
      return 35; 
    }
  }

  Map<String, String> calculateSmartTimes(String title, String goalTimeStr, int trafficWithBuffer, double rainBuffer) {
    try {
      final format = RegExp(r'(\d+):(\d+)\s+(AM|PM)');
      final match = format.firstMatch(goalTimeStr);
      if (match == null) return {"leave": goalTimeStr, "ready": goalTimeStr};

      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      if (match.group(3) == "PM" && hour < 12) hour += 12;
      if (match.group(3) == "AM" && hour == 12) hour = 0;

      DateTime goalDate = DateTime(2026, 1, 1, hour, minute);
      
      // PICKUP LOGIC: Add 10 mins if picking someone up
      int pickupBuffer = title.startsWith("Pick up:") ? 10 : 0;

      DateTime leaveDate = goalDate.subtract(Duration(minutes: trafficWithBuffer + rainBuffer.toInt() + pickupBuffer));
      DateTime readyDate = leaveDate.subtract(const Duration(minutes: 10));

      return {"leave": _formatTime(leaveDate), "ready": _formatTime(readyDate)};
    } catch (_) {
      return {"leave": goalTimeStr, "ready": goalTimeStr};
    }
  }

  String _formatTime(DateTime date) {
    int h = date.hour;
    String p = h >= 12 ? "PM" : "AM";
    h = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return "$h:${date.minute.toString().padLeft(2, '0')} $p";
  }
}