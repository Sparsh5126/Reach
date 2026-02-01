import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // REQUIRED

class LocationResult {
  final String name;
  final String address;
  final double lat;
  final double lon;
  final String eLoc; // Required for Mappls navigation and traffic

  LocationResult({
    required this.name, 
    required this.address, 
    required this.lat, 
    required this.lon, 
    required this.eLoc
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationResult && runtimeType == other.runtimeType && eLoc == other.eLoc;

  @override
  int get hashCode => eLoc.hashCode;
}

class LocationService {
  static String? _accessToken;

  // --- CENTRALIZED TOKEN EXCHANGE ---
  // Other services (Traffic, Route) call this to get a valid token
  static Future<String?> getValidToken() async {
    if (_accessToken != null) return _accessToken;
    await _refreshMapplsToken();
    return _accessToken;
  }

  static Future<void> _refreshMapplsToken() async {
    final clientId = dotenv.env['MAPPLS_CLIENT_ID'];
    final clientSecret = dotenv.env['MAPPLS_CLIENT_SECRET'];
    
    if (clientId == null || clientSecret == null) {
      debugPrint("REACH APP: Missing Mappls Keys in .env");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://outpost.mappls.com/api/security/oauth/token"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "grant_type": "client_credentials",
          "client_id": clientId,
          "client_secret": clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data["access_token"];
      }
    } catch (e) {
      debugPrint("REACH APP: Token Exchange Error -> $e");
    }
  }

  // --- SEARCH PLACES ---
  // Returns clean List<LocationResult> for the UI
  static Future<List<LocationResult>> searchPlaces(String query) async {
    if (query.length < 3) return [];

    // Ensure we have a token
    if (_accessToken == null) {
      await _refreshMapplsToken();
    }

    try {
      final url = Uri.parse("https://atlas.mappls.com/api/places/search/json?query=${Uri.encodeComponent(query)}");
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      // If token expired (401), refresh once and retry
      if (response.statusCode == 401) {
        await _refreshMapplsToken();
        return searchPlaces(query); 
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestions = data['suggestedLocations'] as List?;

        if (suggestions == null) return [];

        return suggestions.map((s) {
          return LocationResult(
            name: s['placeName'] ?? "Unknown",
            address: s['placeAddress'] ?? "",
            lat: double.tryParse(s['latitude'].toString()) ?? 0.0,
            lon: double.tryParse(s['longitude'].toString()) ?? 0.0,
            eLoc: s['eLoc'] ?? "", // The critical Mappls ID
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint("REACH APP: Search Error -> $e");
      return [];
    }
  }
}