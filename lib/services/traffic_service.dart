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
  // Maps "lat_lon_eloc" -> Duration
  static final Map<String, _TrafficCacheItem> _cache = {};
  
  // How long to trust the data before fetching again (e.g., 5 minutes)
  static const int _cacheDurationMinutes = 5;

  Future<int> getAdjustedTravelDuration(double startLat, double startLon, String? destELoc) async {
    if (destELoc == null) return 20; // Default if no location

    // 1. Generate a unique key for this trip
    final String cacheKey = "${startLat.toStringAsFixed(3)}_${startLon.toStringAsFixed(3)}_$destELoc";

    // 2. Check Cache
    if (_cache.containsKey(cacheKey)) {
      final item = _cache[cacheKey]!;
      final age = DateTime.now().difference(item.timestamp).inMinutes;
      
      // If data is fresh (less than 5 mins old), return it immediately (Battery Save!)
      if (age < _cacheDurationMinutes) {
        return item.duration;
      }
    }

    // 3. Fetch Fresh Data (Only if needed)
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
          
          // 4. Save to Cache
          _cache[cacheKey] = _TrafficCacheItem(durationMinutes, DateTime.now());
          
          return durationMinutes;
        }
      }
    } catch (e) {
      // On error, return cached value if it exists (even if old), else default
      if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!.duration;
    }
    return 35; // Fallback
  }

  Map<String, String> calculateSmartTimes(String title, String arriveTimeStr, int travelMinutes, double rainFactor, String mode) {
    // Parse Arrive Time
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

    // Calculate Buffers
    int rainBuffer = (travelMinutes * rainFactor).round(); 
    int parkingBuffer = (mode == 'car') ? 10 : 2;
    int totalCommute = travelMinutes + rainBuffer + parkingBuffer;

    DateTime arriveTime = DateTime(now.year, now.month, now.day, targetHour, targetMinute);
    if (arriveTime.isBefore(now)) arriveTime = arriveTime.add(const Duration(days: 1));

    final leaveTime = arriveTime.subtract(Duration(minutes: totalCommute));
    final readyTime = leaveTime.subtract(const Duration(minutes: 15));

    return {
      'leave': _formatTime(leaveTime),
      'ready': _formatTime(readyTime),
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