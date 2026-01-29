import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class TrafficService {
  final String osrmBaseUrl = 'http://router.project-osrm.org/route/v1/driving';

  // ===========================================================================
  // 1. GET REAL-TIME TRAVEL DURATION (minutes)
  // ===========================================================================
  Future<int> getAdjustedTravelDuration(double destLat, double destLon) async {
    double startLat, startLon;

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      startLat = position.latitude;
      startLon = position.longitude;
    } catch (e) {
      startLat = 30.3165;
      startLon = 78.0322;
    }

    try {
      final url = Uri.parse(
          '$osrmBaseUrl/$startLon,$startLat;$destLon,$destLat?overview=false');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if ((data['routes'] as List).isNotEmpty) {
          final durationVal = data['routes'][0]['duration'];
          final double durationSeconds = (durationVal as num).toDouble();
          int minutes = (durationSeconds / 60).ceil();
          return minutes < 15 ? 15 : minutes;
        }
      }
    } catch (_) {}

    return 35;
  }

  // ===========================================================================
  // 2. SMART TIME CALCULATION (STRING VERSION – UI)
  // ===========================================================================
  Map<String, String> calculateSmartTimes(
    String title,
    String arrivalTimeStr,
    int realTravelMinutes,
    double rainFactor,
    String mode,
  ) {
    final dt = _calculateSmartDateTimesInternal(
      arrivalTimeStr,
      realTravelMinutes,
      rainFactor,
      mode,
    );

    final DateFormat outputFormat = DateFormat("h:mm a");

    return {
      'leave': outputFormat.format(dt['leave']!),
      'ready': outputFormat.format(dt['ready']!),
      'travel_time_text': '${dt['travel']} min'
    };
  }

  // ===========================================================================
  // 3. SMART TIME CALCULATION (DateTime VERSION – notifications)
  // ===========================================================================
  Map<String, DateTime> calculateSmartDateTimes(
    String arrivalTimeStr,
    int realTravelMinutes,
    double rainFactor,
    String mode,
  ) {
    final dt = _calculateSmartDateTimesInternal(
      arrivalTimeStr,
      realTravelMinutes,
      rainFactor,
      mode,
    );

    return {
      'leave': dt['leave']!,
      'ready': dt['ready']!,
    };
  }

  // ===========================================================================
  // INTERNAL (SINGLE SOURCE OF TRUTH)
  // ===========================================================================
  Map<String, dynamic> _calculateSmartDateTimesInternal(
    String arrivalTimeStr,
    int realTravelMinutes,
    double rainFactor,
    String mode,
  ) {
    double multiplier = 1.0;

    bool isExposed = mode.toLowerCase().contains('cycle') ||
        mode.toLowerCase().contains('bike') ||
        mode.toLowerCase().contains('motor') ||
        mode.toLowerCase().contains('walk');

    if (rainFactor >= 0.9) {
      multiplier = isExposed ? 2.0 : 1.5;
    } else if (rainFactor >= 0.4) {
      multiplier = isExposed ? 1.5 : 1.2;
    }

    int finalTravelTime = (realTravelMinutes * multiplier).round();

    // 🔴 CRITICAL FIX: attach date context
    final now = DateTime.now();
    final match = RegExp(r'(\d+):(\d+)\s+(AM|PM)').firstMatch(arrivalTimeStr);

    if (match == null) {
      throw Exception("Invalid time format");
    }

    int h = int.parse(match.group(1)!);
    int m = int.parse(match.group(2)!);
    if (match.group(3) == "PM" && h < 12) h += 12;
    if (match.group(3) == "AM" && h == 12) h = 0;

    DateTime arrivalTime =
        DateTime(now.year, now.month, now.day, h, m);

    if (arrivalTime.isBefore(now)) {
      arrivalTime = arrivalTime.add(const Duration(days: 1));
    }

    DateTime leaveTime =
        arrivalTime.subtract(Duration(minutes: finalTravelTime));

    DateTime readyTime = leaveTime.subtract(const Duration(minutes: 15));

    return {
      'leave': leaveTime,
      'ready': readyTime,
      'travel': finalTravelTime,
    };
  }
}
