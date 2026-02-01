import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'location_service.dart'; // <--- Auth Source

class RouteService {
  // Mappls Distance Matrix API (handles traffic and precise routing)
  static const String _baseUrl = "https://atlas.mappls.com/api/places/distance/matrix";

  static Future<int?> getTravelTime({
    required double startLat,
    required double startLon,
    required String endELoc, // Use eLoc instead of endLat/Lon for Mappls
    required String mode, 
  }) async {
    // 1. Get the token from our LocationService logic
    String? token = await LocationService.getValidToken(); 

    if (token == null) return null;

    try {
      // Mappls Profile Mapping
      String profile = 'driving';
      if (mode == 'motorcycle') profile = 'biking';
      if (mode == 'walk') profile = 'walking';

      // Format: matrix/<profile>/<center>;<pts>
      // We use the start coordinates and the destination eLoc
      final url = Uri.parse(
        "$_baseUrl/$profile/$startLon,$startLat;$endELoc?annotations=duration"
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Mappls returns a durations matrix
        if (data['results'] != null && data['results']['durations'] != null) {
          final durationSeconds = data['results']['durations'][0][1]; 
          
          if (durationSeconds == null) return null;
          
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