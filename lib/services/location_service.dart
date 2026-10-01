import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationResult {
  final String name;
  final String address;
  final double lat;
  final double lon;
  final String eLoc;

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
  static DateTime? _tokenExpiry;

  // --- CENTRALIZED TOKEN EXCHANGE ---
  // Only the Atlas Places-search product below needs this OAuth token.
  // RouteService authenticates with the static MAPPLS_API_KEY REST key
  // instead, so it does not come through here.
  // Tokens are refreshed when they are within 5 minutes of expiry (or expired).
  static Future<String?> _getValidToken() async {
    final now = DateTime.now();
    final isExpiredOrMissing = _accessToken == null ||
        _tokenExpiry == null ||
        now.isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));

    if (isExpiredOrMissing) {
      await _refreshMapplsToken();
    }
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
        // Mappls tokens typically expire in 3600s; cache expiry so we refresh
        // proactively instead of getting silent 401s on every API call.
        final expiresIn = (data["expires_in"] as num?)?.toInt() ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        debugPrint("REACH APP: Token refreshed, expires in ${expiresIn}s");
      }
    } catch (e) {
      debugPrint("REACH APP: Token Exchange Error -> $e");
    }
  }

  // --- SEARCH PLACES ---
  static Future<List<LocationResult>> searchPlaces(String query) async {
    if (query.length < 3) return [];

    // Refresh proactively on expiry rather than waiting to be told 401.
    // This previously only checked `_accessToken == null`, so every search
    // made with an hour-old token paid for a guaranteed-401 round trip before
    // retrying — on the typeahead path, where latency is most visible.
    String? token = await _getValidToken();
    if (token == null) return [];

    try {
      final url = Uri.parse("https://atlas.mappls.com/api/places/search/json?query=${Uri.encodeComponent(query)}");

      var response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // A token can still be rejected early (revoked, clock skew). Retry once,
      // inline. The old code recursed into searchPlaces() instead, which loops
      // forever hammering the network whenever the refresh itself keeps failing
      // — e.g. with bad credentials in .env.
      if (response.statusCode == 401) {
        await _refreshMapplsToken();
        if (_accessToken == null || _accessToken == token) return [];
        token = _accessToken;
        response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestions = data['suggestedLocations'] as List?;

        if (suggestions == null) return [];

        // NOTE: Atlas autosuggest does not return latitude/longitude — the
        // objects carry only placeName/placeAddress/eLoc/type/keywords. So
        // lat/lon below are 0.0 in practice and nothing may treat them as a
        // real position; route on the eLoc instead (RouteService accepts one
        // directly as a waypoint). Kept parsed rather than dropped so the
        // model still works if a plan that does include coordinates is used.
        return suggestions.map((s) {
          return LocationResult(
            name: s['placeName'] ?? "Unknown",
            address: s['placeAddress'] ?? "",
            lat: double.tryParse('${s['latitude']}') ?? 0.0,
            lon: double.tryParse('${s['longitude']}') ?? 0.0,
            eLoc: s['eLoc'] ?? "",
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