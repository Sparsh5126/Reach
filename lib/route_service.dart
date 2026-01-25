import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class RouteService {
  static const String _baseUrl = "http://router.project-osrm.org/route/v1";

  static Future<int?> getTravelTime({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    required String mode, 
  }) async {
    try {
      final String profile = 'driving'; 
      
      final url = Uri.parse(
        "$_baseUrl/$profile/$startLon,$startLat;$endLon,$endLat?overview=false"
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          final durationSeconds = data['routes'][0]['duration'];
          final durationMinutes = (durationSeconds / 60).round();
          return durationMinutes;
        }
      }
      return null;
    } catch (e) {
      debugPrint("REACH APP: Route Error -> $e");
      return null;
    }
  }
}