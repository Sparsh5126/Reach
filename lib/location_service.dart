import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final String name;
  final String address;
  final double lat;
  final double lon;

  LocationResult({required this.name, required this.address, required this.lat, required this.lon});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationResult && runtimeType == other.runtimeType && address == other.address;

  @override
  int get hashCode => address.hashCode;
}

class LocationService {
  static const String _baseUrl = "https://photon.komoot.io/api/";

  static Future<List<LocationResult>> searchPlaces(String query) async {
    if (query.length < 3) return [];

    try {
      final url = Uri.parse("$_baseUrl?q=$query&limit=5&lat=30.3165&lon=78.0322");
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ReachApp/1.0 (flutter-student-project)',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        return features.map((f) {
          final props = f['properties'];
          final geometry = f['geometry'];
          final coords = geometry['coordinates'];
          
          String name = props['name'] ?? props['street'] ?? "Unknown";
          String city = props['city'] ?? props['state'] ?? props['country'] ?? "";
          String address = "$name, $city";

          return LocationResult(
            name: name,
            address: address,
            lat: coords[1],
            lon: coords[0],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint("REACH APP: Network Error -> $e");
      return [];
    }
  }
}