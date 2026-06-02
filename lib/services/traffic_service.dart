import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Simple class to hold data + timestamp
class _TrafficCacheItem {
  final int duration;
  final DateTime timestamp;
  _TrafficCacheItem(this.duration, this.timestamp);
}

class TrafficService {
  // STATIC MEMORY CACHE
  static final Map<String, _TrafficCacheItem> _cache = {};
  static const int _cacheDurationMinutes = 5;

  Future<int> getAdjustedTravelDuration(double startLat, double startLon, String? destELoc) async {
    if (destELoc == null) return 20; 

    final String cacheKey = "${startLat.toStringAsFixed(3)}_${startLon.toStringAsFixed(3)}_$destELoc";

    if (_cache.containsKey(cacheKey)) {
      final item = _cache[cacheKey]!;
      final age = DateTime.now().difference(item.timestamp).inMinutes;
      if (age < _cacheDurationMinutes) {
        return item.duration;
      }
    }

    final String? apiKey = dotenv.env['MAPPLS_API_KEY'];
    if (apiKey == null) return 20;

    final url = Uri.parse(
        "https://apis.mappls.com/advancedmaps/v1/$apiKey/route_adv/driving/$startLon,$startLat;${destELoc.trim()}?steps=false&alternatives=false");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final durationSeconds = data['routes'][0]['duration'] as num;
          final durationMinutes = (durationSeconds / 60).round();
          
          _cache[cacheKey] = _TrafficCacheItem(durationMinutes, DateTime.now());
          
          return durationMinutes;
        }
      }
    } catch (e) {
      if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!.duration;
    }
    return 35; // Fallback
  }

  Map<String, String> calculateSmartTimes(String title, String arriveTimeStr, int travelMinutes, double rainFactor, String mode) {
    final raw = calculateSmartTimesRaw(title, arriveTimeStr, travelMinutes, rainFactor, mode);
    return {
      'leave': _formatTime(raw['leave']!),
      'ready': _formatTime(raw['ready']!),
    };
  }

  /// Returns the exact [DateTime] objects for leave and ready times.
  /// Use this for notification scheduling to preserve full date context.
  Map<String, DateTime> calculateSmartTimesRaw(String title, String arriveTimeStr, int travelMinutes, double rainFactor, String mode) {
    // 1. Parse Arrive Time
    final now = DateTime.now();
    int targetHour = 9;
    int targetMinute = 0;

    try {
      final timeParts = arriveTimeStr.split(" ");
      final hm = timeParts[0].split(":");
      targetHour = int.parse(hm[0]);
      targetMinute = int.parse(hm[1]);
      if (timeParts[1] == "PM" && targetHour != 12) targetHour += 12;
      if (timeParts[1] == "AM" && targetHour == 12) targetHour = 0;
    } catch (_) {}

    // 2. Calculate Real Buffers
    int rainBuffer = 0;
    if (rainFactor > 1.0) {
      rainBuffer = (travelMinutes * (rainFactor - 1.0)).round();
    }

    int parkingBuffer = (mode == 'car') ? 10 : 2;
    
    // Dynamic safety buffer: scales with trip length (15% of travel time),
    // clamped between 5 mins (for short/quick trips) and 15 mins (for long commutes)
    int safetyBuffer = (travelMinutes * 0.15).round().clamp(5, 15);

    int totalCommute = travelMinutes + rainBuffer + parkingBuffer + safetyBuffer;

    DateTime arriveTime = DateTime(now.year, now.month, now.day, targetHour, targetMinute);
    // If arrival time has passed, schedule for tomorrow.
    if (arriveTime.isBefore(now)) arriveTime = arriveTime.add(const Duration(days: 1));

    // 3. Subtract to find Leave Time
    DateTime leaveTime = arriveTime.subtract(Duration(minutes: totalCommute));

    // 4. Subtract 15 mins more for "Pack/Ready" time
    DateTime readyTime = leaveTime.subtract(const Duration(minutes: 15));

    // 5. If the earliest notification (pack/ready) is already in the past, push
    //    the entire window to tomorrow. This handles the narrow window where
    //    arriveTime is technically future but leaveTime/packTime are already past
    //    (e.g. it's 8:35 AM, arrival is 9 AM, leaveTime is 8:25 AM → all past).
    if (!readyTime.isAfter(now)) {
      arriveTime = arriveTime.add(const Duration(days: 1));
      leaveTime  = arriveTime.subtract(Duration(minutes: totalCommute));
      readyTime  = leaveTime.subtract(const Duration(minutes: 15));
    }

    return {
      'leave': leaveTime,
      'ready': readyTime,
      'arrive': arriveTime, // also expose for check-in notification scheduling
    };
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour;
    int m = dt.minute;
    String period = "AM";
    if (h >= 12) { period = "PM"; if (h > 12) h -= 12; }
    if (h == 0) h = 12;
    return "$h:${m.toString().padLeft(2, '0')} $period";
  }
}