import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A cached lookup. The Future itself is stored rather than its result, so
/// callers that arrive while a request is still in flight share that request
/// instead of starting a second one.
class _WeatherCacheItem {
  final Future<Map<String, dynamic>> result;
  final DateTime fetchedAt;
  _WeatherCacheItem(this.result, this.fetchedAt);
}

class WeatherService {
  /// Injectable purely so tests can exercise the caching without a network.
  /// Production callers use the default `WeatherService()`.
  WeatherService({http.Client? client}) : _client = client ?? _defaultClient;

  /// Shared deliberately: call sites construct `WeatherService()` inline, so a
  /// per-instance client would spin up — and never close — a fresh connection
  /// pool on every lookup. One long-lived client also lets keep-alive actually
  /// reuse the connection.
  static final http.Client _defaultClient = http.Client();

  final http.Client _client;

  static const String _baseUrl = "https://api.open-meteo.com/v1/forecast";

  /// Weather does not move fast enough to justify re-fetching per commute.
  static const Duration _cacheTtl = Duration(minutes: 10);

  /// ~1.1 km buckets. Open-Meteo's own model grid is far coarser than this,
  /// so finer keys would only ever produce identical answers.
  static const int _keyPrecision = 2;

  static final Map<String, _WeatherCacheItem> _cache = {};

  /// Returns { 'factor': 1.0, 'emoji': '⛈️' }
  ///
  /// Results are cached per coarse location for [_cacheTtl]. Before this the
  /// method hit the network on every call, so one silent refresh fired a
  /// duplicate request per commute — all with the same origin coordinates.
  Future<Map<String, dynamic>> getWeatherInfo(double lat, double lon) {
    final key =
        "${lat.toStringAsFixed(_keyPrecision)}_${lon.toStringAsFixed(_keyPrecision)}";
    final now = DateTime.now();

    final hit = _cache[key];
    if (hit != null && now.difference(hit.fetchedAt) < _cacheTtl) {
      return hit.result;
    }

    _pruneExpired(now);

    final future = _fetch(lat, lon);
    final item = _WeatherCacheItem(future, now);
    _cache[key] = item;

    // Never let a failed lookup occupy the slot for the whole TTL, or one
    // blip would leave the UI without a reading for ten minutes. _fetch
    // signals failure with an empty emoji in its fallback map.
    //
    // The identity check matters: if clearCache() ran and another lookup
    // claimed this key while this one was still in flight, removing by key
    // alone would evict that newer entry instead of this one.
    void evictIfCurrent() {
      if (identical(_cache[key], item)) _cache.remove(key);
    }

    future.then(
      (r) {
        if (r['emoji'] == '') evictIfCurrent();
      },
      onError: (Object _) => evictIfCurrent(),
    );

    return future;
  }

  static void _pruneExpired(DateTime now) {
    _cache.removeWhere((_, v) => now.difference(v.fetchedAt) >= _cacheTtl);
  }

  /// Drops every cached reading. Call after a location change that should
  /// invalidate the current one.
  static void clearCache() => _cache.clear();

  Future<Map<String, dynamic>> _fetch(double lat, double lon) async {
    try {
      final url = Uri.parse('$_baseUrl?latitude=$lat&longitude=$lon&current_weather=true');
      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int code = data['current_weather']['weathercode'];

        // --- WEATHER CODE MAPPING ---
        if (code >= 95 && code <= 99) {
          return {'factor': 2.0, 'emoji': '⛈️'}; // Storm (100% delay)
        } else if (code >= 61 && code <= 67) {
          return {'factor': 1.5, 'emoji': '🌧️'}; // Rain (50% delay)
        } else if (code >= 51 && code <= 57) {
          return {'factor': 1.3, 'emoji': '🌦️'}; // Drizzle (30% delay)
        } else if (code >= 71 && code <= 77) {
          return {'factor': 2.0, 'emoji': '❄️'}; // Snow (100% delay)
        } else if (code >= 1 && code <= 3) {
          return {'factor': 1.0, 'emoji': '☁️'}; // Cloudy (0% delay)
        } else {
          return {'factor': 1.0, 'emoji': '☀️'}; // Clear (Default)
        }
      }
      debugPrint("REACH APP: Weather -> status ${response.statusCode}");
    } catch (e) {
      debugPrint("REACH APP: Weather API Error -> $e");
    }
    return {'factor': 1.0, 'emoji': ''}; // Return default 1.0 if failed
  }
}
