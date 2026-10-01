import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RouteService {
  // Mappls Route/Direction API — returns travel time for a route.
  // Authenticated with a static REST key passed as an `access_token` query
  // parameter (MAPPLS_API_KEY) — NOT the OAuth bearer token that
  // LocationService/searchPlaces use for the unrelated Atlas Places-search
  // product.
  // https://route.mappls.com no longer lives under atlas.mappls.com/api/direction/v1
  // (that URL 404s) — see https://github.com/mappls-api/mappls-rest-apis/blob/main/mappls-routing-api/readme.md
  // Endpoint format: /route/direction/route_adv/{profile}/{start};{dest}
  // where each waypoint is either "{lon},{lat}" OR a bare Mappls eLoc — the
  // endpoint resolves eLocs server-side, so no separate lookup is needed
  // (verified: ".../driving/78.0322,30.3165;JOU0DF" returns the same
  // duration/distance as passing that place's coordinates directly).
  // Response: { "code": "Ok", "routes": [{ "duration": <seconds>, ... }], ... }
  static const String _directionBase = "https://route.mappls.com/route/direction";

  /// Get travel time in minutes from [startLat]/[startLon] to [destination].
  ///
  /// [destination] is either "destLon,destLat" (coordinates) or an eLoc string;
  /// both are passed straight through to the Direction API as a waypoint.
  ///
  /// This used to pre-resolve eLocs to coordinates via the Mappls Place Details
  /// API (https://place.mappls.com/O2O/entity/place-details/{eLoc}), but that
  /// endpoint returns lat/lon only under a premium "Location Coordinates"
  /// subtemplate. Without it the response is a 200 carrying just
  /// name/address/eloc, so resolution always returned null and every
  /// eLoc-only commute silently degraded to TrafficService's 20-minute
  /// distance estimate. Routing on the eLoc directly avoids that dependency
  /// (and one network round-trip).
  static Future<int?> getTravelTime({
    required double startLat,
    required double startLon,
    required String destination,
    required String mode,
  }) async {
    final apiKey = dotenv.env['MAPPLS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("REACH APP: Route -> missing MAPPLS_API_KEY in .env, aborting");
      return null;
    }

    try {
      // Mappls Profile Mapping
      final profile = switch (mode) {
        'motorcycle' => 'biking',
        _ => 'driving',
      };

      // The destination is already in a form route_adv accepts: either a
      // "lon,lat" pair or an eLoc. A coordinate pair contains a comma and
      // digits/dots only; an eLoc looks like "JOU0DF" — alphanumeric, no
      // comma. Only classified here so the logs say which kind was routed on.
      final destWaypoint = destination.trim();
      if (destWaypoint.isEmpty) {
        debugPrint("REACH APP: Route -> empty destination, aborting");
        return null;
      }
      final isELoc = !destWaypoint.contains(',') &&
          RegExp(r'^[A-Za-z0-9]+$').hasMatch(destWaypoint);

      // route_adv: available for all profiles/countries, no live traffic.
      // Auth is the static `access_token` query param — not a Bearer header.
      // Not percent-encoded: an eLoc is bare alphanumerics and a coordinate
      // pair needs its comma to stay a literal comma in the path segment.
      final url = Uri.parse(
        "$_directionBase/route_adv/$profile/$startLon,$startLat;$destWaypoint"
        "?overview=false&access_token=$apiKey",
      );

      debugPrint(
          "REACH APP: Route -> dest as ${isELoc ? 'eLoc' : 'coordinates'}, "
          "GET ${url.replace(queryParameters: {
            ...url.queryParameters,
            'access_token': '***redacted***',
          })}");

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint(
          "REACH APP: Route -> status ${response.statusCode} body: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // { "code": "Ok", "routes": [{ "duration": <seconds>, ... }] }
        if (data['code'] == 'Ok' &&
            data['routes'] is List &&
            (data['routes'] as List).isNotEmpty) {
          final durationSeconds =
              (data['routes'][0]['duration'] as num?)?.toDouble();
          if (durationSeconds != null && durationSeconds > 0) {
            final minutes = (durationSeconds / 60).round();
            debugPrint(
                "REACH APP: Route -> ${durationSeconds.round()}s = ${minutes}min ✓");
            return minutes;
          }
        }

        debugPrint(
            "REACH APP: Route -> unexpected response shape. code=${data['code']} keys=${data.keys.toList()}");
      } else if (response.statusCode == 412) {
        // route_adv rejects a waypoint it can't resolve with
        // 412 {"msg":"Getting invalid elocs","error":"<eLoc>"} — the saved
        // eLoc is stale or wrong, not an auth problem. Re-pick the commute's
        // destination so a current eLoc gets stored.
        debugPrint(
            "REACH APP: Route -> 412, Mappls could not resolve waypoint "
            "'$destWaypoint'. Re-select this commute's destination.");
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint(
            "REACH APP: Route -> ${response.statusCode} from route.mappls.com. "
            "MAPPLS_API_KEY may be the wrong credential type (e.g. an Android "
            "SDK/signature-restricted key) rather than an unrestricted or "
            "IP-whitelisted REST key — check the key's Client Restrictions "
            "in the Mappls Console (https://auth.mappls.com/console/).");
      }

      return null;
    } catch (e) {
      debugPrint("REACH APP: Route Error -> $e");
      return null;
    }
  }
}
