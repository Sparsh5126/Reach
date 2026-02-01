import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'location_service.dart'; // <--- Auth Source

class TrafficService {
  static const String _matrixUrl = "https://atlas.mappls.com/api/places/distance/matrix";

  // --- GET DYNAMIC TRAVEL DURATION ---
  Future<int> getAdjustedTravelDuration(
    double startLat, 
    double startLon, 
    String? eLoc,
  ) async {
    if (eLoc == null) return 30; // Default fallback

    // 1. Get Token from Central Auth
    String? token = await LocationService.getValidToken();
    if (token == null) return 35;

    try {
      // matrix/driving/startLon,startLat;destELoc
      final url = Uri.parse("$_matrixUrl/driving/$startLon,$startLat;$eLoc?annotations=duration");
      
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final durationSeconds = data['results']['durations'][0][1];
        if (durationSeconds == null) return 35;
        return (durationSeconds / 60).round();
      }
    } catch (_) {}
    return 35; // Standard fallback
  }

  // --- SMART TIME CALCULATION ---
  Map<String, String> calculateSmartTimes(
    String title,
    String arriveBy,
    int baseTrafficMinutes,
    double rainFactor, // 0.0 to 1.0 (0 = clear, 1 = heavy rain)
    String mode,
  ) {
    // 1. BASE BUFFER (Parking, Walking to car, etc)
    int buffer = 10;
    if (mode == 'motorcycle') buffer = 5;
    if (mode == 'train' || mode == 'flight') buffer = 45; // Security/Parking

    // 2. WEATHER PENALTY
    // Rain increases traffic and prep time (finding umbrella, drying seat)
    double weatherMultiplier = 1.0 + (rainFactor * 0.4); // Max 40% increase
    int adjustedTraffic = (baseTrafficMinutes * weatherMultiplier).round();
    
    // Extra prep time for rain (packing gear/covers)
    int rainPrep = (rainFactor * 15).round();

    // 3. PARSE ARRIVAL TIME
    final match = RegExp(r'(\d+):(\d+)\s+(AM|PM)').firstMatch(arriveBy);
    if (match == null) return {"leave": "08:00 AM", "ready": "07:30 AM"};

    int h = int.parse(match.group(1)!);
    int m = int.parse(match.group(2)!);
    if (match.group(3) == "PM" && h < 12) h += 12;
    if (match.group(3) == "AM" && h == 12) h = 0;

    DateTime arrival = DateTime(2026, 1, 1, h, m);

    // 4. CALCULATE LEAVE & READY TIMES
    // Leave = Arrival - Traffic - Base Buffer
    DateTime leaveTime = arrival.subtract(Duration(minutes: adjustedTraffic + buffer));
    
    // Ready = Leave - Packing Time (15m) - Rain Prep
    DateTime readyTime = leaveTime.subtract(Duration(minutes: 15 + rainPrep));

    return {
      "leave": _formatTime(leaveTime),
      "ready": _formatTime(readyTime),
    };
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour;
    String ampm = h >= 12 ? "PM" : "AM";
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return "$h:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }
}